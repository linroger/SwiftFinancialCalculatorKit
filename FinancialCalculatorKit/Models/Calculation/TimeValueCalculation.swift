//
//  TimeValueCalculation.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import Foundation
import SwiftData

/// Time Value of Money calculation model
@Model
final class TimeValueCalculation {
    // MARK: - Common Properties
    var id: UUID
    var name: String
    private var calculationTypeRawValue: String = CalculationType.timeValue.rawValue
    var createdDate: Date
    var lastModified: Date
    var notes: String
    var isFavorite: Bool
    private var currencyRawValue: String
    
    /// Computed property for calculationType
    var calculationType: CalculationType {
        get {
            CalculationType(rawValue: calculationTypeRawValue) ?? .timeValue
        }
        set {
            calculationTypeRawValue = newValue.rawValue
        }
    }
    
    /// Computed property for currency
    var currency: Currency {
        get {
            Currency(rawValue: currencyRawValue) ?? .usd
        }
        set {
            currencyRawValue = newValue.rawValue
        }
    }
    
    // MARK: - Time Value Specific Properties
    /// Present Value
    var presentValue: Double?
    
    /// Future Value
    var futureValue: Double?
    
    /// Payment amount per period
    var payment: Double?
    
    /// Annual interest rate (as percentage, e.g., 5.0 for 5%)
    var annualInterestRate: Double?
    
    /// Number of years
    var numberOfYears: Double?
    
    /// Payment frequency (stored as raw value)
    private var paymentFrequencyRawValue: String
    
    /// Whether payments are made at the beginning (true) or end (false) of each period
    var paymentsAtBeginning: Bool
    
    /// The variable being solved for (stored as raw value)
    private var solveForRawValue: String
    
    /// Computed property for paymentFrequency
    var paymentFrequency: PaymentFrequency {
        get {
            PaymentFrequency(rawValue: paymentFrequencyRawValue) ?? .monthly
        }
        set {
            paymentFrequencyRawValue = newValue.rawValue
        }
    }
    
    /// Computed property for solveFor
    var solveFor: TimeValueVariable {
        get {
            TimeValueVariable(rawValue: solveForRawValue) ?? .futureValue
        }
        set {
            solveForRawValue = newValue.rawValue
        }
    }
    
    init(
        name: String,
        paymentFrequency: PaymentFrequency = .monthly,
        paymentsAtBeginning: Bool = false,
        solveFor: TimeValueVariable = .futureValue,
        currency: Currency = .usd
    ) {
        self.id = UUID()
        self.name = name
        self.createdDate = Date()
        self.lastModified = Date()
        self.notes = ""
        self.isFavorite = false
        self.currencyRawValue = currency.rawValue
        
        self.paymentFrequencyRawValue = paymentFrequency.rawValue
        self.paymentsAtBeginning = paymentsAtBeginning
        self.solveForRawValue = solveFor.rawValue
    }
    
    // MARK: - Common Protocol Methods
    
    /// Update the last modified timestamp
    func updateTimestamp() {
        lastModified = Date()
    }
    
    /// Toggle favorite status
    func toggleFavorite() {
        isFavorite.toggle()
        updateTimestamp()
    }
    
