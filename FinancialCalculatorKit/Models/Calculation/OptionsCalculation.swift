//
//  OptionsCalculation.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/9/25.
//

import Foundation
import SwiftData

/// Options pricing calculation model
@Model
final class OptionsCalculation {
    // MARK: - Common Properties
    var id: UUID
    var name: String
    private var calculationTypeRawValue: String = CalculationType.options.rawValue
    var createdDate: Date
    var lastModified: Date
    var notes: String
    var isFavorite: Bool
    private var currencyRawValue: String

    /// Computed property for calculationType
    var calculationType: CalculationType {
        get {
            CalculationType(rawValue: calculationTypeRawValue) ?? .options
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

    // MARK: - Options Specific Properties
    /// Current price of the underlying asset
    var spotPrice: Double

    /// Strike price of the option
    var strikePrice: Double

    /// Time to expiration in years
    var timeToExpiry: Double

    /// Risk-free interest rate (as percentage)
    var riskFreeRate: Double

    /// Volatility (as percentage)
    var volatility: Double

    /// Option type (call or put)
    private var optionTypeRawValue: String

    /// Option type enum wrapper
    var optionType: CalculationEngine.OptionType {
        get {
            switch optionTypeRawValue {
            case "call": return .call
            case "put": return .put
            default: return .call
            }
        }
        set {
            switch newValue {
            case .call: optionTypeRawValue = "call"
            case .put: optionTypeRawValue = "put"
            }
        }
    }

    init(
        name: String,
        spotPrice: Double,
        strikePrice: Double,
        timeToExpiry: Double,
        riskFreeRate: Double,
        volatility: Double,
        optionType: CalculationEngine.OptionType = .call,
        currency: Currency = .usd
    ) {
        self.id = UUID()
        self.name = name
        self.createdDate = Date()
        self.lastModified = Date()
        self.notes = ""
        self.isFavorite = false
        self.currencyRawValue = currency.rawValue

        self.spotPrice = spotPrice
        self.strikePrice = strikePrice
        self.timeToExpiry = timeToExpiry
        self.riskFreeRate = riskFreeRate
        self.volatility = volatility
        self.optionTypeRawValue = optionType == .call ? "call" : "put"
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
                explanation: "Please provide valid inputs for all required fields."
            )
        }

        let optionPrice = CalculationEngine.calculateBlackScholesOptionPrice(
            spotPrice: spotPrice,
            strikePrice: strikePrice,
            timeToExpiry: timeToExpiry,
            riskFreeRate: riskFreeRate,
            volatility: volatility,
            optionType: optionType
        )

        let greeks = CalculationEngine.calculateOptionGreeks(
            spotPrice: spotPrice,
            strikePrice: strikePrice,
            timeToExpiry: timeToExpiry,
            riskFreeRate: riskFreeRate,
            volatility: volatility,
            optionType: optionType
        )

        var secondaryValues: [String: Double] = [:]
        secondaryValues["Spot Price"] = spotPrice
        secondaryValues["Strike Price"] = strikePrice
        secondaryValues["Time to Expiry"] = timeToExpiry
        secondaryValues["Risk Free Rate"] = riskFreeRate
        secondaryValues["Volatility"] = volatility
        secondaryValues["Delta"] = greeks.delta
        secondaryValues["Gamma"] = greeks.gamma
        secondaryValues["Theta"] = greeks.theta
        secondaryValues["Vega"] = greeks.vega
        secondaryValues["Rho"] = greeks.rho

        let explanation = "Theoretical price for a \(optionTypeRawValue.capitalized) option using Black-Scholes model."

        // Generate sensitivity chart data (Price vs Spot Price)
        let chartData = generateSensitivityData()

        return CalculationResult(
            primaryValue: optionPrice,
            secondaryValues: secondaryValues,
            formattedPrimaryValue: currency.formatValue(optionPrice),
            explanation: explanation,
            chartData: chartData
        )
    }

    var isValid: Bool {
        return !name.isEmpty && spotPrice > 0 && strikePrice > 0 && timeToExpiry > 0 && volatility > 0
    }

    var validationErrors: [String] {
        var errors: [String] = []
        if name.isEmpty { errors.append("Name is required") }
        if spotPrice <= 0 { errors.append("Spot price must be positive") }
        if strikePrice <= 0 { errors.append("Strike price must be positive") }
        if timeToExpiry <= 0 { errors.append("Time to expiry must be positive") }
        if volatility <= 0 { errors.append("Volatility must be positive") }
        return errors
    }

    private func generateSensitivityData() -> [ChartDataPoint] {
        var data: [ChartDataPoint] = []
        let range = spotPrice * 0.5
        let start = max(0, spotPrice - range)
        let end = spotPrice + range
        let steps = 20
        let stepSize = (end - start) / Double(steps)

        for i in 0...steps {
            let s = start + Double(i) * stepSize
            let price = CalculationEngine.calculateBlackScholesOptionPrice(
                spotPrice: s,
                strikePrice: strikePrice,
                timeToExpiry: timeToExpiry,
                riskFreeRate: riskFreeRate,
                volatility: volatility,
                optionType: optionType
            )
            data.append(ChartDataPoint(x: s, y: price, label: String(format: "%.0f", s)))
        }
        return data
    }
}

extension OptionsCalculation: FinancialCalculationProtocol {}
