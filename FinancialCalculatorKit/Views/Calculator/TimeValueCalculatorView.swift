//
//  TimeValueCalculatorView.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import SwiftUI
import SwiftData
import Charts
import LaTeXSwiftUI

/// Professional Time Value of Money planning workspace.
struct TimeValueCalculatorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(MainViewModel.self) private var mainViewModel

    @State private var calculation: TimeValueCalculation?
    @State private var calculationName: String = ""
    @State private var presentValue: Double? = nil
    @State private var futureValue: Double? = nil
    @State private var payment: Double? = nil
    @State private var interestRate: Double? = nil
    @State private var numberOfYears: Double? = nil
    @State private var paymentFrequency: PaymentFrequency = .monthly
    @State private var paymentsAtBeginning: Bool = false
    @State private var solveFor: TimeValueVariable = .futureValue
    @State private var currency: Currency = .usd

    @State private var isCalculating: Bool = false
    @State private var calculationResult: CalculationResult?
    @State private var validationErrors: [String] = []

    private var analysisSnapshot: TVMAnalysisSnapshot? {
        TVMAnalysisEngine.buildSnapshot(
            solveFor: solveFor,
            presentValue: presentValue,
            futureValue: futureValue,
            payment: payment,
            annualInterestRate: interestRate,
            numberOfYears: numberOfYears,
            paymentFrequency: paymentFrequency,
            paymentsAtBeginning: paymentsAtBeginning,
            result: calculationResult
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                headerSection
                workspaceSection
            }
            .padding(24)
        }
        .background(Color.clear)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Calculate") {
                    performCalculation()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCalculate)

                Button("Save") {
                    saveCalculation()
                }
                .disabled(calculationResult == nil || calculationName.isEmpty)

                Button("Clear") {
                    clearAll()
                }
                .buttonStyle(.bordered)
            }
        }
        .onAppear {
            loadUserPreferences()
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Time Value of Money")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Build funding plans, compare rate scenarios, and explain how each assumption changes the outcome. This view now works like a planning cockpit, not just a formula form.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: 720, alignment: .leading)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 10) {
                    Picker("Solve For", selection: $solveFor) {
                        ForEach(TimeValueVariable.allCases) { variable in
                            Text(variable.displayName)
                                .tag(variable)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 220)

                    Picker("Currency", selection: $currency) {
                        ForEach(Currency.allCases.prefix(10)) { curr in
                            Text("\(curr.symbol) \(curr.rawValue)")
                                .tag(curr)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 160)

                    HStack(spacing: 8) {
                        TVMHeaderPill(title: "Compounding", value: paymentFrequency.displayName)
                        TVMHeaderPill(title: "Mode", value: paymentsAtBeginning ? "Annuity Due" : "Ordinary")
                    }
                }
            }

            if !validationErrors.isEmpty {
                ErrorBanner(errors: validationErrors)
            }
        }
    }

    @ViewBuilder
    private var workspaceSection: some View {
        HStack(alignment: .top, spacing: 24) {
            configurationColumn
            analyticsColumn
        }
    }

    @ViewBuilder
    private var configurationColumn: some View {
        VStack(spacing: 20) {
            GroupBox("Plan Setup") {
                VStack(spacing: 16) {
                    InputFieldView(
                        title: "Calculation Name",
                        value: $calculationName,
                        placeholder: "My TVM Strategy",
                        validation: .required,
                        helpText: "Give this plan a descriptive name so it is easy to save and compare later.",
                        isRequired: true
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Compounding Frequency")
                                .font(.headline)
                                .fontWeight(.medium)

                            Spacer()

                            Text("\(Int(paymentFrequency.periodsPerYear)) periods/year")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Picker("Payment Frequency", selection: $paymentFrequency) {
                            ForEach(PaymentFrequency.allCases) { frequency in
                                Text(frequency.displayName)
                                    .tag(frequency)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Toggle("Payments at Beginning of Period", isOn: $paymentsAtBeginning)
                        .help("Use annuity-due timing when deposits or payments happen at the start of each compounding period.")
                }
                .padding(16)
            }
            .groupBoxStyle(FinancialGroupBoxStyle())

            GroupBox("Known Inputs") {
                VStack(spacing: 16) {
                    CurrencyInputField(
                        title: "Present Value (PV)",
                        subtitle: "Starting capital or current balance",
                        value: $presentValue,
                        currency: currency,
                        isRequired: solveFor != .presentValue,
                        helpText: "The current amount invested or financed."
                    )
                    .disabled(solveFor == .presentValue)

                    CurrencyInputField(
                        title: "Future Value (FV)",
                        subtitle: "Target value at the end of the plan",
                        value: $futureValue,
                        currency: currency,
                        isRequired: solveFor != .futureValue,
                        helpText: "The target amount you want to reach or settle."
                    )
                    .disabled(solveFor == .futureValue)

                    CurrencyInputField(
                        title: "Payment (PMT)",
                        subtitle: "Recurring deposit or payment amount",
                        value: $payment,
                        currency: currency,
                        isRequired: solveFor != .payment,
                        helpText: "The amount added or paid every compounding period."
                    )
                    .disabled(solveFor == .payment)

                    PercentageInputField(
                        title: "Annual Interest Rate",
                        subtitle: "Nominal annual rate",
                        value: $interestRate,
                        isRequired: solveFor != .interestRate,
                        helpText: "The stated annual rate before compounding frequency effects."
                    )
                    .disabled(solveFor == .interestRate)

                    InputFieldView(
                        title: "Number of Years",
                        subtitle: "Planning horizon",
                        value: Binding(
                            get: { numberOfYears?.description ?? "" },
                            set: { numberOfYears = Double($0) }
                        ),
                        placeholder: "10",
                        keyboardType: .decimalPad,
                        validation: solveFor != .numberOfYears ? .positiveNumber : nil,
                        helpText: "How long this plan runs before maturity or payoff.",
                        isRequired: solveFor != .numberOfYears
                    )
                    .disabled(solveFor == .numberOfYears)
                }
                .padding(16)
            }
            .groupBoxStyle(FinancialGroupBoxStyle())

            FormulaReferenceView(solveFor: solveFor)
        }
        .frame(maxWidth: 430)
    }

    @ViewBuilder
    private var analyticsColumn: some View {
        VStack(spacing: 20) {
            if isCalculating {
                LoadingResultView()
            } else if let result = calculationResult, let snapshot = analysisSnapshot {
                TVMHeroResultCard(
                    result: result,
                    solveFor: solveFor,
                    snapshot: snapshot,
                    currency: currency
                )

                TVMMetricGrid(snapshot: snapshot, currency: currency)

                TVMGrowthWorkspace(snapshot: snapshot, currency: currency)

                HStack(alignment: .top, spacing: 20) {
                    TVMScenarioExplorer(snapshot: snapshot, currency: currency)
                    TVMMilestoneBoard(snapshot: snapshot, currency: currency)
                }

                TVMInsightPanel(
                    insights: generateInsights(snapshot: snapshot, result: result)
                )
            } else {
                placeholderResultView
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var placeholderResultView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Plan Preview")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Once you calculate, this workspace will show the solved value, growth trajectory, scenario ladder, and milestone timing.")
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                TVMPreviewCard(
                    title: "Trajectory",
                    subtitle: "Balance versus contributed capital over time",
                    systemImage: "chart.line.uptrend.xyaxis"
                )
                TVMPreviewCard(
                    title: "Scenarios",
                    subtitle: "Defensive, base, and upside rate cases",
                    systemImage: "square.3.layers.3d.down.right"
                )
                TVMPreviewCard(
                    title: "Milestones",
                    subtitle: "When the plan reaches 25%, 50%, 75%, and target",
                    systemImage: "flag.pattern.checkered"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var canCalculate: Bool {
        let filledValues = [presentValue, futureValue, payment, interestRate, numberOfYears].compactMap { $0 }.count
        return filledValues >= 4 && !calculationName.isEmpty
    }

    private func performCalculation() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isCalculating = true
            validationErrors = []
        }

        let tempCalculation = TimeValueCalculation(
            name: calculationName,
            paymentFrequency: paymentFrequency,
            paymentsAtBeginning: paymentsAtBeginning,
            solveFor: solveFor,
            currency: currency
        )

        tempCalculation.presentValue = presentValue
        tempCalculation.futureValue = futureValue
        tempCalculation.payment = payment
        tempCalculation.annualInterestRate = interestRate
        tempCalculation.numberOfYears = numberOfYears

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeInOut(duration: 0.25)) {
                isCalculating = false

                if tempCalculation.isValid {
                    calculationResult = tempCalculation.result
                    calculation = tempCalculation
                } else {
                    validationErrors = tempCalculation.validationErrors
                    calculationResult = nil
                }
            }
        }
    }

    private func saveCalculation() {
        guard let calc = calculation else { return }

        modelContext.insert(calc)

        do {
            try modelContext.save()
        } catch {
            mainViewModel.handleError(.dataExportFailed("Failed to save calculation: \(error.localizedDescription)"))
        }
    }

    private func clearAll() {
        withAnimation(.easeInOut(duration: 0.25)) {
            presentValue = nil
            futureValue = nil
            payment = nil
            interestRate = nil
            numberOfYears = nil
            calculationResult = nil
            validationErrors = []
            calculationName = ""
        }
    }

    private func loadUserPreferences() {
        currency = mainViewModel.userPreferences.defaultCurrency
        paymentFrequency = mainViewModel.userPreferences.defaultPaymentFrequency
    }

    private func generateInsights(snapshot: TVMAnalysisSnapshot, result: CalculationResult) -> [String] {
        var insights: [String] = []

        insights.append("Effective annual rate is \(String(format: "%.2f%%", snapshot.effectiveAnnualRate)), which captures the real compounding lift beyond the nominal rate.")

        if snapshot.interestEarned > 0 {
            insights.append("Projected growth attributable to compounding is \(currency.formatValue(snapshot.interestEarned)), on top of \(currency.formatValue(snapshot.resolvedPresentValue + snapshot.totalScheduledPayments)) of principal and scheduled payments.")
        }

        if let targetMilestone = snapshot.milestones.last {
            insights.append("The current plan reaches the target zone around year \(String(format: "%.1f", targetMilestone.year)).")
        }

        if let bestScenario = snapshot.scenarios.max(by: { $0.futureValue < $1.futureValue }),
           let baseScenario = snapshot.scenarios.first(where: { $0.title == "Base" }) {
            let upside = bestScenario.futureValue - baseScenario.futureValue
            insights.append("A two-point improvement in rate assumptions lifts the terminal value by roughly \(currency.formatValue(upside)) versus the base case.")
        }

        if solveFor == .payment {
            insights.append("The solved payment can be treated as a budget target. Use the scenario ladder to judge whether the required cash flow still feels comfortable under different rate conditions.")
        }

        return insights
    }
}

/// Error banner component
struct ErrorBanner: View {
    let errors: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)

                Text("Please fix the following issues:")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            ForEach(errors, id: \.self) { error in
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                        .foregroundColor(.red)

                    Text(error)
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.red.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

/// Formula reference component
struct FormulaReferenceView: View {
    let solveFor: TimeValueVariable
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "function")
                        .foregroundColor(.accentColor)

                    Text("Formula Reference")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Text(formulaDescription)
                        .font(.body)
                        .foregroundColor(.secondary)

                    LaTeX(formulaText)
                        .frame(height: 50)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )

                    if !variableDefinitions.isEmpty {
                        Text("Where:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        ForEach(variableDefinitions, id: \.0) { variable, definition in
                            HStack(alignment: .top, spacing: 8) {
                                Text(variable)
                                    .font(.system(.caption, design: .monospaced))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.accentColor)

                                Text("=")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text(definition)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.accentColor.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private var formulaDescription: String {
        switch solveFor {
        case .presentValue:
            return "Discount future cash flows and recurring payments back to today."
        case .futureValue:
            return "Project the end balance from current capital and recurring payments."
        case .payment:
            return "Solve the recurring payment needed to achieve the target."
        case .interestRate:
            return "Solve the required annual rate using iterative methods."
        case .numberOfYears:
            return "Solve the time required to reach the target under the current cash-flow assumptions."
        }
    }

    private var formulaText: String {
        switch solveFor {
        case .presentValue:
            return "$$PV = \\frac{FV}{(1 + r)^n} + PMT \\times \\frac{1 - (1 + r)^{-n}}{r}$$"
        case .futureValue:
            return "$$FV = PV \\times (1 + r)^n + PMT \\times \\frac{(1 + r)^n - 1}{r}$$"
        case .payment:
            return "$$PMT = \\frac{PV \\times r}{1 - (1 + r)^{-n}}$$"
        case .interestRate:
            return "$$r = \\text{Solved numerically using Newton-Raphson}$$"
        case .numberOfYears:
            return "$$n = \\frac{\\ln(FV/PV)}{\\ln(1 + r)}$$"
        }
    }

    private var variableDefinitions: [(String, String)] {
        [
            ("PV", "Present value"),
            ("FV", "Future value"),
            ("PMT", "Periodic payment"),
            ("r", "Interest rate per period"),
            ("n", "Number of periods")
        ]
    }
}

private struct TVMHeaderPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

private struct TVMPreviewCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(.accentColor)

            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

private struct TVMHeroResultCard: View {
    let result: CalculationResult
    let solveFor: TimeValueVariable
    let snapshot: TVMAnalysisSnapshot
    let currency: Currency

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(solveFor.displayName)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(result.formattedPrimaryValue)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text(result.explanation)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text("Terminal Value")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(currency.formatValue(snapshot.growthTimeline.last?.y ?? snapshot.resolvedFutureValue))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }

            Divider()

            HStack(spacing: 16) {
                TVMQuickDetail(title: "Starting Capital", value: currency.formatValue(snapshot.resolvedPresentValue))
                TVMQuickDetail(title: "Recurring Payment", value: currency.formatValue(snapshot.resolvedPayment))
                TVMQuickDetail(title: "Plan Horizon", value: String(format: "%.1f years", snapshot.years))
                TVMQuickDetail(title: "Nominal Rate", value: String(format: "%.2f%%", snapshot.annualRate))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private struct TVMQuickDetail: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.callout)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TVMMetricGrid: View {
    let snapshot: TVMAnalysisSnapshot
    let currency: Currency

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 14) {
            TVMMetricCard(
                title: "Scheduled Payments",
                value: currency.formatValue(snapshot.totalScheduledPayments),
                subtitle: "Total recurring cash flow"
            )
            TVMMetricCard(
                title: "Effective Annual Rate",
                value: String(format: "%.2f%%", snapshot.effectiveAnnualRate),
                subtitle: "Compounding-adjusted yield"
            )
            TVMMetricCard(
                title: "Interest Earned",
                value: currency.formatValue(snapshot.interestEarned),
                subtitle: "Growth above principal"
            )
            TVMMetricCard(
                title: "Net Growth",
                value: currency.formatValue(snapshot.netGrowth),
                subtitle: "Terminal minus starting value"
            )
        }
    }
}

