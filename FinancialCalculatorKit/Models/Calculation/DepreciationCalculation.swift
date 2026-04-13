//
//  DepreciationCalculation.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import Foundation
import SwiftData

/// Depreciation calculation model for asset depreciation analysis
@Model
final class DepreciationCalculation {
    // MARK: - Common Properties
    var id: UUID
    var name: String
    private var calculationTypeRawValue: String = CalculationType.depreciation.rawValue
    var createdDate: Date
    var lastModified: Date
    var notes: String
    var isFavorite: Bool
    private var currencyRawValue: String
    
    /// Computed property for calculationType
    var calculationType: CalculationType {
        get {
            CalculationType(rawValue: calculationTypeRawValue) ?? .depreciation
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
    
    // MARK: - Depreciation Specific Properties
    /// Initial cost/value of the asset
    var assetCost: Double
    
    /// Salvage value at end of useful life
    var salvageValue: Double
    
    /// Useful life in years
    var usefulLife: Double
    
    /// Current year for depreciation calculation
    var currentYear: Double
    
    /// Depreciation method
    private var methodRawValue: String
    
    /// Depreciation method
    var method: DepreciationMethod {
        get {
            DepreciationMethod(rawValue: methodRawValue) ?? .straightLine
        }
        set {
            methodRawValue = newValue.rawValue
        }
    }
    
    /// MACRS property class (for MACRS method only)
    private var macrsClassRawValue: String?
    
    /// MACRS property class
    var macrsClass: MACRSPropertyClass? {
        get {
            guard let rawValue = macrsClassRawValue else { return nil }
            return MACRSPropertyClass(rawValue: rawValue)
        }
        set {
            macrsClassRawValue = newValue?.rawValue
        }
    }
    
    /// Declining balance rate (for declining balance method)
    var decliningBalanceRate: Double
    
    init(
        name: String,
        assetCost: Double,
        salvageValue: Double = 0.0,
        usefulLife: Double,
        currentYear: Double = 1.0,
        method: DepreciationMethod = .straightLine,
        decliningBalanceRate: Double = 2.0,
        currency: Currency = .usd
    ) {
        self.id = UUID()
        self.name = name
        self.createdDate = Date()
        self.lastModified = Date()
        self.notes = ""
        self.isFavorite = false
        self.currencyRawValue = currency.rawValue
        
        self.assetCost = assetCost
        self.salvageValue = salvageValue
        self.usefulLife = usefulLife
        self.currentYear = currentYear
        self.methodRawValue = method.rawValue
        self.decliningBalanceRate = decliningBalanceRate
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
        
        let depreciationSchedule = generateDepreciationSchedule()
        let currentYearIndex = Int(currentYear) - 1
        
        guard currentYearIndex >= 0 && currentYearIndex < depreciationSchedule.count else {
            return CalculationResult(
                primaryValue: 0.0,
                formattedPrimaryValue: "Invalid year",
                explanation: "Current year is outside the asset's useful life."
            )
        }
        
        let currentYearDepreciation = depreciationSchedule[currentYearIndex].depreciation
        var secondaryValues: [String: Double] = [:]
        
        // Calculate cumulative depreciation up to current year
        let cumulativeDepreciation = depreciationSchedule.prefix(Int(currentYear))
            .reduce(0) { $0 + $1.depreciation }
        
        let bookValue = assetCost - cumulativeDepreciation
        
        secondaryValues["Asset Cost"] = assetCost
        secondaryValues["Salvage Value"] = salvageValue
        secondaryValues["Useful Life"] = usefulLife
        secondaryValues["Current Year"] = currentYear
        secondaryValues["Cumulative Depreciation"] = cumulativeDepreciation
        secondaryValues["Book Value"] = bookValue
        secondaryValues["Depreciable Base"] = assetCost - salvageValue
        
        // Calculate depreciation rate for current method
        let depreciationRate = calculateDepreciationRate()
        if depreciationRate > 0 {
            secondaryValues["Depreciation Rate"] = depreciationRate * 100
        }
        
        let explanation = generateExplanation()
        
        // Generate chart data
        let chartData = depreciationSchedule.enumerated().map { index, item in
            ChartDataPoint(
                x: Double(index + 1),
                y: item.depreciation,
                label: "Year \(index + 1)"
            )
        }
        
        return CalculationResult(
            primaryValue: currentYearDepreciation,
            secondaryValues: secondaryValues,
            formattedPrimaryValue: currency.formatValue(currentYearDepreciation),
            explanation: explanation,
            chartData: chartData
        )
    }
    
    var isValid: Bool {
        guard !name.isEmpty else { return false }
        
        return assetCost > 0 &&
               salvageValue >= 0 &&
               salvageValue < assetCost &&
               usefulLife > 0 &&
               currentYear > 0 &&
               currentYear <= usefulLife &&
               decliningBalanceRate > 0
    }
    
    var validationErrors: [String] {
        var errors: [String] = []
        
        if name.isEmpty {
            errors.append("Name is required")
        }
        
        if assetCost <= 0 {
            errors.append("Asset cost must be positive")
        }
        
        if salvageValue < 0 {
            errors.append("Salvage value cannot be negative")
        }
        
        if salvageValue >= assetCost {
            errors.append("Salvage value must be less than asset cost")
        }
        
        if usefulLife <= 0 {
            errors.append("Useful life must be positive")
        }
        
        if currentYear <= 0 || currentYear > usefulLife {
            errors.append("Current year must be between 1 and useful life")
        }
        
        if decliningBalanceRate <= 0 {
            errors.append("Declining balance rate must be positive")
        }
        
        if method == .macrs && macrsClass == nil {
            errors.append("MACRS property class is required for MACRS method")
        }
        
        return errors
    }
    
    /// Generate complete depreciation schedule
    func generateDepreciationSchedule() -> [DepreciationEntry] {
        var schedule: [DepreciationEntry] = []
        let years = Int(usefulLife)
        
        switch method {
        case .straightLine:
            let annualDepreciation = (assetCost - salvageValue) / usefulLife
            for year in 1...years {
                schedule.append(DepreciationEntry(
                    year: year,
                    depreciation: annualDepreciation,
                    cumulativeDepreciation: annualDepreciation * Double(year),
                    bookValue: assetCost - (annualDepreciation * Double(year))
                ))
            }
            
        case .decliningBalance:
            let rate = decliningBalanceRate / usefulLife
            var bookValue = assetCost
            var cumulativeDepreciation = 0.0
            
            for year in 1...years {
                let maxDepreciation = bookValue - salvageValue
                let calculatedDepreciation = bookValue * rate
                let depreciation = min(calculatedDepreciation, maxDepreciation)
                
                cumulativeDepreciation += depreciation
                bookValue -= depreciation
                
                schedule.append(DepreciationEntry(
                    year: year,
                    depreciation: depreciation,
                    cumulativeDepreciation: cumulativeDepreciation,
                    bookValue: bookValue
                ))
            }
            
        case .sumOfYearsDigits:
            let sumOfYears = (usefulLife * (usefulLife + 1)) / 2
            let depreciableBase = assetCost - salvageValue
            var cumulativeDepreciation = 0.0
            
            for year in 1...years {
                let remainingLife = usefulLife - Double(year - 1)
                let depreciation = (remainingLife / sumOfYears) * depreciableBase
                cumulativeDepreciation += depreciation
                
                schedule.append(DepreciationEntry(
                    year: year,
                    depreciation: depreciation,
                    cumulativeDepreciation: cumulativeDepreciation,
                    bookValue: assetCost - cumulativeDepreciation
                ))
            }
            
        case .macrs:
            guard let macrsClass = macrsClass else { break }
            let rates = macrsClass.depreciationRates
            let depreciableBase = assetCost // MACRS doesn't use salvage value
            var cumulativeDepreciation = 0.0
            
            for (index, rate) in rates.enumerated() {
                let year = index + 1
                let depreciation = depreciableBase * rate
                cumulativeDepreciation += depreciation
                
                schedule.append(DepreciationEntry(
                    year: year,
                    depreciation: depreciation,
                    cumulativeDepreciation: cumulativeDepreciation,
                    bookValue: assetCost - cumulativeDepreciation
                ))
            }
        }
        
        return schedule
    }
    
    private func calculateDepreciationRate() -> Double {
        switch method {
        case .straightLine:
            return 1.0 / usefulLife
        case .decliningBalance:
            return decliningBalanceRate / usefulLife
        case .sumOfYearsDigits:
            let sumOfYears = (usefulLife * (usefulLife + 1)) / 2
            let remainingLife = usefulLife - (currentYear - 1)
            return remainingLife / sumOfYears
        case .macrs:
            guard let macrsClass = macrsClass else { return 0 }
            let yearIndex = Int(currentYear) - 1
            guard yearIndex >= 0 && yearIndex < macrsClass.depreciationRates.count else { return 0 }
            return macrsClass.depreciationRates[yearIndex]
        }
    }
    
    private func generateExplanation() -> String {
        switch method {
        case .straightLine:
            return "Straight-line depreciation spreads the cost evenly over the asset's useful life"
        case .decliningBalance:
            return "Declining balance method accelerates depreciation in early years"
        case .sumOfYearsDigits:
            return "Sum-of-years digits method provides moderate acceleration of depreciation"
        case .macrs:
            return "MACRS is the tax depreciation system used in the United States"
        }
    }
}

// MARK: - Protocol Conformance

extension DepreciationCalculation: FinancialCalculationProtocol {}

/// Depreciation methods
enum DepreciationMethod: String, CaseIterable, Identifiable {
    case straightLine = "straightLine"
    case decliningBalance = "decliningBalance"
    case sumOfYearsDigits = "sumOfYearsDigits"
    case macrs = "macrs"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .straightLine:
            return "Straight-Line"
        case .decliningBalance:
            return "Declining Balance"
        case .sumOfYearsDigits:
            return "Sum-of-Years Digits"
        case .macrs:
            return "MACRS"
        }
    }
    
