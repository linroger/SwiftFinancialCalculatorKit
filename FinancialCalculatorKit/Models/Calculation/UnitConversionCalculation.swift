//
//  UnitConversionCalculation.swift
//  FinancialCalculatorKit
//
//  Saved unit conversion, so the converter participates in the same sidebar,
//  dashboard, favorite, and restore flows as every other calculator.
//

import Foundation
import SwiftData

@Model
final class UnitConversionCalculation {
    // MARK: - Common Properties
    var id: UUID
    var name: String
    private var calculationTypeRawValue: String = CalculationType.conversion.rawValue
    var createdDate: Date
    var lastModified: Date
    var notes: String
    var isFavorite: Bool
    private var currencyRawValue: String

    var calculationType: CalculationType {
        get { CalculationType(rawValue: calculationTypeRawValue) ?? .conversion }
        set { calculationTypeRawValue = newValue.rawValue }
    }

    /// Unit conversions are currency-free, but the protocol and shared UI
    /// expect a currency, so this tracks the app default without using it.
    var currency: Currency {
        get { Currency(rawValue: currencyRawValue) ?? .usd }
        set { currencyRawValue = newValue.rawValue }
    }

    // MARK: - Conversion Properties

    var inputValue: Double
    var outputValue: Double
    var fromUnit: String
    var toUnit: String
    private var categoryRawValue: String

    var category: UnitCategory {
        get { UnitCategory(rawValue: categoryRawValue) ?? .length }
        set { categoryRawValue = newValue.rawValue }
    }

    init(
        name: String,
        inputValue: Double,
        outputValue: Double,
        fromUnit: String,
        toUnit: String,
        category: UnitCategory,
        currency: Currency = .usd
    ) {
        self.id = UUID()
        self.name = name
        self.createdDate = Date()
        self.lastModified = Date()
        self.notes = ""
        self.isFavorite = false
        self.currencyRawValue = currency.rawValue

        self.inputValue = inputValue
        self.outputValue = outputValue
        self.fromUnit = fromUnit
        self.toUnit = toUnit
        self.categoryRawValue = category.rawValue
    }

    // MARK: - Common Protocol Methods

    func updateTimestamp() {
        lastModified = Date()
    }

    func toggleFavorite() {
        isFavorite.toggle()
        updateTimestamp()
    }

    var result: CalculationResult {
        guard isValid else {
            return CalculationResult(
                primaryValue: 0.0,
                formattedPrimaryValue: "Invalid inputs",
                explanation: "Select both units before saving a conversion."
            )
        }

        return CalculationResult(
            primaryValue: outputValue,
            secondaryValues: ["Input Value": inputValue],
            formattedPrimaryValue: "\(formatted(outputValue)) \(toUnit)",
            explanation: "\(formatted(inputValue)) \(fromUnit) = \(formatted(outputValue)) \(toUnit)"
        )
    }

    var isValid: Bool {
        validationErrors.isEmpty
    }

    var validationErrors: [String] {
        var errors: [String] = []
        if name.isEmpty { errors.append("Name is required") }
        if fromUnit.isEmpty || toUnit.isEmpty { errors.append("Both units must be selected") }
        return errors
    }

    /// Trims trailing zeros so "2.5 km" does not read "2.500000 km".
    private func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 6
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

// MARK: - Protocol Conformance

extension UnitConversionCalculation: FinancialCalculationProtocol {}
