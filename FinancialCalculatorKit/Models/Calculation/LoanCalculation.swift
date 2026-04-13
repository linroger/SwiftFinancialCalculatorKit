//
//  LoanCalculation.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import Foundation
import SwiftData

/// Loan calculation model for standard loans and mortgages
@Model
final class LoanCalculation {
    // MARK: - Common Properties
    var id: UUID
    var name: String
    private var calculationTypeRawValue: String
    var createdDate: Date
    var lastModified: Date
    var notes: String
    var isFavorite: Bool
    private var currencyRawValue: String
    
    /// Computed property for calculationType
    var calculationType: CalculationType {
        get {
            CalculationType(rawValue: calculationTypeRawValue) ?? .loan
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
    
    // MARK: - Loan Specific Properties
    /// Principal loan amount
    var principalAmount: Double
    
    /// Annual interest rate (as percentage)
    var annualInterestRate: Double
    
    /// Loan term in years
    var loanTermYears: Double
    
    /// Payment frequency (stored as raw value)
    private var paymentFrequencyRawValue: String
    
    /// Down payment amount (for mortgages)
    var downPayment: Double
    
    /// Additional monthly payment
    var extraPayment: Double
    
    /// Loan type (stored as raw value)
    private var loanTypeRawValue: String
    
    /// Computed property for paymentFrequency
    var paymentFrequency: PaymentFrequency {
        get {
            PaymentFrequency(rawValue: paymentFrequencyRawValue) ?? .monthly
        }
        set {
            paymentFrequencyRawValue = newValue.rawValue
        }
    }
    
    /// Computed property for loanType
    var loanType: LoanType {
        get {
            LoanType(rawValue: loanTypeRawValue) ?? .standardLoan
        }
        set {
            loanTypeRawValue = newValue.rawValue
        }
    }
    
    init(
        name: String,
        principalAmount: Double,
        annualInterestRate: Double,
        loanTermYears: Double,
        paymentFrequency: PaymentFrequency = .monthly,
        downPayment: Double = 0.0,
        extraPayment: Double = 0.0,
        loanType: LoanType = .standardLoan,
        currency: Currency = .usd
    ) {
        self.id = UUID()
        self.name = name
        self.calculationTypeRawValue = (loanType == .mortgage ? CalculationType.mortgage : CalculationType.loan).rawValue
        self.createdDate = Date()
        self.lastModified = Date()
        self.notes = ""
        self.isFavorite = false
        self.currencyRawValue = currency.rawValue
        
        self.principalAmount = principalAmount
        self.annualInterestRate = annualInterestRate
        self.loanTermYears = loanTermYears
        self.paymentFrequencyRawValue = paymentFrequency.rawValue
        self.downPayment = downPayment
        self.extraPayment = extraPayment
        self.loanTypeRawValue = loanType.rawValue
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
        
        let amortization = calculateAmortization()
        let monthlyPayment = amortization.first?.payment ?? 0.0
        let totalInterest = amortization.reduce(0) { $0 + $1.interestPayment }
        let totalPayments = amortization.reduce(0) { $0 + $1.payment }
        
        let formattedPayment = currency.formatValue(monthlyPayment)
        
        var secondaryValues: [String: Double] = [:]
        secondaryValues["Total Interest"] = totalInterest
        secondaryValues["Total Payments"] = totalPayments
        secondaryValues["Principal Amount"] = principalAmount - downPayment
        
        if downPayment > 0 {
            secondaryValues["Down Payment"] = downPayment
        }
        
        if extraPayment > 0 {
            secondaryValues["Extra Payment"] = extraPayment
            // Calculate time saved with extra payments
            let timeWithoutExtra = calculatePayoffTime(extraPayment: 0)
            let timeWithExtra = calculatePayoffTime(extraPayment: extraPayment)
            secondaryValues["Time Saved (Years)"] = timeWithoutExtra - timeWithExtra
        }
        
        let explanation = loanType == .mortgage ? 
            "Monthly mortgage payment including principal and interest" :
            "Monthly loan payment including principal and interest"
        
        // Generate chart data for payment breakdown over time
        let chartData = generatePaymentBreakdownData(amortization: amortization)
        
        // Generate table data for amortization schedule
        let tableData = generateAmortizationTable(amortization: amortization)
        
        return CalculationResult(
            primaryValue: monthlyPayment,
            secondaryValues: secondaryValues,
            formattedPrimaryValue: formattedPayment,
            explanation: explanation,
            chartData: chartData,
            tableData: tableData
        )
    }
    
    var isValid: Bool {
        guard !name.isEmpty else { return false }
        
        return principalAmount > 0 &&
               annualInterestRate >= 0 &&
               loanTermYears > 0 &&
               downPayment >= 0 &&
               extraPayment >= 0 &&
               downPayment < principalAmount
    }
    
    var validationErrors: [String] {
        var errors: [String] = []
        
        if name.isEmpty {
            errors.append("Name is required")
        }
        
        if principalAmount <= 0 {
            errors.append("Principal amount must be positive")
        }
        
        if annualInterestRate < 0 {
            errors.append("Interest rate cannot be negative")
        }
        
        if loanTermYears <= 0 {
            errors.append("Loan term must be positive")
        }
        
        if downPayment < 0 {
            errors.append("Down payment cannot be negative")
        }
        
        if extraPayment < 0 {
            errors.append("Extra payment cannot be negative")
        }
        
        if downPayment >= principalAmount {
            errors.append("Down payment must be less than principal amount")
        }
        
        return errors
    }
    
    /// Calculate monthly payment amount
    func calculateMonthlyPayment() -> Double {
        let loanAmount = principalAmount - downPayment
        let periodRate = paymentFrequency.periodRate(from: annualInterestRate)
        let numberOfPayments = paymentFrequency.numberOfPeriods(from: loanTermYears)
        
        let basePayment = CalculationEngine.calculateLoanPayment(
            principal: loanAmount,
            interestRate: periodRate * 100,
            numberOfPayments: numberOfPayments
        )
        
        return basePayment + extraPayment
    }
    
    /// Calculate complete amortization schedule
    func calculateAmortization() -> [AmortizationEntry] {
        let loanAmount = principalAmount - downPayment
        let monthlyRate = paymentFrequency.periodRate(from: annualInterestRate / 100)
        let basePayment = calculateMonthlyPayment() - extraPayment
        let totalPayment = basePayment + extraPayment
        
        var schedule: [AmortizationEntry] = []
        var remainingBalance = loanAmount
        var paymentNumber = 1
        
        while remainingBalance > 0.01 && paymentNumber <= Int(paymentFrequency.numberOfPeriods(from: loanTermYears)) {
            let interestPayment = remainingBalance * monthlyRate
            var principalPayment = totalPayment - interestPayment
            
            // Ensure we don't overpay
            if principalPayment > remainingBalance {
                principalPayment = remainingBalance
            }
            
            let actualPayment = interestPayment + principalPayment
            remainingBalance -= principalPayment
            
            let entry = AmortizationEntry(
                paymentNumber: paymentNumber,
                payment: actualPayment,
                principalPayment: principalPayment,
                interestPayment: interestPayment,
                remainingBalance: remainingBalance
            )
            
            schedule.append(entry)
            paymentNumber += 1
            
            if remainingBalance < 0.01 {
                break
            }
        }
        
        return schedule
    }
    
    /// Calculate payoff time with given extra payment
    private func calculatePayoffTime(extraPayment: Double) -> Double {
        let originalExtra = self.extraPayment
        self.extraPayment = extraPayment
        
        let amortization = calculateAmortization()
        let payoffTime = paymentFrequency.yearsFromPeriods(Double(amortization.count))
        
        self.extraPayment = originalExtra
        return payoffTime
    }
    
    /// Generate chart data for payment breakdown visualization
    private func generatePaymentBreakdownData(amortization: [AmortizationEntry]) -> [ChartDataPoint] {
        var data: [ChartDataPoint] = []
        
        for (index, entry) in amortization.enumerated() {
            let year = paymentFrequency.yearsFromPeriods(Double(index + 1))
            
            // Create data points for principal and interest
            data.append(ChartDataPoint(x: year, y: entry.principalPayment, label: "Principal"))
            data.append(ChartDataPoint(x: year, y: entry.interestPayment, label: "Interest"))
        }
        
        return data
    }
    
    /// Generate amortization table data
    private func generateAmortizationTable(amortization: [AmortizationEntry]) -> [TableRow] {
        return amortization.map { entry in
            TableRow(values: [
                "Payment #": "\(entry.paymentNumber)",
                "Payment": currency.formatValue(entry.payment),
                "Principal": currency.formatValue(entry.principalPayment),
                "Interest": currency.formatValue(entry.interestPayment),
                "Balance": currency.formatValue(entry.remainingBalance)
            ])
        }
    }
}

// MARK: - Protocol Conformance

extension LoanCalculation: FinancialCalculationProtocol {}

/// Loan type enumeration
enum LoanType: String, CaseIterable, Identifiable, Codable {
    case standardLoan = "standardLoan"
    case mortgage = "mortgage"
    case autoLoan = "autoLoan"
    case personalLoan = "personalLoan"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .standardLoan:
            return "Standard Loan"
        case .mortgage:
            return "Mortgage"
        case .autoLoan:
            return "Auto Loan"
        case .personalLoan:
            return "Personal Loan"
        }
    }
}

/// Single entry in an amortization schedule
struct AmortizationEntry: Identifiable {
    let id = UUID()
    let paymentNumber: Int
    let payment: Double
    let principalPayment: Double
    let interestPayment: Double
    let remainingBalance: Double
    
    var cumulativePrincipal: Double = 0.0
    var cumulativeInterest: Double = 0.0
}