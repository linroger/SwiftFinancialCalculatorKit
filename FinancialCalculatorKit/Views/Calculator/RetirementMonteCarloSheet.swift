//
//  RetirementMonteCarloSheet.swift
//  FinancialCalculatorKit
//
//  Presents the stochastic retirement analysis: how often the plan survives,
//  the range of outcomes, and the income it sustains with confidence.
//

import SwiftUI
import Charts

struct RetirementMonteCarloSheet: View {
    let inputs: RetirementMonteCarloInputs
    let currency: Currency
    @Environment(\.dismiss) private var dismiss

    @State private var trials: RetirementMonteCarlo.TrialCount = .standard
    @State private var result: RetirementSimulationResult?
    @State private var isRunning = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    controlsSection

                    if let result {
                        outcomeSection(result)
                        fanChartSection(result)
                        rangeSection(result)
                        interpretationSection(result)
                    } else if isRunning {
                        runningSection
                    } else {
                        introSection
                    }
                }
                .padding()
            }
            .navigationTitle("Monte Carlo Analysis")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 720, minHeight: 620)
        .task {
            await run()
        }
    }

    // MARK: - Sections

    private var controlsSection: some View {
        HStack(spacing: 16) {
            Picker("Simulation size", selection: $trials) {
                ForEach(RetirementMonteCarlo.TrialCount.allCases) { count in
                    Text(count.displayName).tag(count)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 260)
            .disabled(isRunning)

            Button("Run Again") {
                Task { await run() }
            }
            .buttonStyle(.bordered)
            .disabled(isRunning)

            Spacer()

            if isRunning {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .onChange(of: trials) { _, _ in
            Task { await run() }
        }
    }

    private var introSection: some View {
        Text("Simulating market paths…")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var runningSection: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Simulating \(trials.rawValue.formatted()) market paths…")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func outcomeSection(_ result: RetirementSimulationResult) -> some View {
        GroupBox {
            VStack(spacing: 12) {
                Text("Chance the Plan Lasts")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text(result.successProbability.formatted(.percent.precision(.fractionLength(0))))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(successColor(result.successProbability))

                Text(successNarrative(result))
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("Across \(result.trials.formatted()) simulated market paths")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .groupBoxStyle(FinancialGroupBoxStyle())
    }

    private func fanChartSection(_ result: RetirementSimulationResult) -> some View {
        GroupBox("Range of Outcomes") {
            VStack(alignment: .leading, spacing: 8) {
                Chart {
                    ForEach(result.percentileBands) { point in
                        AreaMark(
                            x: .value("Age", point.age),
                            yStart: .value("10th percentile", point.p10),
                            yEnd: .value("90th percentile", point.p90)
                        )
                        .foregroundStyle(Color.accentColor.opacity(0.18))
                        .interpolationMethod(.monotone)
                    }

                    ForEach(result.percentileBands) { point in
                        LineMark(
                            x: .value("Age", point.age),
                            y: .value("Median", point.p50)
                        )
                        .foregroundStyle(Color.accentColor)
                        .interpolationMethod(.monotone)
                    }
                }
                .frame(height: 260)
                .chartXAxisLabel("Age")
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(Formatters.formatAbbreviated(amount))
                                    .font(.caption)
                            }
                        }
                    }
                }

                Text("The shaded band covers the middle 80% of outcomes; the line is the median path.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(8)
        }
        .groupBoxStyle(FinancialGroupBoxStyle())
    }

    private func rangeSection(_ result: RetirementSimulationResult) -> some View {
        GroupBox("Ending Balance at Age \(Int(inputs.lifeExpectancy))") {
            VStack(spacing: 4) {
                DetailRow(title: "Pessimistic (10th percentile)", value: currency.formatValue(result.p10EndingBalance))
                DetailRow(title: "Median", value: currency.formatValue(result.medianEndingBalance), isHighlighted: true)
                DetailRow(title: "Optimistic (90th percentile)", value: currency.formatValue(result.p90EndingBalance))

                Divider()

                DetailRow(
                    title: "Income sustainable at 90% confidence",
                    value: currency.formatValue(result.sustainableIncomeAt90) + " / month",
                    isHighlighted: true
                )
                DetailRow(
                    title: "Income you asked for",
                    value: currency.formatValue(inputs.desiredMonthlyIncome) + " / month"
                )

                if let depletionAge = result.medianDepletionAge {
                    Divider()
                    DetailRow(
                        title: "When money runs out (median of failed paths)",
                        value: "Age \(Int(depletionAge))"
                    )
                }
            }
            .padding(8)
        }
        .groupBoxStyle(FinancialGroupBoxStyle())
    }

    private func interpretationSection(_ result: RetirementSimulationResult) -> some View {
        GroupBox("What This Means") {
            VStack(alignment: .leading, spacing: 10) {
                Text(gapNarrative(result))

                Text("Each path draws monthly returns from a normal distribution around your expected return, using the volatility you entered, while withdrawals grow with inflation. This captures sequence-of-returns risk — the same average return can succeed or fail depending on when the bad years land. It is a model, not a forecast, and real markets have fatter tails than a normal distribution.")
            }
            .font(.callout)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        }
        .groupBoxStyle(FinancialGroupBoxStyle())
    }

    // MARK: - Helpers

    private func run() async {
        isRunning = true
        let snapshot = inputs
        let count = trials

        let computed = await Task.detached(priority: .userInitiated) {
            RetirementMonteCarlo.analyze(
                currentAge: snapshot.currentAge,
                retirementAge: snapshot.retirementAge,
                lifeExpectancy: snapshot.lifeExpectancy,
                currentSavings: snapshot.currentSavings,
                monthlyContribution: snapshot.monthlyContribution,
                preRetirementReturn: snapshot.preRetirementReturn,
                inRetirementReturn: snapshot.inRetirementReturn,
                returnVolatility: snapshot.returnVolatility,
                inflationRate: snapshot.inflationRate,
                desiredMonthlyIncome: snapshot.desiredMonthlyIncome,
                trials: count
            )
        }.value

        result = computed
        isRunning = false
    }

    private func successColor(_ probability: Double) -> Color {
        switch probability {
        case 0.85...: return .green
        case 0.70..<0.85: return .orange
        default: return .red
        }
    }

    private func successNarrative(_ result: RetirementSimulationResult) -> String {
        switch result.successProbability {
        case 0.90...:
            return "This plan funds your desired income in almost every simulated market."
        case 0.75..<0.90:
            return "This plan usually works, but a poor run of early returns can still exhaust it."
        case 0.50..<0.75:
            return "This plan fails in a meaningful share of markets. Consider saving more, spending less, or working longer."
        default:
            return "This plan fails more often than it succeeds. The gap is large enough that assumptions alone will not close it."
        }
    }

    private func gapNarrative(_ result: RetirementSimulationResult) -> String {
        let gap = inputs.desiredMonthlyIncome - result.sustainableIncomeAt90
        if gap <= 0 {
            let headroom = currency.formatValue(-gap)
            return "You could raise spending by about \(headroom) per month and still clear 90% confidence."
        }
        return "To reach 90% confidence you would need to trim about \(currency.formatValue(gap)) per month from the income target, or make up the difference with more savings or more years of work."
    }
}

/// Plain snapshot of the plan inputs, so the simulation can run off the main actor.
struct RetirementMonteCarloInputs: Sendable {
    let currentAge: Double
    let retirementAge: Double
    let lifeExpectancy: Double
    let currentSavings: Double
    let monthlyContribution: Double
    let preRetirementReturn: Double
    let inRetirementReturn: Double
    let returnVolatility: Double
    let inflationRate: Double
    let desiredMonthlyIncome: Double
}
