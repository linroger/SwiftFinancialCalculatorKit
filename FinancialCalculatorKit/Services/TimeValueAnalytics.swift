//
//  TimeValueAnalytics.swift
//  FinancialCalculatorKit
//
//  Created by Codex on 4/14/26.
//

import Foundation

struct TVMMilestone: Identifiable {
    let id = UUID()
    let title: String
    let year: Double
    let balance: Double
}

struct TVMScenarioOutcome: Identifiable {
    let id = UUID()
    let title: String
    let annualRate: Double
    let futureValue: Double
}

struct TVMAnalysisSnapshot {
    let resolvedPresentValue: Double
    let resolvedFutureValue: Double
    let resolvedPayment: Double
    let annualRate: Double
    let effectiveAnnualRate: Double
    let years: Double
    let totalScheduledPayments: Double
    let netGrowth: Double
    let interestEarned: Double
    let growthTimeline: [ChartDataPoint]
    let contributionTimeline: [ChartDataPoint]
    let milestones: [TVMMilestone]
    let scenarios: [TVMScenarioOutcome]
}

enum TVMAnalysisEngine {
    static func buildSnapshot(
        solveFor: TimeValueVariable,
        presentValue: Double?,
        futureValue: Double?,
        payment: Double?,
        annualInterestRate: Double?,
        numberOfYears: Double?,
        paymentFrequency: PaymentFrequency,
        paymentsAtBeginning: Bool,
        result: CalculationResult?
    ) -> TVMAnalysisSnapshot? {
        let resolvedPresentValue = solveFor == .presentValue ? (result?.primaryValue ?? 0) : (presentValue ?? 0)
        let resolvedFutureValue = solveFor == .futureValue ? (result?.primaryValue ?? 0) : (futureValue ?? 0)
        // Preserve the payment's sign: negative means a withdrawal from the balance
        let resolvedPayment = solveFor == .payment ? (result?.primaryValue ?? 0) : (payment ?? 0)
        let annualRate = solveFor == .interestRate ? (result?.primaryValue ?? 0) : (annualInterestRate ?? 0)
        let years = solveFor == .numberOfYears ? (result?.primaryValue ?? 0) : (numberOfYears ?? 0)

        guard annualRate >= 0, years > 0, years.isFinite, annualRate.isFinite else { return nil }

        let effectiveAnnualRate = pow(1 + (annualRate / 100 / paymentFrequency.periodsPerYear), paymentFrequency.periodsPerYear) - 1
        // Cap the simulated series so extreme horizons stay renderable
        let periods = min(max(Int(paymentFrequency.numberOfPeriods(from: years).rounded()), 1), 1200)
        let ratePerPeriod = annualRate / 100 / paymentFrequency.periodsPerYear

        var growthTimeline: [ChartDataPoint] = [
            ChartDataPoint(x: 0, y: resolvedPresentValue, label: "Start")
        ]
        var contributionTimeline: [ChartDataPoint] = [
            ChartDataPoint(x: 0, y: resolvedPresentValue, label: "Initial")
        ]

        var balance = resolvedPresentValue
        var cumulativePrincipal = resolvedPresentValue

        for period in 1...periods {
            if paymentsAtBeginning && resolvedPayment != 0 {
                balance += resolvedPayment
                cumulativePrincipal += resolvedPayment
            }

            balance *= (1 + ratePerPeriod)

            if !paymentsAtBeginning && resolvedPayment != 0 {
                balance += resolvedPayment
                cumulativePrincipal += resolvedPayment
            }

            let year = paymentFrequency.yearsFromPeriods(Double(period))
            growthTimeline.append(
                ChartDataPoint(x: year, y: balance, label: "Year \(String(format: "%.1f", year))")
            )
            contributionTimeline.append(
                ChartDataPoint(x: year, y: cumulativePrincipal, label: "Principal \(String(format: "%.1f", year))")
            )
        }

        let endBalance = growthTimeline.last?.y ?? resolvedFutureValue
        let totalScheduledPayments = resolvedPayment * Double(periods)
        let interestEarned = endBalance - cumulativePrincipal
        let netGrowth = endBalance - resolvedPresentValue
        let milestones = buildMilestones(for: endBalance, from: growthTimeline)
        let scenarios = buildScenarios(
            presentValue: resolvedPresentValue,
            payment: resolvedPayment,
            years: years,
            annualRate: annualRate,
            paymentFrequency: paymentFrequency,
            paymentsAtBeginning: paymentsAtBeginning
        )

        return TVMAnalysisSnapshot(
            resolvedPresentValue: resolvedPresentValue,
            // Prefer the user-entered or solved target; fall back to the simulated balance
            resolvedFutureValue: resolvedFutureValue != 0 ? resolvedFutureValue : endBalance,
            resolvedPayment: resolvedPayment,
            annualRate: annualRate,
            effectiveAnnualRate: effectiveAnnualRate * 100,
            years: years,
            totalScheduledPayments: totalScheduledPayments,
            netGrowth: netGrowth,
            interestEarned: interestEarned,
            growthTimeline: growthTimeline,
            contributionTimeline: contributionTimeline,
            milestones: milestones,
            scenarios: scenarios
        )
    }

    private static func buildMilestones(for targetValue: Double, from timeline: [ChartDataPoint]) -> [TVMMilestone] {
        guard targetValue > 0 else { return [] }

        let thresholds: [(String, Double)] = [
            ("25%", 0.25),
            ("50%", 0.50),
            ("75%", 0.75),
            ("Target", 1.00)
        ]

        return thresholds.compactMap { title, percentage in
            let threshold = targetValue * percentage
            guard let point = timeline.first(where: { $0.y >= threshold }) else { return nil }
            return TVMMilestone(title: title, year: point.x, balance: point.y)
        }
    }

    private static func buildScenarios(
        presentValue: Double,
        payment: Double,
        years: Double,
        annualRate: Double,
        paymentFrequency: PaymentFrequency,
        paymentsAtBeginning: Bool
    ) -> [TVMScenarioOutcome] {
        let scenarios: [(String, Double)] = [
            ("Defensive", max(annualRate - 2, 0)),
            ("Base", annualRate),
            ("Upside", annualRate + 2)
        ]

        return scenarios.map { title, scenarioRate in
            let futureValue = CalculationEngine.calculateFutureValue(
                presentValue: presentValue,
                payment: payment,
                interestRate: paymentFrequency.periodRate(from: scenarioRate),
                numberOfPeriods: paymentFrequency.numberOfPeriods(from: years),
                paymentAtBeginning: paymentsAtBeginning
            )

            return TVMScenarioOutcome(
                title: title,
                annualRate: scenarioRate,
                futureValue: futureValue
            )
        }
    }
}
