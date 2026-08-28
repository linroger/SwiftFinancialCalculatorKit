//
//  DebtPayoffCalculation.swift
//  FinancialCalculatorKit
//
//  Saved multi-debt payoff plan.
//

import Foundation
import SwiftData

@Model
final class DebtPayoffCalculation {
    // MARK: - Common Properties
    var id: UUID
    var name: String
    private var calculationTypeRawValue: String = CalculationType.debtPayoff.rawValue
    var createdDate: Date
    var lastModified: Date
    var notes: String
    var isFavorite: Bool
    private var currencyRawValue: String

    var calculationType: CalculationType {
        get { CalculationType(rawValue: calculationTypeRawValue) ?? .debtPayoff }
        set { calculationTypeRawValue = newValue.rawValue }
    }

    var currency: Currency {
        get { Currency(rawValue: currencyRawValue) ?? .usd }
        set { currencyRawValue = newValue.rawValue }
    }

    // MARK: - Plan Properties

    /// Debts stored as JSON. SwiftData handles `Data` natively, so this avoids
    /// registering a value transformer for the array.
    private var debtsData: Data

    /// Amount paid each month on top of the combined minimums
    var extraPayment: Double

    private var strategyRawValue: String

    var debts: [Debt] {
        get { (try? JSONDecoder().decode([Debt].self, from: debtsData)) ?? [] }
        set { debtsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var strategy: PayoffStrategy {
        get { PayoffStrategy(rawValue: strategyRawValue) ?? .avalanche }
        set { strategyRawValue = newValue.rawValue }
    }

    init(
        name: String,
        debts: [Debt],
        extraPayment: Double = 0,
        strategy: PayoffStrategy = .avalanche,
        currency: Currency = .usd
    ) {
        self.id = UUID()
        self.name = name
        self.createdDate = Date()
        self.lastModified = Date()
        self.notes = ""
        self.isFavorite = false
        self.currencyRawValue = currency.rawValue

        self.debtsData = (try? JSONEncoder().encode(debts)) ?? Data()
        self.extraPayment = extraPayment
        self.strategyRawValue = strategy.rawValue
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
                explanation: "Please provide at least one debt with a positive balance."
            )
        }

        guard let plan = try? DebtPayoffPlanner.plan(
            debts: debts,
            extraPayment: extraPayment,
            strategy: strategy
        ) else {
            return CalculationResult(
                primaryValue: 0.0,
                formattedPrimaryValue: "No payoff",
                explanation: "At this budget the balances never retire — the monthly payment does not outpace the interest."
            )
        }

        var secondaryValues: [String: Double] = [:]
        secondaryValues["Total Interest"] = plan.totalInterest
        secondaryValues["Total Paid"] = plan.totalPaid
        secondaryValues["Monthly Budget"] = plan.monthlyBudget
        secondaryValues["Debts"] = Double(debts.count)
        secondaryValues["Starting Balance"] = debts.reduce(0) { $0 + $1.balance }

        let years = Double(plan.months) / 12
        return CalculationResult(
            primaryValue: Double(plan.months),
            secondaryValues: secondaryValues,
            formattedPrimaryValue: Formatters.formatDuration(years: years),
            explanation: "Debt-free in \(plan.months) months using the \(strategy.displayName.lowercased()) strategy.",
            chartData: plan.balanceTimeline.map {
                ChartDataPoint(
                    x: Double($0.month),
                    y: $0.totalBalance,
                    label: "Month \($0.month)"
                )
            }
        )
    }

    var isValid: Bool {
        validationErrors.isEmpty
    }

    var validationErrors: [String] {
        var errors: [String] = []

        if name.isEmpty {
            errors.append("Name is required")
        }
        let live = debts.filter { $0.balance > 0 }
        if live.isEmpty {
            errors.append("Add at least one debt with a positive balance")
        }
        if debts.contains(where: { $0.annualRate < 0 }) {
            errors.append("Interest rates cannot be negative")
        }
        if debts.contains(where: { $0.minimumPayment < 0 }) {
            errors.append("Minimum payments cannot be negative")
        }
        if extraPayment < 0 {
            errors.append("Extra payment cannot be negative")
        }

        return errors
    }
}

// MARK: - Protocol Conformance

extension DebtPayoffCalculation: FinancialCalculationProtocol {}
