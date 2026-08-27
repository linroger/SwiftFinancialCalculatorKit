//
//  Formatters.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import Foundation

/// Central location for all number and date formatters used in the app
struct Formatters {
    
    // MARK: - Number Formatters
    
    /// Currency formatter with dynamic currency support
    static func currencyFormatter(for currency: Currency, decimalPlaces: Int? = nil) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.rawValue
        formatter.currencySymbol = currency.symbol
        
        if let places = decimalPlaces {
            formatter.minimumFractionDigits = places
            formatter.maximumFractionDigits = places
        } else {
            formatter.minimumFractionDigits = currency.decimalPlaces
            formatter.maximumFractionDigits = currency.decimalPlaces
        }
        
        return formatter
    }
    
    /// Percentage formatter
    static let percentageFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 3
        formatter.multiplier = 1.0 // We handle percentage conversion separately
        return formatter
    }()
    
    /// Decimal formatter with thousands separator (locale-aware separators)
    static func decimalFormatter(decimalPlaces: Int = 2, useGroupingSeparator: Bool = true) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimalPlaces
        formatter.maximumFractionDigits = decimalPlaces
        formatter.usesGroupingSeparator = useGroupingSeparator
        return formatter
    }
    
    /// Scientific notation formatter
    static let scientificFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .scientific
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        return formatter
    }()
    
    /// Integer formatter with thousands separator (locale-aware)
    static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        return formatter
    }()
    
    // MARK: - Date Formatters
    
    /// Short date formatter (MM/dd/yyyy)
    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    /// Medium date formatter (Jan 1, 2025)
    static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    /// Long date formatter (January 1, 2025)
    static let longDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
    
    /// Month year formatter (January 2025)
    static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    /// ISO date formatter (fixed POSIX locale so era/calendar settings can't leak in)
    static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()
    
    /// Relative date formatter (e.g., "2 days ago", "in 3 months")
    @MainActor
    static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
    
    // MARK: - Helper Methods
    
    /// Format a number as currency with proper handling of negative values
    static func formatCurrency(_ value: Double, currency: Currency, showSign: Bool = false) -> String {
        let formatter = currencyFormatter(for: currency)

        if showSign && value > 0 {
            // Keep the currency symbol; positivePrefix replaces the whole prefix
            formatter.positivePrefix = "+" + (formatter.currencySymbol ?? "")
        }

        return formatter.string(from: NSNumber(value: value)) ?? currency.formatValue(value)
    }
    
    /// Format a number as percentage with specified decimal places
    static func formatPercentage(_ value: Double, decimalPlaces: Int = 2) -> String {
        return String(format: "%.\(decimalPlaces)f%%", value)
    }
    
    /// Format time duration in years and months
    static func formatDuration(years: Double) -> String {
        guard years.isFinite, years > 0 else { return "0 months" }
        let totalMonths = Int((years * 12).rounded())
        let displayYears = totalMonths / 12
        let displayMonths = totalMonths % 12

        if displayYears > 0 && displayMonths > 0 {
            return "\(displayYears) year\(displayYears == 1 ? "" : "s") \(displayMonths) month\(displayMonths == 1 ? "" : "s")"
        } else if displayYears > 0 {
            return "\(displayYears) year\(displayYears == 1 ? "" : "s")"
        } else {
            return "\(displayMonths) month\(displayMonths == 1 ? "" : "s")"
        }
    }
    
    /// Format large numbers with abbreviations (K, M, B)
    static func formatAbbreviated(_ value: Double) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""
        
        if absValue >= 1_000_000_000 {
            return "\(sign)\(String(format: "%.1f", absValue / 1_000_000_000))B"
        } else if absValue >= 1_000_000 {
            return "\(sign)\(String(format: "%.1f", absValue / 1_000_000))M"
        } else if absValue >= 1_000 {
            return "\(sign)\(String(format: "%.1f", absValue / 1_000))K"
        } else {
            return "\(sign)\(String(format: "%.0f", absValue))"
        }
    }
}