    var description: String {
        switch self {
        case .straightLine:
            return "Equal depreciation each year"
        case .decliningBalance:
            return "Higher depreciation in early years"
        case .sumOfYearsDigits:
            return "Accelerated depreciation based on remaining life"
        case .macrs:
            return "Modified Accelerated Cost Recovery System (US tax)"
        }
    }
}

/// MACRS property classes
enum MACRSPropertyClass: String, CaseIterable, Identifiable {
    case threeYear = "3-year"
    case fiveYear = "5-year"
    case sevenYear = "7-year"
    case tenYear = "10-year"
    case fifteenYear = "15-year"
    case twentyYear = "20-year"
    
    var id: String { rawValue }
    
    var displayName: String {
        return rawValue.capitalized + " Property"
    }
    
    var description: String {
        switch self {
        case .threeYear:
            return "Research equipment, racehorses over 2 years old"
        case .fiveYear:
            return "Cars, trucks, computers, office equipment"
        case .sevenYear:
            return "Office furniture, appliances, most machinery"
        case .tenYear:
            return "Boats, fruit trees, single-purpose structures"
        case .fifteenYear:
            return "Land improvements, roads, fences"
        case .twentyYear:
            return "Farm buildings, municipal sewers"
        }
    }
    
    var depreciationRates: [Double] {
        switch self {
        case .threeYear:
            return [0.3333, 0.4445, 0.1481, 0.0741]
        case .fiveYear:
            return [0.2000, 0.3200, 0.1920, 0.1152, 0.1152, 0.0576]
        case .sevenYear:
            return [0.1429, 0.2449, 0.1749, 0.1249, 0.0893, 0.0892, 0.0893, 0.0446]
        case .tenYear:
            return [0.1000, 0.1800, 0.1440, 0.1152, 0.0922, 0.0737, 0.0655, 0.0655, 0.0656, 0.0655, 0.0328]
        case .fifteenYear:
            return [0.0500, 0.0950, 0.0855, 0.0770, 0.0693, 0.0623, 0.0590, 0.0590, 0.0591, 0.0590, 0.0591, 0.0590, 0.0591, 0.0590, 0.0591, 0.0295]
        case .twentyYear:
            return [0.0375, 0.0722, 0.0668, 0.0618, 0.0571, 0.0528, 0.0489, 0.0452, 0.0447, 0.0447, 0.0446, 0.0446, 0.0446, 0.0446, 0.0446, 0.0446, 0.0446, 0.0446, 0.0446, 0.0446, 0.0223]
        }
    }
}

/// Depreciation schedule entry
struct DepreciationEntry: Identifiable {
    let id = UUID()
    let year: Int
    let depreciation: Double
    let cumulativeDepreciation: Double
    let bookValue: Double
}