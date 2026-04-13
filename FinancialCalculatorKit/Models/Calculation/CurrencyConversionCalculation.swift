//
//  CurrencyConversionCalculation.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/9/25.
//

import Foundation
import SwiftData

/// Currency conversion history model
@Model
final class CurrencyConversionCalculation {
    // MARK: - Common Properties
    var id: UUID
    var name: String
    private var calculationTypeRawValue: String = CalculationType.currency.rawValue
    var createdDate: Date
    var lastModified: Date
    var notes: String
    var isFavorite: Bool
    private var currencyRawValue: String // Target currency

    /// Computed property for calculationType
    var calculationType: CalculationType {
        get {
            CalculationType(rawValue: calculationTypeRawValue) ?? .currency
        }
        set {
            calculationTypeRawValue = newValue.rawValue
        }
    }

    /// Target Currency
    var currency: Currency {
        get {
            Currency(rawValue: currencyRawValue) ?? .usd
        }
        set {
            currencyRawValue = newValue.rawValue
        }
    }

    // MARK: - Conversion Specific Properties
    var sourceAmount: Double
    private var sourceCurrencyRawValue: String
    var exchangeRate: Double

    var sourceCurrency: Currency {
        get {
            Currency(rawValue: sourceCurrencyRawValue) ?? .usd
        }
        set {
            sourceCurrencyRawValue = newValue.rawValue
        }
    }

    init(
        name: String,
        sourceAmount: Double,
        sourceCurrency: Currency,
        targetCurrency: Currency,
        exchangeRate: Double
    ) {
        self.id = UUID()
        self.name = name
        self.createdDate = Date()
        self.lastModified = Date()
        self.notes = ""
        self.isFavorite = false
        self.currencyRawValue = targetCurrency.rawValue

        self.sourceAmount = sourceAmount
        self.sourceCurrencyRawValue = sourceCurrency.rawValue
        self.exchangeRate = exchangeRate
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
        let convertedAmount = sourceAmount * exchangeRate

        var secondaryValues: [String: Double] = [:]
        secondaryValues["Source Amount"] = sourceAmount
        secondaryValues["Exchange Rate"] = exchangeRate

        return CalculationResult(
            primaryValue: convertedAmount,
            secondaryValues: secondaryValues,
            formattedPrimaryValue: currency.formatValue(convertedAmount),
            explanation: "Converted \(sourceCurrency.formatValue(sourceAmount)) to \(currency.displayName)"
        )
    }

    var isValid: Bool {
        return !name.isEmpty && sourceAmount >= 0 && exchangeRate > 0
    }

    var validationErrors: [String] {
        var errors: [String] = []
        if name.isEmpty { errors.append("Name is required") }
        if sourceAmount < 0 { errors.append("Amount cannot be negative") }
        if exchangeRate <= 0 { errors.append("Exchange rate must be positive") }
        return errors
    }
}

extension CurrencyConversionCalculation: FinancialCalculationProtocol {}
