//
//  RefinanceAnalysisSheet.swift
//  FinancialCalculatorKit
//
//  "Should I refinance?" — compares the loan on screen against a new offer.
//

import SwiftUI
import Charts

struct RefinanceAnalysisSheet: View {
    /// The loan currently on screen, used to prefill the comparison.
    let originalPrincipal: Double
    let originalAnnualRate: Double
    let originalTermMonths: Int
    let currency: Currency

    @Environment(\.dismiss) private var dismiss

    @State private var paymentsMade: Double = 0
    @State private var newAnnualRate: Double? = nil
    @State private var newTermYears: Double? = nil
    @State private var closingCosts: Double? = 3_000
    @State private var financeClosingCosts: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                HStack(alignment: .top, spacing: 24) {
                    inputColumn
                        .frame(width: 360)
                    resultColumn
                        .frame(maxWidth: .infinity)
                }
                .padding()
            }
            .navigationTitle("Refinance Analysis")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 900, minHeight: 640)
        .onAppear {
            if newAnnualRate == nil {
                // Start a point below the existing rate — the case worth checking
                newAnnualRate = max(originalAnnualRate - 1, 0.1)
            }
            if newTermYears == nil {
                newTermYears = (Double(remainingMonths) / 12).rounded()
            }
        }
    }

    // MARK: - Inputs

    private var inputColumn: some View {
        VStack(spacing: 16) {
            GroupBox("Your Current Loan") {
                VStack(alignment: .leading, spacing: 12) {
                    DetailRow(title: "Original Amount", value: currency.formatValue(originalPrincipal))
                    DetailRow(title: "Rate", value: String(format: "%.3f%%", originalAnnualRate))
                    DetailRow(title: "Original Term", value: "\(originalTermMonths / 12) years")

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Payments Already Made")
                                .font(.headline)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(Int(paymentsMade))")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        Slider(
                            value: $paymentsMade,
                            in: 0...Double(max(originalTermMonths - 1, 1)),
                            step: 1
                        )
                        .help("How far into the loan you are today")

                        Text("\(String(format: "%.1f", paymentsMade / 12)) years in")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    DetailRow(
                        title: "Balance Today",
                        value: currency.formatValue(currentBalance),
                        isHighlighted: true
                    )
                    DetailRow(title: "Payments Remaining", value: "\(remainingMonths)")
                }
                .padding(8)
            }
            .groupBoxStyle(FinancialGroupBoxStyle())

            GroupBox("New Loan Offer") {
                VStack(alignment: .leading, spacing: 12) {
                    PercentageInputField(
                        title: "New Rate",
                        value: $newAnnualRate,
                        isRequired: true,
                        helpText: "The annual rate you have been quoted"
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("New Term")
                            .font(.headline)
                            .fontWeight(.medium)

                        HStack {
                            TextField(
                                "Years",
                                value: $newTermYears,
                                format: .number.precision(.fractionLength(0))
                            )
                            .textFieldStyle(.roundedBorder)

                            Text("years")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 6) {
                            ForEach([10, 15, 20, 30], id: \.self) { years in
                                Button("\(years)y") { newTermYears = Double(years) }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                        }
                    }

                    CurrencyInputField(
                        title: "Closing Costs",
                        value: $closingCosts,
                        currency: currency,
                        helpText: "Origination, appraisal, title, and related fees"
                    )

                    Toggle("Roll costs into the loan", isOn: $financeClosingCosts)
                        .help("Finance the closing costs instead of paying cash at closing")
                }
                .padding(8)
            }
            .groupBoxStyle(FinancialGroupBoxStyle())
        }
    }

    // MARK: - Results

    @ViewBuilder
    private var resultColumn: some View {
        if let analysis {
            VStack(alignment: .leading, spacing: 16) {
                verdictCard(analysis)
                paymentCard(analysis)
                breakEvenChart(analysis)
                lifetimeCard(analysis)
                if analysis.samePaymentPayoffMonths != nil {
                    samePaymentCard(analysis)
                }
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 44))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("Enter the rate and term you have been offered")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 80)
        }
    }

    private func verdictCard(_ analysis: RefinanceAnalysis) -> some View {
        GroupBox {
            VStack(spacing: 10) {
                Image(systemName: verdictIcon(analysis))
                    .font(.system(size: 32))
                    .foregroundColor(verdictColor(analysis))

                Text(verdictHeadline(analysis))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text(verdictDetail(analysis))
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .groupBoxStyle(FinancialGroupBoxStyle())
    }

    private func paymentCard(_ analysis: RefinanceAnalysis) -> some View {
        GroupBox("Monthly Payment") {
            VStack(spacing: 4) {
                DetailRow(title: "Current", value: currency.formatValue(analysis.currentMonthlyPayment))
                DetailRow(title: "New", value: currency.formatValue(analysis.newMonthlyPayment))
                Divider()
                DetailRow(
                    title: analysis.monthlySavings >= 0 ? "Monthly Savings" : "Monthly Increase",
                    value: currency.formatValue(abs(analysis.monthlySavings)),
                    isHighlighted: true
                )
                if analysis.upfrontCost > 0 {
                    DetailRow(title: "Cash Due at Closing", value: currency.formatValue(analysis.upfrontCost))
                } else if closingCosts ?? 0 > 0 {
                    DetailRow(
                        title: "Costs Financed Into Loan",
                        value: currency.formatValue(closingCosts ?? 0)
                    )
                }
            }
            .padding(8)
        }
        .groupBoxStyle(FinancialGroupBoxStyle())
    }

    private func breakEvenChart(_ analysis: RefinanceAnalysis) -> some View {
        GroupBox("Cumulative Position") {
            VStack(alignment: .leading, spacing: 8) {
                Chart(cumulativePositions(analysis)) { point in
                    AreaMark(
                        x: .value("Month", point.month),
                        y: .value("Net", point.net)
                    )
                    .foregroundStyle(point.net >= 0 ? Color.green.opacity(0.18) : Color.red.opacity(0.18))
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Month", point.month),
                        y: .value("Net", point.net)
                    )
                    .foregroundStyle(Color.accentColor)
                    .interpolationMethod(.monotone)
                }
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
                .chartXAxisLabel("Months after closing")
                .frame(height: 200)

                if let breakEven = analysis.breakEvenMonths, breakEven > 0 {
                    Text("You come out ahead after month \(breakEven) — about \(String(format: "%.1f", Double(breakEven) / 12)) years. Selling or refinancing again before then loses money.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if analysis.breakEvenMonths == 0 {
                    Text("There is no cash due at closing, so the savings start immediately.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("The payment does not fall, so closing costs are never recovered through monthly savings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
        }
        .groupBoxStyle(FinancialGroupBoxStyle())
    }

    private func lifetimeCard(_ analysis: RefinanceAnalysis) -> some View {
        GroupBox("Lifetime Cost") {
            VStack(spacing: 4) {
                DetailRow(
                    title: "Interest left on current loan",
                    value: currency.formatValue(analysis.currentRemainingInterest)
                )
                DetailRow(
                    title: "Interest on new loan",
                    value: currency.formatValue(analysis.newTotalInterest)
                )
                Divider()
                DetailRow(
                    title: analysis.lifetimeSavings >= 0 ? "Lifetime Savings" : "Lifetime Extra Cost",
                    value: currency.formatValue(abs(analysis.lifetimeSavings)),
                    isHighlighted: true
                )

                if analysis.extendsTerm {
                    Divider()
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("The new loan runs \(analysis.newTotalCostTermNote(remaining: remainingMonths)) longer than what is left on your current one. A lower payment over more months can still cost more overall.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
        }
        .groupBoxStyle(FinancialGroupBoxStyle())
    }

    private func samePaymentCard(_ analysis: RefinanceAnalysis) -> some View {
        GroupBox("If You Keep Paying the Old Amount") {
            VStack(spacing: 4) {
                if let months = analysis.samePaymentPayoffMonths {
                    DetailRow(
                        title: "Paid off in",
                        value: "\(String(format: "%.1f", months / 12)) years"
                    )
                }
                if let interest = analysis.samePaymentInterest {
                    DetailRow(title: "Interest paid", value: currency.formatValue(interest))
                }
                if let saved = analysis.samePaymentInterestSaved, saved > 0 {
                    Divider()
                    DetailRow(
                        title: "Extra interest saved",
                        value: currency.formatValue(saved),
                        isHighlighted: true
                    )
                }

                Text("Refinancing to a lower rate but keeping your current payment puts the whole rate cut toward principal instead of cash flow.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 6)
            }
            .padding(8)
        }
        .groupBoxStyle(FinancialGroupBoxStyle())
    }

    // MARK: - Derived values

    private var currentBalance: Double {
        RefinanceAnalyzer.remainingBalance(
            principal: originalPrincipal,
            annualRate: originalAnnualRate,
            termMonths: originalTermMonths,
            paymentsMade: Int(paymentsMade)
        )
    }

    private var remainingMonths: Int {
        max(originalTermMonths - Int(paymentsMade), 1)
    }

    private var analysis: RefinanceAnalysis? {
        guard let rate = newAnnualRate, let years = newTermYears, years > 0 else { return nil }
        return RefinanceAnalyzer.analyze(
            RefinanceScenario(
                currentBalance: currentBalance,
                currentAnnualRate: originalAnnualRate,
                remainingMonths: remainingMonths,
                newAnnualRate: rate,
                newTermMonths: Int(years * 12),
                closingCosts: closingCosts ?? 0,
                financeClosingCosts: financeClosingCosts
            )
        )
    }

    private struct CumulativePoint: Identifiable {
        let id = UUID()
        let month: Int
        let net: Double
    }

    /// Net cash position after each month: accumulated payment savings less the
    /// cash paid at closing.
    private func cumulativePositions(_ analysis: RefinanceAnalysis) -> [CumulativePoint] {
        let horizon = min(max(analysis.breakEvenMonths.map { $0 * 2 } ?? 60, 24), 360)
        let stride = max(1, horizon / 60)
        return Swift.stride(from: 0, through: horizon, by: stride).map { month in
            CumulativePoint(
                month: month,
                net: analysis.monthlySavings * Double(month) - analysis.upfrontCost
            )
        }
    }

    private func verdictIcon(_ analysis: RefinanceAnalysis) -> String {
        if analysis.lifetimeSavings > 0 && analysis.monthlySavings > 0 {
            return "checkmark.seal.fill"
        }
        if analysis.monthlySavings > 0 {
            return "arrow.left.arrow.right.circle.fill"
        }
        return "xmark.seal.fill"
    }

    private func verdictColor(_ analysis: RefinanceAnalysis) -> Color {
        if analysis.lifetimeSavings > 0 && analysis.monthlySavings > 0 { return .green }
        if analysis.monthlySavings > 0 { return .orange }
        return .red
    }

    private func verdictHeadline(_ analysis: RefinanceAnalysis) -> String {
        if analysis.lifetimeSavings > 0 && analysis.monthlySavings > 0 {
            return "Cheaper every month and over the life of the loan"
        }
        if analysis.monthlySavings > 0 && analysis.lifetimeSavings <= 0 {
            return "Lower payment, higher total cost"
        }
        if analysis.monthlySavings <= 0 && analysis.lifetimeSavings > 0 {
            return "Higher payment, but less interest overall"
        }
        return "This offer costs more both ways"
    }

    private func verdictDetail(_ analysis: RefinanceAnalysis) -> String {
        let monthly = currency.formatValue(abs(analysis.monthlySavings))
        let lifetime = currency.formatValue(abs(analysis.lifetimeSavings))

        if analysis.monthlySavings > 0 && analysis.lifetimeSavings <= 0 {
            return "You free up \(monthly) a month, but pay \(lifetime) more in total. That trade makes sense only if the monthly cash flow matters more to you than the lifetime cost."
        }
        if analysis.monthlySavings <= 0 && analysis.lifetimeSavings > 0 {
            return "The payment rises by \(monthly), but you finish \(lifetime) ahead because the loan is retired sooner."
        }
        if analysis.monthlySavings > 0 {
            return "You save \(monthly) a month and \(lifetime) over the life of the loan."
        }
        return "The payment rises by \(monthly) and you pay \(lifetime) more overall."
    }
}

private extension RefinanceAnalysis {
    /// Human phrase for how much longer the new loan runs.
    func newTotalCostTermNote(remaining: Int) -> String {
        let extraMonths = max(Int((newTotalCost / max(newMonthlyPayment, 1)).rounded()) - remaining, 0)
        let years = Double(extraMonths) / 12
        return years >= 1
            ? "about \(String(format: "%.0f", years)) year\(years >= 2 ? "s" : "")"
            : "\(extraMonths) months"
    }
}