private struct TVMMetricCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

private struct TVMGrowthWorkspace: View {
    let snapshot: TVMAnalysisSnapshot
    let currency: Currency

    private struct SeriesPoint: Identifiable {
        let id = UUID()
        let series: String
        let x: Double
        let y: Double
    }

    private var seriesPoints: [SeriesPoint] {
        let growth = snapshot.growthTimeline.map { SeriesPoint(series: "Projected Value", x: $0.x, y: $0.y) }
        let principal = snapshot.contributionTimeline.map { SeriesPoint(series: "Capital + Payments", x: $0.x, y: $0.y) }
        return growth + principal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Growth Workspace")
                .font(.headline)
                .fontWeight(.semibold)

            Chart(seriesPoints) { point in
                LineMark(
                    x: .value("Year", point.x),
                    y: .value("Value", point.y)
                )
                .foregroundStyle(by: .value("Series", point.series))
                .interpolationMethod(.catmullRom)

                if point.series == "Projected Value" {
                    AreaMark(
                        x: .value("Year", point.x),
                        y: .value("Value", point.y)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [.accentColor.opacity(0.18), .accentColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .frame(height: 280)
            .chartForegroundStyleScale([
                "Projected Value": Color.accentColor,
                "Capital + Payments": Color.secondary
            ])
            .chartLegend(position: .bottom, alignment: .leading)
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(currency.formatValue(amount))
                        }
                    }
                }
            }

            Text("The projected-value curve shows when compounding starts to dominate contributions. The gap between the two lines is your earned growth.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private struct TVMScenarioExplorer: View {
    let snapshot: TVMAnalysisSnapshot
    let currency: Currency

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Scenario Ladder")
                .font(.headline)
                .fontWeight(.semibold)

            Chart(snapshot.scenarios) { scenario in
                BarMark(
                    x: .value("Scenario", scenario.title),
                    y: .value("Future Value", scenario.futureValue)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .annotation(position: .top) {
                    Text(currency.formatValue(scenario.futureValue))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 220)
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(currency.formatValue(amount))
                        }
                    }
                }
            }