    var result: CalculationResult {
        guard isValid else {
            return CalculationResult(
                primaryValue: 0.0,
                formattedPrimaryValue: "Invalid inputs",
                explanation: "Please provide valid inputs for all required fields."
            )
        }
        
        let calculatedValue = calculateSolveForValue()

        guard calculatedValue.isFinite else {
            return CalculationResult(
                primaryValue: 0.0,
                formattedPrimaryValue: "No solution",
                explanation: "The target cannot be reached with these inputs. Check that the values describe a solvable scenario."
            )
        }

        let formattedValue: String
        switch solveFor {
        case .interestRate:
            formattedValue = String(format: "%.3f%%", calculatedValue)
        case .numberOfYears:
            formattedValue = String(format: "%.2f years", calculatedValue)
        case .presentValue, .futureValue, .payment:
            formattedValue = currency.formatValue(calculatedValue)
        }

        var secondaryValues: [String: Double] = [:]
        var explanation = ""
        
        switch solveFor {
        case .presentValue:
            explanation = "Present value required to achieve the target future value"
            if let fv = futureValue { secondaryValues["Future Value"] = fv }
            if let pmt = payment { secondaryValues["Payment"] = pmt }
            
        case .futureValue:
            explanation = "Future value of the investment or loan"
            if let pv = presentValue { secondaryValues["Present Value"] = pv }
            if let pmt = payment { secondaryValues["Payment"] = pmt }
            
        case .payment:
            explanation = "Required payment per period to achieve the target"
            if let pv = presentValue { secondaryValues["Present Value"] = pv }
            if let fv = futureValue { secondaryValues["Future Value"] = fv }
            
        case .interestRate:
            explanation = "Required annual interest rate (as percentage)"
            if let pv = presentValue { secondaryValues["Present Value"] = pv }
            if let fv = futureValue { secondaryValues["Future Value"] = fv }
            if let pmt = payment { secondaryValues["Payment"] = pmt }
            
        case .numberOfYears:
            explanation = "Time required to achieve the target"
            if let pv = presentValue { secondaryValues["Present Value"] = pv }
            if let fv = futureValue { secondaryValues["Future Value"] = fv }
            if let pmt = payment { secondaryValues["Payment"] = pmt }
        }
        
        if let rate = annualInterestRate {
            secondaryValues["Annual Interest Rate"] = rate
            let effectiveAnnualRate = pow(1 + (rate / 100 / paymentFrequency.periodsPerYear), paymentFrequency.periodsPerYear) - 1
            secondaryValues["Effective Annual Rate"] = effectiveAnnualRate * 100
        }
        
        if let years = numberOfYears {
            secondaryValues["Number of Years"] = years
        }
        
        // Generate chart data for cash flow visualization
        let chartData = generateCashFlowData()
        
        return CalculationResult(
            primaryValue: calculatedValue,
            secondaryValues: secondaryValues,
            formattedPrimaryValue: formattedValue,
            explanation: explanation,
            chartData: chartData
        )
    }
    
    var isValid: Bool {
        validationErrors.isEmpty
    }

    var validationErrors: [String] {
        var errors: [String] = []

        if name.isEmpty {
            errors.append("Name is required")
        }

        // A missing payment or missing present value is treated as zero, so only
        // the inputs the chosen solve actually needs are required.
        let hasMoneyInput = (presentValue ?? 0) != 0 || (payment ?? 0) != 0

        switch solveFor {
        case .presentValue:
            if annualInterestRate == nil { errors.append("Interest rate is required") }
            if numberOfYears == nil { errors.append("Number of years is required") }
            if (futureValue ?? 0) == 0 && (payment ?? 0) == 0 {
                errors.append("Provide a future value or a payment amount")
            }
        case .futureValue:
            if annualInterestRate == nil { errors.append("Interest rate is required") }
            if numberOfYears == nil { errors.append("Number of years is required") }
            if !hasMoneyInput {
                errors.append("Provide a present value or a payment amount")
            }
        case .payment:
            if annualInterestRate == nil { errors.append("Interest rate is required") }
            if numberOfYears == nil { errors.append("Number of years is required") }
            if (presentValue ?? 0) == 0 && (futureValue ?? 0) == 0 {
                errors.append("Provide a present value or a future value")
            }
        case .interestRate:
            if numberOfYears == nil { errors.append("Number of years is required") }
            if (futureValue ?? 0) == 0 {
                errors.append("A future value target is required to solve for the rate")
            }
            if !hasMoneyInput {
                errors.append("Provide a present value or a payment amount")
            }
        case .numberOfYears:
            if annualInterestRate == nil { errors.append("Interest rate is required") }
            if (futureValue ?? 0) == 0 {
                errors.append("A future value target is required to solve for the time")
            }
            if !hasMoneyInput {
                errors.append("Provide a present value or a payment amount")
            }
        }

        if let pv = presentValue, pv < 0 {
            errors.append("Present value cannot be negative")
        }
        if let fv = futureValue, fv < 0 {
            errors.append("Future value cannot be negative")
        }
        if let rate = annualInterestRate, rate < 0 {
            errors.append("Interest rate cannot be negative")
        }
        if let years = numberOfYears, years <= 0 {
            errors.append("Number of years must be positive")
        }
        if let years = numberOfYears, years > 1000 {
            errors.append("Number of years must be 1000 or less")
        }

        return errors
    }
    
    /// Calculate the value of the variable being solved for
    private func calculateSolveForValue() -> Double {
        switch solveFor {
        case .presentValue:
            return calculatePresentValue()
        case .futureValue:
            return calculateFutureValue()
        case .payment:
            return calculatePayment()
        case .interestRate:
            return calculateInterestRate()
        case .numberOfYears:
            return calculateNumberOfYears()
        }
    }
    
