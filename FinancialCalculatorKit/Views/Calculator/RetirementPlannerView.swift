//
//  RetirementPlannerView.swift
//  FinancialCalculatorKit
//
//  Retirement planning workflow: project savings to retirement, compare against
//  the nest egg the desired income requires, and quantify any gap.
//

import SwiftUI
import SwiftData
import Charts

struct RetirementPlannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(MainViewModel.self) private var mainViewModel

    @State private var calculationName: String = ""
    @State private var currentAge: Double? = 35
    @State private var retirementAge: Double? = 65
    @State private var lifeExpectancy: Double? = 90
    @State private var currentSavings: Double? = 50_000
    @State private var monthlyContribution: Double? = 1_000
    @State private var preRetirementReturn: Double? = 7.0
    @State private var inRetirementReturn: Double? = 4.0
    @State private var inflationRate: Double? = 2.5
    @State private var returnVolatility: Double? = 12.0
    @State private var desiredMonthlyIncome: Double? = 5_000
    @State private var currency: Currency = .usd

    @State private var projection: RetirementProjection?
    @State private var validationErrors: [String] = []
    @State private var didSave: Bool = false
    @State private var showingMonteCarlo: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                HStack(alignment: .top, spacing: 24) {
                    inputSection
                        .frame(minWidth: 340, maxWidth: 420)
                    resultSection
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 24)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: saveCalculation) {
                    Label(didSave ? "Saved" : "Save", systemImage: didSave ? "checkmark" : "square.and.arrow.down")
                }
                .disabled(!canSave)
                .help("Save this plan")

                Menu {
                    Button("Monte Carlo Analysis", action: { showingMonteCarlo = true })
                        .disabled(projection == nil)

                    Button("Export Results", action: exportResults)
                        .disabled(projection == nil)

                    Divider()

                    Button("Reset Fields", action: resetFields)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .help("More actions")
                .accessibilityLabel("More Actions")
            }
        }
        .sheet(isPresented: $showingMonteCarlo) {
            RetirementMonteCarloSheet(inputs: monteCarloInputs, currency: currency)
        }
        .onAppear {
            currency = mainViewModel.userPreferences.defaultCurrency
        }
    }

    /// Snapshot of the current inputs for the stochastic analysis.
    private var monteCarloInputs: RetirementMonteCarloInputs {
        RetirementMonteCarloInputs(
            currentAge: currentAge ?? 0,
            retirementAge: retirementAge ?? 0,
            lifeExpectancy: lifeExpectancy ?? 0,
            currentSavings: currentSavings ?? 0,
            monthlyContribution: monthlyContribution ?? 0,
            preRetirementReturn: preRetirementReturn ?? 0,
            inRetirementReturn: inRetirementReturn ?? 0,
            returnVolatility: returnVolatility ?? 0,
            inflationRate: inflationRate ?? 0,
            desiredMonthlyIncome: desiredMonthlyIncome ?? 0
        )
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 16) {
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("Retirement Planner")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Project your savings to retirement and check whether they fund the income you want.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Inputs

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Plan") {
                VStack(alignment: .leading, spacing: 12) {
                    InputFieldView(
                        title: "Plan Name",
                        value: $calculationName,
                        placeholder: "My Retirement Plan",
                        isRequired: true
                    )

                    ageField("Current Age", value: $currentAge, help: "Your age today, in years")
                    ageField("Retirement Age", value: $retirementAge, help: "The age you plan to stop working")
                    ageField("Plan Through Age", value: $lifeExpectancy, help: "The age the plan must fund through")
                }
                .padding(8)
            }
            .groupBoxStyle(FinancialGroupBoxStyle())

            GroupBox("Savings") {
                VStack(alignment: .leading, spacing: 12) {
                    CurrencyInputField(
                        title: "Current Savings",
                        value: $currentSavings,
                        currency: currency,
                        helpText: "Retirement savings you already have"
                    )

                    CurrencyInputField(
                        title: "Monthly Contribution",
                        value: $monthlyContribution,
                        currency: currency,
                        helpText: "Amount added at the end of each month until retirement"
                    )

                    CurrencyInputField(
                        title: "Desired Monthly Income",
                        subtitle: "In today's purchasing power",
                        value: $desiredMonthlyIncome,
                        currency: currency,
                        isRequired: true,
                        helpText: "The gross monthly amount you want to withdraw in retirement, stated in today's dollars"
                    )
                }
                .padding(8)
            }
            .groupBoxStyle(FinancialGroupBoxStyle())

            GroupBox("Assumptions") {
                VStack(alignment: .leading, spacing: 12) {
                    PercentageInputField(
                        title: "Return Before Retirement",
                        value: $preRetirementReturn,
                        helpText: "Expected annual return while contributing"
                    )

                    PercentageInputField(
                        title: "Return In Retirement",
                        value: $inRetirementReturn,
                        helpText: "Expected annual return on the balance while withdrawing"
                    )

                    PercentageInputField(
                        title: "Inflation",
                        value: $inflationRate,
                        helpText: "Expected annual inflation; withdrawals grow at this rate"
                    )

                    PercentageInputField(
                        title: "Return Volatility",
                        subtitle: "Used by Monte Carlo analysis",
                        value: $returnVolatility,
                        helpText: "Annual standard deviation of returns. A diversified stock-heavy portfolio has run roughly 15%; a balanced portfolio closer to 10%."
                    )

                    Picker("Currency", selection: $currency) {
                        ForEach(Currency.allCases) { currency in
                            Text("\(currency.displayName) (\(currency.symbol))")
                                .tag(currency)
                        }
                    }
                }
                .padding(8)
            }
            .groupBoxStyle(FinancialGroupBoxStyle())

            Button(action: performCalculation) {
                Label("Calculate Plan", systemImage: "equal.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canCalculate)

            if !validationErrors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(validationErrors, id: \.self) { error in
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .onChange(of: currentAge) { _, _ in clearResults() }
        .onChange(of: retirementAge) { _, _ in clearResults() }
        .onChange(of: lifeExpectancy) { _, _ in clearResults() }
        .onChange(of: currentSavings) { _, _ in clearResults() }
        .onChange(of: monthlyContribution) { _, _ in clearResults() }
        .onChange(of: preRetirementReturn) { _, _ in clearResults() }
        .onChange(of: inRetirementReturn) { _, _ in clearResults() }
        .onChange(of: inflationRate) { _, _ in clearResults() }
        .onChange(of: returnVolatility) { _, _ in clearResults() }
        .onChange(of: desiredMonthlyIncome) { _, _ in clearResults() }
        .onChange(of: currency) { _, _ in clearResults() }
    }

    private func ageField(_ title: String, value: Binding<Double?>, help: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.medium)
                .frame(width: 150, alignment: .leading)

            TextField(title, value: value, format: .number.precision(.fractionLength(0)))
                .textFieldStyle(FinancialTextFieldStyle(isEditing: false, hasError: false, isFocused: false))

            Text("years")
                .font(.caption)
                .foregroundColor(.secondary)

            Image(systemName: "questionmark.circle")
                .font(.callout)
                .foregroundColor(.secondary)
                .help(help)
        }
    }

    // MARK: - Results

    @ViewBuilder
    private var resultSection: some View {
        if let projection = projection {
            VStack(alignment: .leading, spacing: 16) {
                projectionSummaryCard(projection)

                Button(action: { showingMonteCarlo = true }) {
                    Label("Run Monte Carlo Analysis", systemImage: "chart.line.uptrend.xyaxis")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help("Test this plan against thousands of simulated market paths")

                gapCard(projection)
                timelineChart(projection)
            }
        } else {
            VStack(spacing: 16) {
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary.opacity(0.5))

                Text("Plan Preview")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text("Enter your plan details and press Calculate Plan to see the projection.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            )
        }
    }

    private func projectionSummaryCard(_ projection: RetirementProjection) -> some View {
        GroupBox {
            VStack(spacing: 12) {
                Text("Projected Balance at Retirement")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text(currency.formatValue(projection.projectedNestEgg))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Image(systemName: projection.surplus >= 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(projection.surplus >= 0 ? .green : .orange)

                    Text(projection.surplus >= 0
                         ? "On track — covers the desired income through age \(Int(lifeExpectancy ?? 0))"
                         : "Shortfall of \(currency.formatValue(-projection.surplus)) versus the required nest egg")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .groupBoxStyle(FinancialGroupBoxStyle())
    }

    private func gapCard(_ projection: RetirementProjection) -> some View {
        GroupBox("Plan Details") {
            VStack(spacing: 4) {
                DetailRow(
                    title: "Required Nest Egg",
                    value: currency.formatValue(projection.requiredNestEgg),
                    isHighlighted: projection.surplus < 0
                )
                DetailRow(
                    title: "First-Year Monthly Income (Future Dollars)",
                    value: currency.formatValue(projection.incomeAtRetirement)
                )
                DetailRow(
                    title: "Sustainable Income (Today's Dollars)",
                    value: currency.formatValue(projection.sustainableMonthlyIncomeToday)
                )
                if projection.surplus < 0 {
                    DetailRow(
                        title: "Additional Monthly Savings Needed",
                        value: currency.formatValue(projection.additionalMonthlySavingsNeeded),
                        isHighlighted: true
                    )
                    if let depletionAge = projection.depletionAge {
                        DetailRow(
                            title: "Balance Depleted Around Age",
                            value: String(format: "%.0f", depletionAge),
                            isHighlighted: true
                        )
                    }
                } else {
                    DetailRow(
                        title: "Projected Surplus",
                        value: currency.formatValue(projection.surplus)
                    )
                }
            }
            .padding(8)
        }
        .groupBoxStyle(FinancialGroupBoxStyle())
    }

    private func timelineChart(_ projection: RetirementProjection) -> some View {
        GroupBox("Balance Over Time") {
            VStack(alignment: .leading, spacing: 8) {
                Chart(projection.timeline) { point in
                    AreaMark(
                        x: .value("Age", point.x),
                        y: .value("Balance", point.y)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [Color.accentColor.opacity(0.5), Color.accentColor.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Age", point.x),
                        y: .value("Balance", point.y)
                    )
                    .foregroundStyle(Color.accentColor)
                    .interpolationMethod(.monotone)
                }
                .chartXAxisLabel("Age")
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(Formatters.formatAbbreviated(doubleValue))
                                    .font(.caption)
                            }
                        }
                    }
                }
                .frame(height: 260)

                if let retirementAge = retirementAge {
                    Text("Grows with contributions until age \(Int(retirementAge)), then draws the desired income (rising with inflation).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
        }
        .groupBoxStyle(FinancialGroupBoxStyle())
    }

    // MARK: - Actions

    private var canCalculate: Bool {
        currentAge != nil && retirementAge != nil && lifeExpectancy != nil &&
        desiredMonthlyIncome != nil && buildCalculation().isValid
    }

    private var canSave: Bool {
        projection != nil && !calculationName.isEmpty
    }

    /// Build an unsaved model from the current field values.
    private func buildCalculation() -> RetirementPlanCalculation {
        RetirementPlanCalculation(
            name: calculationName.isEmpty ? "Retirement Plan" : calculationName,
            currentAge: currentAge ?? 0,
            retirementAge: retirementAge ?? 0,
            lifeExpectancy: lifeExpectancy ?? 0,
            currentSavings: currentSavings ?? 0,
            monthlyContribution: monthlyContribution ?? 0,
            preRetirementReturn: preRetirementReturn ?? 0,
            inRetirementReturn: inRetirementReturn ?? 0,
            inflationRate: inflationRate ?? 0,
            desiredMonthlyIncome: desiredMonthlyIncome ?? 0,
            currency: currency
        )
    }

    private func performCalculation() {
        let calculation = buildCalculation()
        validationErrors = calculation.validationErrors.filter { $0 != "Name is required" }
        guard validationErrors.isEmpty else {
            projection = nil
            return
        }

        projection = RetirementPlanCalculation.project(
            currentAge: calculation.currentAge,
            retirementAge: calculation.retirementAge,
            lifeExpectancy: calculation.lifeExpectancy,
            currentSavings: calculation.currentSavings,
            monthlyContribution: calculation.monthlyContribution,
            preRetirementReturn: calculation.preRetirementReturn,
            inRetirementReturn: calculation.inRetirementReturn,
            inflationRate: calculation.inflationRate,
            desiredMonthlyIncome: calculation.desiredMonthlyIncome
        )
    }

    private func clearResults() {
        projection = nil
        validationErrors = []
        didSave = false
    }

    private func resetFields() {
        calculationName = ""
        currentAge = 35
        retirementAge = 65
        lifeExpectancy = 90
        currentSavings = 50_000
        monthlyContribution = 1_000
        preRetirementReturn = 7.0
        inRetirementReturn = 4.0
        inflationRate = 2.5
        returnVolatility = 12.0
        desiredMonthlyIncome = 5_000
        currency = mainViewModel.userPreferences.defaultCurrency
        clearResults()
    }

    private func saveCalculation() {
        guard canSave else { return }
        let calculation = buildCalculation()
        calculation.updateTimestamp()
        modelContext.insert(calculation)

        do {
            try modelContext.save()
            didSave = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                didSave = false
            }
        } catch {
            mainViewModel.handleError(.dataExportFailed("Could not save the plan: \(error.localizedDescription)"))
        }
    }

    private func exportResults() {
        let calculation = buildCalculation()
        do {
            let exported = try CalculationExporter.exportResult(
                suggestedName: calculationName.isEmpty ? "Retirement Plan" : calculationName,
                primaryLabel: "Projected Balance at Retirement",
                result: calculation.result
            )
            _ = exported
        } catch {
            mainViewModel.handleError(.dataExportFailed(error.localizedDescription))
        }
    }
}

#Preview {
    RetirementPlannerView()
        .environment(MainViewModel())
        .modelContainer(for: RetirementPlanCalculation.self, inMemory: true)
        .frame(width: 1000, height: 800)
}
