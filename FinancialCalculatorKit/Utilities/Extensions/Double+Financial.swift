//
//  Double+Financial.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import Foundation

extension Double {
    /// Format as currency with the specified currency
    func asCurrency(_ currency: Currency = .usd) -> String {
        return currency.formatValue(self)
    }
    
    /// Format as percentage with specified decimal places
    func asPercentage(_ decimalPlaces: Int = 2) -> String {
        return String(format: "%.\(decimalPlaces)f%%", self)
    }
    
    /// Format with thousands separator
    func withThousandsSeparator(_ decimalPlaces: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimalPlaces
        formatter.maximumFractionDigits = decimalPlaces
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        
        return formatter.string(from: NSNumber(value: self)) ?? String(format: "%.\(decimalPlaces)f", self)
    }
    
    /// Round to specified decimal places
    func rounded(to places: Int) -> Double {
        let divisor = Foundation.pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
    
    /// Check if value is effectively zero (within epsilon)
    var isEffectivelyZero: Bool {
        return abs(self) < Double.ulpOfOne
    }
    
    /// Convert annual rate to monthly rate
    func annualToMonthly() -> Double {
        return self / 12.0
    }
    
    /// Convert monthly rate to annual rate
    func monthlyToAnnual() -> Double {
        return self * 12.0
    }
    
    /// Convert percentage to decimal (e.g., 5.5% to 0.055)
    func percentToDecimal() -> Double {
        return self / 100.0
    }
    
    /// Convert decimal to percentage (e.g., 0.055 to 5.5%)
    func decimalToPercent() -> Double {
        return self * 100.0
    }
}