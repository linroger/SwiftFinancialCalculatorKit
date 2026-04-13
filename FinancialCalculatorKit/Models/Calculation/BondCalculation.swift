//
//  BondCalculation.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import Foundation
import SwiftData

/// Bond calculation model for pricing and yield analysis
@Model
final class BondCalculation {
    // MARK: - Common Properties
    var id: UUID
    var name: String
    private var calculationTypeRawValue: String = CalculationType.bond.rawValue
    var createdDate: Date
    var lastModified: Date
    var notes: String
    var isFavorite: Bool
    private var currencyRawValue: String
    
    /// Computed property for calculationType
    var calculationType: CalculationType {
        get {
            CalculationType(rawValue: calculationTypeRawValue) ?? .bond
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
    
    // MARK: - Bond Specific Properties
    /// Face value (par value) of the bond
    var faceValue: Double
    
    /// Coupon rate (annual percentage)
    var couponRate: Double
    
    /// Market rate/required yield (annual percentage)
    var marketRate: Double?
    
    /// Current price of the bond
    var currentPrice: Double?
    
    /// Years to maturity
    var yearsToMaturity: Double
    
    /// Number of coupon payments per year
    var paymentsPerYear: Double
    
    /// Bond type for solving
    private var solveForRawValue: String
    
    /// What to solve for
    var solveFor: BondSolveFor {
        get {
            BondSolveFor(rawValue: solveForRawValue) ?? .price
        }
        set {
            solveForRawValue = newValue.rawValue
        }
    }
    
    init(
        name: String,
        faceValue: Double,
        couponRate: Double,
        yearsToMaturity: Double,
        paymentsPerYear: Double = 2,
        solveFor: BondSolveFor = .price,
        currency: Currency = .usd
    ) {
        self.id = UUID()
        self.name = name
        self.createdDate = Date()
        self.lastModified = Date()
        self.notes = ""
        self.isFavorite = false
        self.currencyRawValue = currency.rawValue
        
        self.faceValue = faceValue
        self.couponRate = couponRate
        self.yearsToMaturity = yearsToMaturity
        self.paymentsPerYear = paymentsPerYear
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
        
        let calculatedValue: Double
        var secondaryValues: [String: Double] = [:]
        var explanation: String = ""
        
        switch solveFor {
        case .price:
            guard let marketRate = marketRate else {
                return CalculationResult(
                    primaryValue: 0.0,
                    formattedPrimaryValue: "Missing market rate",
                    explanation: "Please provide the market interest rate."
                )
            }
            
            calculatedValue = CalculationEngine.calculateBondPrice(
                faceValue: faceValue,
                couponRate: couponRate,
                marketRate: marketRate,
                yearsToMaturity: yearsToMaturity,
                paymentsPerYear: paymentsPerYear
            )
            
            explanation = "The theoretical price of the bond based on current market rates"
            secondaryValues["Face Value"] = faceValue
            secondaryValues["Coupon Rate"] = couponRate
            secondaryValues["Market Rate"] = marketRate
            secondaryValues["Annual Coupon"] = faceValue * couponRate / 100
            
            // Calculate premium/discount
            let premiumDiscount = calculatedValue - faceValue
            secondaryValues["Premium/Discount"] = premiumDiscount
            
        case .yield:
            guard let currentPrice = currentPrice else {
                return CalculationResult(
                    primaryValue: 0.0,
                    formattedPrimaryValue: "Missing current price",
                    explanation: "Please provide the current market price of the bond."
                )
            }
            
            calculatedValue = CalculationEngine.calculateBondYTM(
                faceValue: faceValue,
                currentPrice: currentPrice,
                couponRate: couponRate,
                yearsToMaturity: yearsToMaturity,
                paymentsPerYear: paymentsPerYear
            )
            
            explanation = "The yield to maturity (YTM) if held until maturity"
            secondaryValues["Face Value"] = faceValue
            secondaryValues["Current Price"] = currentPrice
            secondaryValues["Coupon Rate"] = couponRate
            secondaryValues["Annual Coupon"] = faceValue * couponRate / 100
            
            // Calculate current yield
            let currentYield = (faceValue * couponRate / 100) / currentPrice * 100
            secondaryValues["Current Yield"] = currentYield
        }
        
        secondaryValues["Years to Maturity"] = yearsToMaturity
        secondaryValues["Total Payments"] = yearsToMaturity * paymentsPerYear
        
        // Generate cash flow data
        let chartData = generateCashFlowData()
        
        return CalculationResult(
            primaryValue: calculatedValue,
            secondaryValues: secondaryValues,
            formattedPrimaryValue: solveFor == .price ? currency.formatValue(calculatedValue) : String(format: "%.3f%%", calculatedValue),
            explanation: explanation,
            chartData: chartData
        )
    }
    
    var isValid: Bool {
        guard !name.isEmpty else { return false }
        
        return faceValue > 0 &&
               couponRate >= 0 &&
               yearsToMaturity > 0 &&
               paymentsPerYear > 0
    }
    
    var validationErrors: [String] {
        var errors: [String] = []
        
        if name.isEmpty {
            errors.append("Name is required")
        }
        
        if faceValue <= 0 {
            errors.append("Face value must be positive")
        }
        
        if couponRate < 0 {
            errors.append("Coupon rate cannot be negative")
        }
        
        if yearsToMaturity <= 0 {
            errors.append("Years to maturity must be positive")
        }
        
        if paymentsPerYear <= 0 {
            errors.append("Payments per year must be positive")
        }
        
        if solveFor == .price && marketRate == nil {
            errors.append("Market rate is required to calculate price")
        }
        
        if solveFor == .yield && currentPrice == nil {
            errors.append("Current price is required to calculate yield")
        }
        
        return errors
    }
    
    /// Generate cash flow data for visualization
    private func generateCashFlowData() -> [ChartDataPoint] {
        var data: [ChartDataPoint] = []
        let couponPayment = faceValue * couponRate / 100 / paymentsPerYear
        let totalPeriods = Int(yearsToMaturity * paymentsPerYear)
        
        for period in 1...totalPeriods {
            let year = Double(period) / paymentsPerYear
            var cashFlow = couponPayment
            
            // Add face value at maturity
            if period == totalPeriods {
                cashFlow += faceValue
            }
            
            data.append(ChartDataPoint(
                x: year,
                y: cashFlow,
                label: period == totalPeriods ? "Final Payment + Principal" : "Coupon Payment"
            ))
        }
        
        return data
    }
}

// MARK: - Protocol Conformance

extension BondCalculation: FinancialCalculationProtocol {}

/// What to solve for in bond calculations
enum BondSolveFor: String, CaseIterable, Identifiable {
    case price = "price"
    case yield = "yield"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .price:
            return "Bond Price"
        case .yield:
            return "Yield to Maturity (YTM)"
        }
    }
    
    var description: String {
        switch self {
        case .price:
            return "Calculate the theoretical price of the bond"
        case .yield:
            return "Calculate the yield to maturity based on current price"
        }
    }
}