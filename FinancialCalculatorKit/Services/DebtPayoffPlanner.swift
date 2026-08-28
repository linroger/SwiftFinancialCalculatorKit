//
//  DebtPayoffPlanner.swift
//  FinancialCalculatorKit
//
//  Compares strategies for retiring several debts at once. Paying the minimum
//  on everything is the expensive default; directing a fixed budget at one
//  target and rolling each cleared minimum into the next is what actually ends
//  the debt. Avalanche minimises interest, snowball clears individual balances
//  sooner — this quantifies the gap so the trade-off is explicit.
//

import Foundation

struct Debt: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var balance: Double
    var annualRate: Double
    var minimumPayment: Double

    init(
        id: UUID = UUID(),
        name: String,
        balance: Double,
        annualRate: Double,
        minimumPayment: Double
    ) {
        self.id = id
        self.name = name
        self.balance = balance
        self.annualRate = annualRate
        self.minimumPayment = minimumPayment
    }

    /// Interest accruing in the first month at the current balance.
    var monthlyInterest: Double {
        balance * annualRate / 100 / 12
    }
}

enum PayoffStrategy: String, CaseIterable, Identifiable, Codable {
    /// Highest interest rate first — mathematically cheapest
    case avalanche
    /// Smallest balance first — clears individual debts soonest
    case snowball
    /// Every debt paid at its minimum, with nothing rolled over
    case minimumsOnly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .avalanche: return "Avalanche"
        case .snowball: return "Snowball"
        case .minimumsOnly: return "Minimums Only"
        }
    }

    var subtitle: String {
        switch self {
        case .avalanche: return "Highest rate first"
        case .snowball: return "Smallest balance first"
        case .minimumsOnly: return "No extra, no rollover"
        }
    }

    var explanation: String {
        switch self {
        case .avalanche:
            return "Attacks the most expensive debt first, so the least interest accrues. This is always the cheapest option in pure arithmetic."
        case .snowball:
            return "Clears the smallest balance first. It usually costs more in interest, but each payoff arrives sooner, which is what keeps some people going."
        case .minimumsOnly:
            return "The default if you change nothing: every debt paid at its minimum with no rollover. Shown as the baseline the other strategies improve on."
        }
    }
}

/// When a particular debt is retired.
struct DebtPayoffMilestone: Identifiable {
    let id = UUID()
    let debtName: String
    let month: Int
    let interestPaid: Double
}

/// Total balance across all debts at a point in time.
struct DebtBalancePoint: Identifiable {
    let id = UUID()
    let month: Int
    let totalBalance: Double
}

struct DebtPayoffPlan {
    let strategy: PayoffStrategy
    /// Months until every balance reaches zero
    let months: Int
    let totalInterest: Double
    let totalPaid: Double
    /// Order in which debts were retired
    let milestones: [DebtPayoffMilestone]
    let balanceTimeline: [DebtBalancePoint]
    /// Fixed amount sent to creditors each month under this strategy
    let monthlyBudget: Double
}

enum DebtPayoffError: LocalizedError {
    case noDebts
    case budgetBelowInterest(shortfall: Double)
    case neverRetires

    var errorDescription: String? {
        switch self {
        case .noDebts:
            return "Add at least one debt to compare strategies."
        case .budgetBelowInterest(let shortfall):
            return "The monthly budget does not cover the interest accruing. Balances would grow — you need at least \(String(format: "%.2f", shortfall)) more per month."
        case .neverRetires:
            return "These debts do not retire within 50 years at this budget."
        }
    }
}

enum DebtPayoffPlanner {
    /// Hard stop so a pathological input cannot spin forever.
    private static let maxMonths = 600

