//
//  PaymentFrequency.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import Foundation

/// Payment frequency options for financial calculations
enum PaymentFrequency: String, CaseIterable, Identifiable, Codable {
    case annual = "annual"
    case semiAnnual = "semiAnnual"
    case quarterly = "quarterly"
    case monthly = "monthly"
    case weekly = "weekly"
    case daily = "daily"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .annual:
            return "Annual"
        case .semiAnnual:
            return "Semi-Annual"
        case .quarterly:
            return "Quarterly"
        case .monthly:
            return "Monthly"
        case .weekly:
            return "Weekly"
        case .daily:
            return "Daily"
        }
    }
    
    /// Number of payment periods per year
    var periodsPerYear: Double {
        switch self {
        case .annual:
            return 1.0
        case .semiAnnual:
            return 2.0
        case .quarterly:
            return 4.0
        case .monthly:
            return 12.0
        case .weekly:
            return 52.0
        case .daily:
            return 365.0
        }
    }
    
    /// Convert annual interest rate to period rate
    func periodRate(from annualRate: Double) -> Double {
        return annualRate / periodsPerYear
    }
    
    /// Convert number of years to number of periods
    func numberOfPeriods(from years: Double) -> Double {
        return years * periodsPerYear
    }
    
    /// Convert number of periods to years
    func yearsFromPeriods(_ periods: Double) -> Double {
        return periods / periodsPerYear
    }
}