    private func calculatePresentValue() -> Double {
        return CalculationEngine.calculatePresentValue(
            futureValue: futureValue,
            payment: payment,
            interestRate: paymentFrequency.periodRate(from: annualInterestRate ?? 0.0),
            numberOfPeriods: paymentFrequency.numberOfPeriods(from: numberOfYears ?? 0.0),
            paymentAtBeginning: paymentsAtBeginning
        )
    }
    
    private func calculateFutureValue() -> Double {
        return CalculationEngine.calculateFutureValue(
            presentValue: presentValue,
            payment: payment,
            interestRate: paymentFrequency.periodRate(from: annualInterestRate ?? 0.0),
            numberOfPeriods: paymentFrequency.numberOfPeriods(from: numberOfYears ?? 0.0),
            paymentAtBeginning: paymentsAtBeginning
        )
    }
    
    private func calculatePayment() -> Double {
        return CalculationEngine.calculatePayment(
            presentValue: presentValue,
            futureValue: futureValue,
            interestRate: paymentFrequency.periodRate(from: annualInterestRate ?? 0.0),
            numberOfPeriods: paymentFrequency.numberOfPeriods(from: numberOfYears ?? 0.0),
            paymentAtBeginning: paymentsAtBeginning
        )
    }
    
    private func calculateInterestRate() -> Double {
        // The engine returns a per-period rate; convert to a nominal annual rate.
        let periodicRate = CalculationEngine.calculateInterestRate(
            presentValue: presentValue,
            futureValue: futureValue,
            payment: payment,
            numberOfPeriods: paymentFrequency.numberOfPeriods(from: numberOfYears ?? 0.0),
            paymentAtBeginning: paymentsAtBeginning
        )
        return periodicRate * paymentFrequency.periodsPerYear
    }
    
    private func calculateNumberOfYears() -> Double {
        let periods = CalculationEngine.calculateNumberOfPeriods(
            presentValue: presentValue,
            futureValue: futureValue,
            payment: payment,
            interestRate: paymentFrequency.periodRate(from: annualInterestRate ?? 0.0),
            paymentAtBeginning: paymentsAtBeginning
        )
        return paymentFrequency.yearsFromPeriods(periods)
    }
    
    /// Generate cash flow data for visualization, including recurring payments.
    private func generateCashFlowData() -> [ChartDataPoint] {
        guard let years = numberOfYears,
              let rate = annualInterestRate else {
            return []
        }

        let totalPeriods = paymentFrequency.numberOfPeriods(from: years)
        guard totalPeriods.isFinite, totalPeriods > 0 else { return [] }

        // Clamp BEFORE the Int conversion (a huge Double would trap), and cap
        // the series so very long horizons stay renderable
        let periods = Int(min(totalPeriods.rounded(), 1200))
        let r = paymentFrequency.periodRate(from: rate) / 100
        let pv = presentValue ?? 0.0
        let pmt = payment ?? 0.0

        var data: [ChartDataPoint] = []
        for period in 0...periods {
            let p = Double(period)
            let growth = pow(1 + r, p)
            let annuity: Double
            if r == 0 {
                annuity = pmt * p
            } else {
                let s = (growth - 1) / r
                annuity = pmt * (paymentsAtBeginning ? s * (1 + r) : s)
            }
            let value = pv * growth + annuity
            let time = paymentFrequency.yearsFromPeriods(p)
            data.append(ChartDataPoint(x: time, y: value, label: "Period \(period)"))
        }

        return data
    }
}

// MARK: - Protocol Conformance

extension TimeValueCalculation: FinancialCalculationProtocol {}

/// Variables that can be solved for in TVM calculations
enum TimeValueVariable: String, CaseIterable, Identifiable {
    case presentValue = "presentValue"
    case futureValue = "futureValue"
    case payment = "payment"
    case interestRate = "interestRate"
    case numberOfYears = "numberOfYears"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .presentValue:
            return "Present Value (PV)"
        case .futureValue:
            return "Future Value (FV)"
        case .payment:
            return "Payment (PMT)"
        case .interestRate:
            return "Interest Rate (I/Y)"
        case .numberOfYears:
            return "Number of Years (N)"
        }
    }
    
    var description: String {
        switch self {
        case .presentValue:
            return "The current value of future cash flows"
        case .futureValue:
            return "The value of an investment at a future date"
        case .payment:
            return "The amount of each periodic payment"
        case .interestRate:
            return "The annual interest rate as a percentage"
        case .numberOfYears:
            return "The time period in years"
        }
    }
}