    /// Simulate one strategy. Every strategy spends the same monthly budget
    /// (the sum of minimums plus any extra), which is what makes the comparison
    /// fair — except `minimumsOnly`, which by definition spends less over time
    /// as debts clear.
    static func plan(
        debts: [Debt],
        extraPayment: Double,
        strategy: PayoffStrategy
    ) throws -> DebtPayoffPlan {
        let active = debts.filter { $0.balance > 0 }
        guard !active.isEmpty else { throw DebtPayoffError.noDebts }

        let totalMinimums = active.reduce(0) { $0 + $1.minimumPayment }
        let budget = totalMinimums + max(extraPayment, 0)

        // A budget below the accruing interest never retires anything
        let firstMonthInterest = active.reduce(0) { $0 + $1.monthlyInterest }
        if budget <= firstMonthInterest {
            throw DebtPayoffError.budgetBelowInterest(shortfall: firstMonthInterest - budget + 1)
        }

        var balances = active.map(\.balance)
        var interestByDebt = [Double](repeating: 0, count: active.count)
        let rates = active.map { $0.annualRate / 100 / 12 }
        let minimums = active.map(\.minimumPayment)

        var milestones: [DebtPayoffMilestone] = []
        var timeline: [DebtBalancePoint] = [
            DebtBalancePoint(month: 0, totalBalance: balances.reduce(0, +))
        ]
        var totalInterest = 0.0
        var totalPaid = 0.0
        var month = 0

        while balances.contains(where: { $0 > 0.005 }) {
            month += 1
            guard month <= maxMonths else { throw DebtPayoffError.neverRetires }

            // Interest accrues before any payment lands
            for index in balances.indices where balances[index] > 0 {
                let interest = balances[index] * rates[index]
                balances[index] += interest
                interestByDebt[index] += interest
                totalInterest += interest
            }

            // Minimums go out on every live debt
            var available = strategy == .minimumsOnly ? Double.greatestFiniteMagnitude : budget
            for index in balances.indices where balances[index] > 0 {
                let payment = min(minimums[index], balances[index])
                balances[index] -= payment
                available -= payment
                totalPaid += payment
            }

            // Whatever is left goes to the strategy's current target
            if strategy != .minimumsOnly, available > 0.005 {
                if let target = targetIndex(
                    balances: balances,
                    rates: rates,
                    strategy: strategy
                ) {
                    let payment = min(available, balances[target])
                    balances[target] -= payment
                    available -= payment
                    totalPaid += payment
                }
            }

            // Record any debt retired this month
            for index in balances.indices where balances[index] <= 0.005 {
                let alreadyRecorded = milestones.contains { $0.debtName == active[index].name }
                if !alreadyRecorded {
                    balances[index] = 0
                    milestones.append(
                        DebtPayoffMilestone(
                            debtName: active[index].name,
                            month: month,
                            interestPaid: interestByDebt[index]
                        )
                    )
                }
            }

            timeline.append(
                DebtBalancePoint(month: month, totalBalance: balances.reduce(0, +))
            )
        }

        return DebtPayoffPlan(
            strategy: strategy,
            months: month,
            totalInterest: totalInterest,
            totalPaid: totalPaid,
            milestones: milestones,
            balanceTimeline: timeline,
            monthlyBudget: strategy == .minimumsOnly ? totalMinimums : budget
        )
    }

    /// Compare every strategy at once, skipping any that cannot complete.
    static func compareAll(debts: [Debt], extraPayment: Double) -> [DebtPayoffPlan] {
        PayoffStrategy.allCases.compactMap { strategy in
            try? plan(debts: debts, extraPayment: extraPayment, strategy: strategy)
        }
    }

    /// Index of the debt the strategy targets next among those still owing.
    private static func targetIndex(
        balances: [Double],
        rates: [Double],
        strategy: PayoffStrategy
    ) -> Int? {
        let live = balances.indices.filter { balances[$0] > 0.005 }
        guard !live.isEmpty else { return nil }

        switch strategy {
        case .avalanche:
            // Highest rate wins; ties break to the smaller balance so the
            // ordering is stable rather than dependent on input order
            return live.max { lhs, rhs in
                if rates[lhs] == rates[rhs] {
                    return balances[lhs] > balances[rhs]
                }
                return rates[lhs] < rates[rhs]
            }
        case .snowball:
            return live.min { lhs, rhs in
                if balances[lhs] == balances[rhs] {
                    return rates[lhs] > rates[rhs]
                }
                return balances[lhs] < balances[rhs]
            }
        case .minimumsOnly:
            return nil
        }
    }
}
