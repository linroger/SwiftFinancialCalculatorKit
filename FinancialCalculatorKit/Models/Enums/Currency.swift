//
//  Currency.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import Foundation

/// Supported currencies for financial calculations
enum Currency: String, CaseIterable, Identifiable, Codable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case jpy = "JPY"
    case cad = "CAD"
    case aud = "AUD"
    case chf = "CHF"
    case cny = "CNY"
    case hkd = "HKD"
    case sgd = "SGD"
    case krw = "KRW"
    case inr = "INR"
    case brl = "BRL"
    case mxn = "MXN"
    case rub = "RUB"
    case zar = "ZAR"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .usd:
            return "US Dollar"
        case .eur:
            return "Euro"
        case .gbp:
            return "British Pound"
        case .jpy:
            return "Japanese Yen"
        case .cad:
            return "Canadian Dollar"
        case .aud:
            return "Australian Dollar"
        case .chf:
            return "Swiss Franc"
        case .cny:
            return "Chinese Yuan"
        case .hkd:
            return "Hong Kong Dollar"
        case .sgd:
            return "Singapore Dollar"
        case .krw:
            return "South Korean Won"
        case .inr:
            return "Indian Rupee"
        case .brl:
            return "Brazilian Real"
        case .mxn:
            return "Mexican Peso"
        case .rub:
            return "Russian Ruble"
        case .zar:
            return "South African Rand"
        }
    }
    
    var symbol: String {
        switch self {
        case .usd:
            return "$"
        case .eur:
            return "€"
        case .gbp:
            return "£"
        case .jpy:
            return "¥"
        case .cad:
            return "C$"
        case .aud:
            return "A$"
        case .chf:
            return "CHF"
        case .cny:
            return "¥"
        case .hkd:
            return "HK$"
        case .sgd:
            return "S$"
        case .krw:
            return "₩"
        case .inr:
            return "₹"
        case .brl:
            return "R$"
        case .mxn:
            return "Mex$"
        case .rub:
            return "₽"
        case .zar:
            return "R"
        }
    }
    
    var countryCode: String {
        switch self {
        case .usd:
            return "US"
        case .eur:
            return "EU"
        case .gbp:
            return "GB"
        case .jpy:
            return "JP"
        case .cad:
            return "CA"
        case .aud:
            return "AU"
        case .chf:
            return "CH"
        case .cny:
            return "CN"
        case .hkd:
            return "HK"
        case .sgd:
            return "SG"
        case .krw:
            return "KR"
        case .inr:
            return "IN"
        case .brl:
            return "BR"
        case .mxn:
            return "MX"
        case .rub:
            return "RU"
        case .zar:
            return "ZA"
        }
    }
    
    /// Number of decimal places typically used for this currency
    var decimalPlaces: Int {
        switch self {
        case .jpy, .krw:
            return 0  // Yen and Won don't use decimal places
        default:
            return 2
        }
    }
    
    /// Format a value with the currency symbol and appropriate decimal places
    func formatValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = rawValue
        formatter.currencySymbol = symbol
        formatter.maximumFractionDigits = decimalPlaces
        formatter.minimumFractionDigits = decimalPlaces
        
        return formatter.string(from: NSNumber(value: value)) ?? "\(symbol)\(value)"
    }
}