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
        let formattedValue = currency.formatValue(calculatedValue)
        
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
        guard !name.isEmpty else { return false }
        
        // Check that we have enough inputs to solve
        let inputCount = [presentValue, futureValue, payment, annualInterestRate, numberOfYears].compactMap { $0 }.count
        
        // We need at least 4 out of 5 values to solve for the 5th
        guard inputCount >= 4 else { return false }
        
        // Validate individual inputs
        if let pv = presentValue, pv < 0 { return false }
        if let fv = futureValue, fv < 0 { return false }
        if let rate = annualInterestRate, rate < 0 { return false }
        if let years = numberOfYears, years <= 0 { return false }
        
        return true
    }
    
    var validationErrors: [String] {
        var errors: [String] = []
        
        if name.isEmpty {
            errors.append("Name is required")
        }
        
        let inputCount = [presentValue, futureValue, payment, annualInterestRate, numberOfYears].compactMap { $0 }.count
        
        if inputCount < 4 {
            errors.append("At least 4 out of 5 values must be provided to solve for the unknown")
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
        
        return errors
    }
    
    /// Calculate the value of the variable being solved for
    private func calculateSolveForValue() -> Double {
        // This would contain the actual financial mathematics
        // For now, returning a placeholder calculation
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
        return CalculationEngine.calculateInterestRate(
            presentValue: presentValue,
            futureValue: futureValue,
            payment: payment,
            numberOfPeriods: paymentFrequency.numberOfPeriods(from: numberOfYears ?? 0.0),
            paymentAtBeginning: paymentsAtBeginning
        )
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
    
    /// Generate cash flow data for visualization
    private func generateCashFlowData() -> [ChartDataPoint] {
        guard let years = numberOfYears,
              let rate = annualInterestRate else {
            return []
        }
        
        var data: [ChartDataPoint] = []
        let periods = Int(paymentFrequency.numberOfPeriods(from: years))
        
        for period in 0...periods {
            let time = paymentFrequency.yearsFromPeriods(Double(period))
            let value = (presentValue ?? 0.0) * pow(1 + paymentFrequency.periodRate(from: rate / 100), Double(period))
            
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