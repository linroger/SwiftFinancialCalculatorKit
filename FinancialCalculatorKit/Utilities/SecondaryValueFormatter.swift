//
//  SecondaryValueFormatter.swift
//  FinancialCalculatorKit
//
//  Shared formatting for the labelled values a CalculationResult carries, so a
//  figure reads the same in a result card as it does in a comparison table.
//

import Foundation

enum SecondaryValueFormatter {
    /// Keys that carry money despite containing a rate-ish word.
    private static let currencyOverrides: Set<String> = [
        "NPV at IRR"
    ]

    /// Keys that carry a plain count rather than money or a percentage.
    private static let countOverrides: Set<String> = [
        "Debts",
        "Number of Coupon Payments"
    ]

    /// Format one secondary value for display.
    static func format(key: String, value: Double, currency: Currency) -> String {
        guard value.isFinite else { return "—" }

        if currencyOverrides.contains(key) {
            return currency.formatValue(value)
        }
        if countOverrides.contains(key) {
            return String(format: "%.0f", value)
        }

        let lowered = key.lowercased()
        if lowered.contains("rate") || lowered.contains("percentage") {
            return String(format: "%.3f%%", value)
        }
        if lowered.contains("year") || lowered.contains("period") {
            return String(format: "%.1f", value)
        }
        return currency.formatValue(value)
    }

    /// Format the difference between two values for the same key, keeping the
    /// sign so a comparison reads as "more" or "less" at a glance.
    static func formatDelta(key: String, delta: Double, currency: Currency) -> String {
        guard delta.isFinite else { return "—" }
        if abs(delta) < 0.005 { return "—" }

        let sign = delta > 0 ? "+" : "−"
        return sign + format(key: key, value: abs(delta), currency: currency)
    }
}
