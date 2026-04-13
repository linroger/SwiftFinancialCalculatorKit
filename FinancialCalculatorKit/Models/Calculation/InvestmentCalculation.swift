//
//  InvestmentCalculation.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import Foundation
import SwiftData

/// Investment calculation model for NPV, IRR, and performance analysis
@Model
final class InvestmentCalculation {
    // MARK: - Common Properties
    var id: UUID
    var name: String
    private var calculationTypeRawValue: String = CalculationType.investment.rawValue
    var createdDate: Date
    var lastModified: Date
    var notes: String
    var isFavorite: Bool
    private var currencyRawValue: String
    
    /// Computed property for calculationType
    var calculationType: CalculationType {
        get {
            CalculationType(rawValue: calculationTypeRawValue) ?? .investment
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
    
    // MARK: - Investment Specific Properties
    /// Initial investment (negative value)
    var initialInvestment: Double
    
    /// Cash flows for each period
    @Attribute(.transformable(by: CashFlowsTransformer.self))
    var cashFlows: [Double]
    
    /// Discount rate for NPV (as percentage)
    var discountRate: Double
    
    /// Type of investment analysis
    private var analysisTypeRawValue: String
    
    /// Analysis type
    var analysisType: InvestmentAnalysisType {
        get {
            InvestmentAnalysisType(rawValue: analysisTypeRawValue) ?? .npv
        }
        set {
            analysisTypeRawValue = newValue.rawValue
        }
    }
    
    init(
        name: String,
        initialInvestment: Double,
        cashFlows: [Double] = [],
        discountRate: Double = 10.0,
        analysisType: InvestmentAnalysisType = .npv,
        currency: Currency = .usd
    ) {
        self.id = UUID()
        self.name = name
        self.createdDate = Date()
        self.lastModified = Date()
        self.notes = ""
        self.isFavorite = false
        self.currencyRawValue = currency.rawValue
        
        self.initialInvestment = initialInvestment
        self.cashFlows = cashFlows
        self.discountRate = discountRate
        self.analysisTypeRawValue = analysisType.rawValue
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
        
        // Combine initial investment with cash flows
        var allCashFlows = [-abs(initialInvestment)]
        allCashFlows.append(contentsOf: cashFlows)
        
        let calculatedValue: Double
        var secondaryValues: [String: Double] = [:]
        var explanation: String = ""
        
        switch analysisType {
        case .npv:
            calculatedValue = CalculationEngine.calculateNPV(
                cashFlows: allCashFlows,
                discountRate: discountRate
            )
            
            explanation = calculatedValue > 0 ? 
                "The investment is profitable at the given discount rate" :
                "The investment would result in a loss at the given discount rate"
            
            secondaryValues["Initial Investment"] = initialInvestment
            secondaryValues["Total Cash Inflows"] = cashFlows.reduce(0, +)
            secondaryValues["Discount Rate"] = discountRate
            
            // Calculate profitability index
            let presentValueOfInflows = CalculationEngine.calculateNPV(
                cashFlows: [0] + cashFlows,
                discountRate: discountRate
            )
            let profitabilityIndex = presentValueOfInflows / abs(initialInvestment)
            secondaryValues["Profitability Index"] = profitabilityIndex
            
        case .irr:
            calculatedValue = CalculationEngine.calculateIRR(cashFlows: allCashFlows)
            
            explanation = "The internal rate of return is the discount rate that makes NPV equal to zero"
            
            secondaryValues["Initial Investment"] = initialInvestment
            secondaryValues["Total Cash Inflows"] = cashFlows.reduce(0, +)
            
            // Calculate NPV at this IRR (should be close to 0)
            let npvAtIRR = CalculationEngine.calculateNPV(
                cashFlows: allCashFlows,
                discountRate: calculatedValue
            )
            secondaryValues["NPV at IRR"] = npvAtIRR
            
            // Calculate payback period
            var cumulativeCashFlow = -abs(initialInvestment)
            var paybackPeriod = 0.0
            for (index, cashFlow) in cashFlows.enumerated() {
                cumulativeCashFlow += cashFlow
                if cumulativeCashFlow >= 0 {
                    paybackPeriod = Double(index) + 1 - (cumulativeCashFlow - cashFlow) / cashFlow
                    break
                }
            }
            if paybackPeriod > 0 {
                secondaryValues["Payback Period"] = paybackPeriod
            }
            
        case .both:
            let npv = CalculationEngine.calculateNPV(
                cashFlows: allCashFlows,
                discountRate: discountRate
            )
            let irr = CalculationEngine.calculateIRR(cashFlows: allCashFlows)
            
            calculatedValue = npv // Primary value is NPV
            secondaryValues["IRR"] = irr
            secondaryValues["Initial Investment"] = initialInvestment
            secondaryValues["Total Cash Inflows"] = cashFlows.reduce(0, +)
            secondaryValues["Discount Rate"] = discountRate
            
            explanation = npv > 0 ? 
                "The investment is profitable with an IRR of \(String(format: "%.2f%%", irr))" :
                "The investment would result in a loss at the given discount rate"
        }
        
        // Generate chart data
        let chartData = generateCashFlowData()
        
        return CalculationResult(
            primaryValue: calculatedValue,
            secondaryValues: secondaryValues,
            formattedPrimaryValue: analysisType == .irr ? 
                String(format: "%.3f%%", calculatedValue) : 
                currency.formatValue(calculatedValue),
            explanation: explanation,
            chartData: chartData
        )
    }
    
    var isValid: Bool {
        guard !name.isEmpty else { return false }
        
        return initialInvestment != 0 &&
               !cashFlows.isEmpty &&
               discountRate >= 0
    }
    
    var validationErrors: [String] {
        var errors: [String] = []
        
        if name.isEmpty {
            errors.append("Name is required")
        }
        
        if initialInvestment == 0 {
            errors.append("Initial investment cannot be zero")
        }
        
        if cashFlows.isEmpty {
            errors.append("At least one cash flow is required")
        }
        
        if discountRate < 0 {
            errors.append("Discount rate cannot be negative")
        }
        
        return errors
    }
    
    /// Generate cash flow data for visualization
    private func generateCashFlowData() -> [ChartDataPoint] {
        var data: [ChartDataPoint] = []
        
        // Initial investment
        data.append(ChartDataPoint(
            x: 0,
            y: -abs(initialInvestment),
            label: "Initial Investment"
        ))
        
        // Cash flows
        for (index, cashFlow) in cashFlows.enumerated() {
            data.append(ChartDataPoint(
                x: Double(index + 1),
                y: cashFlow,
                label: "Period \(index + 1)"
            ))
        }
        
        return data
    }
}

// MARK: - Protocol Conformance

extension InvestmentCalculation: FinancialCalculationProtocol {}

/// Type of investment analysis
enum InvestmentAnalysisType: String, CaseIterable, Identifiable {
    case npv = "npv"
    case irr = "irr"
    case both = "both"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .npv:
            return "Net Present Value (NPV)"
        case .irr:
            return "Internal Rate of Return (IRR)"
        case .both:
            return "NPV & IRR"
        }
    }
    
    var description: String {
        switch self {
        case .npv:
            return "Calculate the present value of future cash flows"
        case .irr:
            return "Calculate the rate of return that makes NPV zero"
        case .both:
            return "Calculate both NPV and IRR for comprehensive analysis"
        }
    }
}

/// Custom transformer for cash flows array
final class CashFlowsTransformer: ValueTransformer {
    override func transformedValue(_ value: Any?) -> Any? {
        guard let cashFlows = value as? [Double] else { return nil }
        return try? JSONEncoder().encode(cashFlows)
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        return try? JSONDecoder().decode([Double].self, from: data)
    }
    
    override class func transformedValueClass() -> AnyClass {
        return NSData.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
}