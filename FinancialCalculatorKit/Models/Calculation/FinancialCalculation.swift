//
//  FinancialCalculation.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import Foundation
import SwiftData

/// Protocol defining common behavior for financial calculations
protocol FinancialCalculationProtocol {
    var id: UUID { get }
    var name: String { get set }
    var calculationType: CalculationType { get }
    var createdDate: Date { get }
    var lastModified: Date { get set }
    var notes: String { get set }
    var isFavorite: Bool { get set }
    var currency: Currency { get set }
    
    var result: CalculationResult { get }
    var isValid: Bool { get }
    var validationErrors: [String] { get }
    
    func updateTimestamp()
    func toggleFavorite()
}

/// Base financial calculation model with common properties
@Model
final class FinancialCalculation {
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
    
    /// Computed result of the calculation
    var result: CalculationResult {
        CalculationResult(
            primaryValue: 0.0,
            secondaryValues: [:],
            formattedPrimaryValue: "Not calculated",
            explanation: "Generic calculation - specific calculations implemented in dedicated models"
        )
    }
    
    init(
        name: String,
        calculationType: CalculationType,
        currency: Currency = .usd,
        notes: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.calculationTypeRawValue = calculationType.rawValue
        self.createdDate = Date()
        self.lastModified = Date()
        self.notes = notes
        self.isFavorite = false
        self.currencyRawValue = currency.rawValue
    }
    
    /// Update the last modified timestamp
    func updateTimestamp() {
        lastModified = Date()
    }
    
    /// Toggle favorite status
    func toggleFavorite() {
        isFavorite.toggle()
        updateTimestamp()
    }
    
    /// Validate that all required inputs are provided
    var isValid: Bool {
        return !name.isEmpty
    }
    
    /// Get validation errors
    var validationErrors: [String] {
        var errors: [String] = []
        if name.isEmpty {
            errors.append("Name is required")
        }
        return errors
    }
}

// MARK: - Protocol Conformance

extension FinancialCalculation: FinancialCalculationProtocol {}

/// Result structure for financial calculations
struct CalculationResult {
    let primaryValue: Double
    let secondaryValues: [String: Double]
    let formattedPrimaryValue: String
    let explanation: String
    let chartData: [ChartDataPoint]?
    let tableData: [TableRow]?
    
    /// Whether the calculation result is valid
    var isValid: Bool {
        return !formattedPrimaryValue.contains("Invalid") && !formattedPrimaryValue.contains("Missing")
    }
    
    init(
        primaryValue: Double,
        secondaryValues: [String: Double] = [:],
        formattedPrimaryValue: String,
        explanation: String,
        chartData: [ChartDataPoint]? = nil,
        tableData: [TableRow]? = nil
    ) {
        self.primaryValue = primaryValue
        self.secondaryValues = secondaryValues
        self.formattedPrimaryValue = formattedPrimaryValue
        self.explanation = explanation
        self.chartData = chartData
        self.tableData = tableData
    }
}

/// Data point for charts
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
    let label: String?
    let date: Date?
    
    init(x: Double, y: Double, label: String? = nil, date: Date? = nil) {
        self.x = x
        self.y = y
        self.label = label
        self.date = date
    }
}

/// Row data for tables
struct TableRow: Identifiable {
    let id = UUID()
    let values: [String: String]
    
    init(values: [String: String]) {
        self.values = values
    }
}

/// Validation result for calculations
struct ValidationResult {
    let isValid: Bool
    let errors: [String]
    
    static let valid = ValidationResult(isValid: true, errors: [])
    
    init(isValid: Bool, errors: [String]) {
        self.isValid = isValid
        self.errors = errors
    }
}