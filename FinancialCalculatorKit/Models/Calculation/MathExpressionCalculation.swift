//
//  MathExpressionCalculation.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/9/25.
//

import Foundation
import SwiftData

/// Math expression calculation model
@Model
final class MathExpressionCalculation {
    // MARK: - Common Properties
    var id: UUID
    var name: String
    private var calculationTypeRawValue: String = CalculationType.mathExpression.rawValue
    var createdDate: Date
    var lastModified: Date
    var notes: String
    var isFavorite: Bool
    private var currencyRawValue: String

    /// Computed property for calculationType
    var calculationType: CalculationType {
        get {
            CalculationType(rawValue: calculationTypeRawValue) ?? .mathExpression
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

    // MARK: - Math Expression Specific Properties
    /// The mathematical expression string
    var expression: String

    /// Variables used in the expression (JSON encoded)
    @Attribute(.transformable(by: StringDoubleMapTransformer.self))
    var variables: [String: Double]

    init(
        name: String,
        expression: String,
        variables: [String: Double] = [:],
        currency: Currency = .usd
    ) {
        self.id = UUID()
        self.name = name
        self.createdDate = Date()
        self.lastModified = Date()
        self.notes = ""
        self.isFavorite = false
        self.currencyRawValue = currency.rawValue

        self.expression = expression
        self.variables = variables
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
                explanation: "Please provide a valid expression."
            )
        }

        let calculatedValue = CalculationEngine.evaluateExpression(expression, with: variables) ?? 0.0

        return CalculationResult(
            primaryValue: calculatedValue,
            secondaryValues: variables,
            formattedPrimaryValue: String(format: "%.4f", calculatedValue),
            explanation: "Result of evaluating: \(expression)"
        )
    }

    var isValid: Bool {
        return !name.isEmpty && !expression.isEmpty
    }

    var validationErrors: [String] {
        var errors: [String] = []
        if name.isEmpty { errors.append("Name is required") }
        if expression.isEmpty { errors.append("Expression is required") }
        return errors
    }
}

extension MathExpressionCalculation: FinancialCalculationProtocol {}

// Transformer for [String: Double] dictionary
final class StringDoubleMapTransformer: ValueTransformer {
    override func transformedValue(_ value: Any?) -> Any? {
        guard let dict = value as? [String: Double] else { return nil }
        return try? JSONEncoder().encode(dict)
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        return try? JSONDecoder().decode([String: Double].self, from: data)
    }

    override class func transformedValueClass() -> AnyClass {
        return NSData.self
    }

    override class func allowsReverseTransformation() -> Bool {
        return true
    }
}
