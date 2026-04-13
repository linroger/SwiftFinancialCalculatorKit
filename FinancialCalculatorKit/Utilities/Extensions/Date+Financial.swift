//
//  Date+Financial.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import Foundation

extension Date {
    /// Get the number of days between two dates
    func daysBetween(_ otherDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: self, to: otherDate)
        return abs(components.day ?? 0)
    }
    
    /// Get the number of months between two dates
    func monthsBetween(_ otherDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: self, to: otherDate)
        return abs(components.month ?? 0)
    }
    
    /// Get the number of years between two dates
    func yearsBetween(_ otherDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: self, to: otherDate)
        return abs(components.year ?? 0)
    }
    
    /// Add months to date
    func addingMonths(_ months: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .month, value: months, to: self) ?? self
    }
    
    /// Add years to date
    func addingYears(_ years: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .year, value: years, to: self) ?? self
    }
    
    /// Format date for display
    func formatted(as style: DateFormatStyle) -> String {
        let formatter = DateFormatter()
        
        switch style {
        case .short:
            formatter.dateStyle = .short
            formatter.timeStyle = .none
        case .medium:
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        case .long:
            formatter.dateStyle = .long
            formatter.timeStyle = .none
        case .monthYear:
            formatter.dateFormat = "MMM yyyy"
        case .dayMonthYear:
            formatter.dateFormat = "dd MMM yyyy"
        }
        
        return formatter.string(from: self)
    }
    
    /// Check if date is in the past
    var isInPast: Bool {
        return self < Date()
    }
    
    /// Check if date is in the future
    var isInFuture: Bool {
        return self > Date()
    }
    
    /// Get the start of the day
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    /// Get the end of the day
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }
}

enum DateFormatStyle {
    case short
    case medium
    case long
    case monthYear
    case dayMonthYear
}