            ForEach(snapshot.scenarios) { scenario in
                HStack {
                    Text("\(scenario.title) • \(String(format: "%.2f%%", scenario.annualRate))")
                        .font(.caption)
                    Spacer()
                    Text(currency.formatValue(scenario.futureValue))
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

private struct TVMMilestoneBoard: View {
    let snapshot: TVMAnalysisSnapshot
    let currency: Currency

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Milestones")
                .font(.headline)
                .fontWeight(.semibold)

            ForEach(snapshot.milestones) { milestone in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(milestone.title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Year \(String(format: "%.1f", milestone.year))")
                            .font(.callout)
                            .fontWeight(.semibold)
                    }

                    Spacer()

                    Text(currency.formatValue(milestone.balance))
                        .font(.callout)
                        .fontWeight(.semibold)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.primary.opacity(0.05))
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

private struct TVMInsightPanel: View {
    let insights: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Planner Takeaways")
                .font(.headline)
                .fontWeight(.semibold)

            ForEach(insights, id: \.self) { insight in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.accentColor)
                        .font(.caption)
                    Text(insight)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [.accentColor.opacity(0.10), .accentColor.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

#Preview {
    TimeValueCalculatorView()
        .environment(MainViewModel())
        .modelContainer(for: TimeValueCalculation.self, inMemory: true)
        .frame(width: 1280, height: 860)
}
