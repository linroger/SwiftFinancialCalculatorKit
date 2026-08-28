//
//  CalculationType.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import Foundation

/// Types of financial calculations supported by the app
enum CalculationType: String, CaseIterable, Identifiable {
    case timeValue = "timeValue"
    case loan = "loan"
    case mortgage = "mortgage"
    case debtPayoff = "debtPayoff"
    case retirement = "retirement"
    case bond = "bond"
    case investment = "investment"
    case options = "options"
    case mathExpression = "mathExpression"
    case depreciation = "depreciation"
    case currency = "currency"
    case conversion = "conversion"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .timeValue:
            return "Time Value of Money"
        case .loan:
            return "Loan Calculator"
        case .mortgage:
            return "Mortgage Calculator"
        case .debtPayoff:
            return "Debt Payoff Planner"
        case .retirement:
            return "Retirement Planner"
        case .bond:
            return "Bond Calculator"
        case .investment:
            return "Investment Analysis"
        case .options:
            return "Options Calculator"
        case .mathExpression:
            return "Math Expression"
        case .depreciation:
            return "Depreciation"
        case .currency:
            return "Currency Exchange"
        case .conversion:
            return "Unit Conversion"
        }
    }
    
    var description: String {
        switch self {
        case .timeValue:
            return "Calculate present value, future value, payment, interest rate, and number of periods"
        case .loan:
            return "Analyze loan payments, interest, and amortization schedules"
        case .mortgage:
            return "Calculate mortgage payments, total interest, and payment schedules"
        case .debtPayoff:
            return "Compare avalanche, snowball, and minimum-only strategies across several debts"
        case .retirement:
            return "Project savings to retirement, required nest egg, and sustainable income"
        case .bond:
            return "Bond pricing, yield calculations, and sensitivity analysis"
        case .investment:
            return "NPV, IRR, MIRR, and investment performance analysis"
        case .options:
            return "Black-Scholes options pricing with Greeks analysis and risk assessment"
        case .mathExpression:
            return "Advanced mathematical expression evaluator with financial functions and variables"
        case .depreciation:
            return "Straight-line, declining balance, and MACRS depreciation"
        case .currency:
            return "Daily reference exchange rates and currency conversions"
        case .conversion:
            return "Unit conversions for international calculations"
        }
    }
    
    var systemImage: String {
        switch self {
        case .timeValue:
            return "clock.arrow.circlepath"
        case .loan:
            return "creditcard"
        case .mortgage:
            return "house"
        case .debtPayoff:
            return "creditcard.trianglebadge.exclamationmark"
        case .retirement:
            return "figure.walk.motion"
        case .bond:
            return "chart.line.uptrend.xyaxis"
        case .investment:
            return "chart.bar.fill"
        case .options:
            return "function"
        case .mathExpression:
            return "x.squareroot"
        case .depreciation:
            return "arrow.down.right.circle"
        case .currency:
            return "dollarsign.circle"
        case .conversion:
            return "arrow.left.arrow.right"
        }
    }

    var category: CalculationCategory {
        switch self {
        case .timeValue, .loan, .mortgage, .debtPayoff, .retirement, .depreciation:
            return .basics
        case .bond, .investment, .options:
            return .investment
        case .currency, .conversion, .mathExpression:
            return .tools
        }
    }
}

enum CalculationCategory: String, CaseIterable, Identifiable {
    case basics = "Basics"
    case investment = "Investment"
    case tools = "Tools"

    var id: String { rawValue }
}
