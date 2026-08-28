//
//  DebtPayoffCalculatorView.swift
//  FinancialCalculatorKit
//
//  Multi-debt payoff planning: compare avalanche, snowball, and doing nothing.
//

import SwiftUI
import SwiftData
import Charts

struct DebtPayoffCalculatorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(MainViewModel.self) private var mainViewModel

    @State private var calculationName: String = ""
    @State private var debts: [Debt] = []
    @State private var extraPayment: Double? = 200
    @State private var currency: Currency = .usd

    @State private var plans: [DebtPayoffPlan] = []
    @State private var planError: String?
    @State private var didSave: Bool = false
    @State private var editingDebt: Debt?
    @State private var showingDebtEditor: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection

                HStack(alignment: .top, spacing: 24) {
                    inputColumn
                        .frame(width: 420)
                    resultColumn
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 24)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Compare Strategies") {
                    recalculate()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCalculate)

                Button(didSave ? "Saved" : "Save", systemImage: didSave ? "checkmark" : "square.and.arrow.down") {
                    saveCalculation()
                }
                .disabled(plans.isEmpty || calculationName.isEmpty || didSave)

                Menu {
                    Button("Export Results", action: exportResults)
                        .disabled(plans.isEmpty)
                    Divider()
                    Button("Load Example", action: loadExample)
                    Button("Clear All", action: clearAll)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .help("More actions")
                .accessibilityLabel("More Actions")
            }
        }
        .sheet(isPresented: $showingDebtEditor) {
            DebtEditorSheet(
                debt: editingDebt,
                currency: currency,
                onSave: { updated in
                    if let index = debts.firstIndex(where: { $0.id == updated.id }) {
                        debts[index] = updated
                    } else {
                        debts.append(updated)
                    }
                    clearResults()
                }
            )
        }
        .onAppear {
            currency = mainViewModel.userPreferences.defaultCurrency
            restorePendingCalculation()
            if debts.isEmpty {
                loadExample()
            }
        }
        .onChange(of: mainViewModel.pendingLoadID) { _, _ in
            restorePendingCalculation()
        }
        .onChange(of: extraPayment) { _, _ in clearResults() }
        .onChange(of: currency) { _, _ in clearResults() }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 16) {
            Image(systemName: "creditcard.trianglebadge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("Debt Payoff Planner")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Compare paying the highest rate first, the smallest balance first, or just the minimums.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Inputs

    private var inputColumn: some View {
        VStack(spacing: 16) {
            GroupBox("Plan") {
                VStack(alignment: .leading, spacing: 12) {
                    InputFieldView(
                        title: "Plan Name",
                        value: $calculationName,
                        placeholder: "My Debt Payoff Plan",
                        isRequired: true
                    )

                    CurrencyInputField(
                        title: "Extra Monthly Payment",
                        subtitle: "On top of the combined minimums",
                        value: $extraPayment,
                        currency: currency,
                        helpText: "Every strategy spends the same total each month, so the comparison is fair"
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

            GroupBox("Your Debts") {
                VStack(alignment: .leading, spacing: 10) {
                    if debts.isEmpty {
                        Text("No debts added yet.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(debts) { debt in
                            DebtRow(debt: debt, currency: currency)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingDebt = debt
                                    showingDebtEditor = true
                                }
                                .contextMenu {
                                    Button("Edit") {
                                        editingDebt = debt
                                        showingDebtEditor = true
                                    }
                                    Button("Delete", role: .destructive) {
                                        debts.removeAll { $0.id == debt.id }
                                        clearResults()
                                    }
                                }
                        }

                        Divider()

                        HStack {
                            Text("Total Owed")
                                .font(.callout)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(currency.formatValue(totalBalance))
                                .font(.callout)
                                .fontWeight(.semibold)
                        }
                        HStack {
                            Text("Combined Minimums")
                                .font(.callout)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(currency.formatValue(totalMinimums) + " / month")
                                .font(.callout)
                                .fontWeight(.semibold)
                        }
                        HStack {
                            Text("Monthly Budget")
                                .font(.callout)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(currency.formatValue(totalMinimums + (extraPayment ?? 0)) + " / month")
                                .font(.callout)
                                .fontWeight(.bold)
                        }
                    }

                    Button {
                        editingDebt = nil
                        showingDebtEditor = true
                    } label: {
                        Label("Add Debt", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
                }
                .padding(8)
            }
            .groupBoxStyle(FinancialGroupBoxStyle())

            if let planError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(planError)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.08))
                )
            }
        }
    }

    // MARK: - Results

    @ViewBuilder
    private var resultColumn: some View {
        if plans.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary.opacity(0.5))

                Text("Strategy Comparison")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text("Add your debts and press Compare Strategies to see how much sooner — and cheaper — each approach clears them.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            )
        } else {
            VStack(alignment: .leading, spacing: 16) {
                verdictCard
                strategyCards
                balanceChart
                payoffOrderCard
            }
        }
    }

    @ViewBuilder
    private var verdictCard: some View {
        if let avalanche = plans.first(where: { $0.strategy == .avalanche }),
           let snowball = plans.first(where: { $0.strategy == .snowball }) {
            let interestGap = snowball.totalInterest - avalanche.totalInterest
            let monthGap = snowball.months - avalanche.months

            GroupBox {
                VStack(spacing: 10) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 30))
                        .foregroundColor(.accentColor)

                    Text("Debt-free in \(Formatters.formatDuration(years: Double(avalanche.months) / 12))")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(comparisonNarrative(interestGap: interestGap, monthGap: monthGap))
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
    }

    private var strategyCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(plans, id: \.strategy) { plan in
                StrategyCard(
                    plan: plan,
                    currency: currency,
                    isBest: plan.strategy == bestStrategy
                )
            }
        }
    }

    private var balanceChart: some View {
        GroupBox("Balance Over Time") {
            VStack(alignment: .leading, spacing: 8) {
                Chart {
                    ForEach(plans, id: \.strategy) { plan in
                        ForEach(plan.balanceTimeline) { point in
                            LineMark(
                                x: .value("Month", point.month),
                                y: .value("Balance", point.totalBalance)
                            )
                            .foregroundStyle(by: .value("Strategy", plan.strategy.displayName))
                            .interpolationMethod(.monotone)
                        }
                    }
                }
                .frame(height: 260)
                .chartXAxisLabel("Months from today")
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

                Text("Where a line reaches zero is the month that strategy clears every balance.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(8)
        }
        .groupBoxStyle(FinancialGroupBoxStyle())
    }

    @ViewBuilder
    private var payoffOrderCard: some View {
        if let best = plans.first(where: { $0.strategy == bestStrategy }), !best.milestones.isEmpty {
            GroupBox("Payoff Order — \(best.strategy.displayName)") {
                VStack(spacing: 4) {
                    ForEach(best.milestones) { milestone in
                        DetailRow(
                            title: milestone.debtName,
                            value: "Month \(milestone.month) • \(currency.formatValue(milestone.interestPaid)) interest"
                        )
                    }
                }
                .padding(8)
            }
            .groupBoxStyle(FinancialGroupBoxStyle())
        }
    }

    // MARK: - Derived values

    private var totalBalance: Double {
        debts.reduce(0) { $0 + $1.balance }
    }

    private var totalMinimums: Double {
        debts.reduce(0) { $0 + $1.minimumPayment }
    }

    private var canCalculate: Bool {
        !debts.isEmpty && debts.contains { $0.balance > 0 } && !calculationName.isEmpty
    }

    /// Cheapest strategy that actually retires the debt.
    private var bestStrategy: PayoffStrategy {
        plans.filter { $0.strategy != .minimumsOnly }
            .min { $0.totalInterest < $1.totalInterest }?
            .strategy ?? .avalanche
    }

    private func comparisonNarrative(interestGap: Double, monthGap: Int) -> String {
        if interestGap <= 0.01 && monthGap == 0 {
            return "Avalanche and snowball finish at the same time and cost the same here — with these balances and rates the order does not matter."
        }
        let money = currency.formatValue(abs(interestGap))
        if monthGap > 0 {
            return "Avalanche saves \(money) in interest and finishes \(monthGap) month\(monthGap == 1 ? "" : "s") sooner than snowball. Snowball still clears your smallest balance first, if early wins keep you going."
        }
        return "Avalanche saves \(money) in interest. Snowball finishes at the same time but clears your smallest balance first, which some people find easier to sustain."
    }

    // MARK: - Actions

    private func recalculate() {
        planError = nil
        didSave = false

        do {
            // Surface a real reason if the budget cannot retire the debt
            _ = try DebtPayoffPlanner.plan(
                debts: debts,
                extraPayment: extraPayment ?? 0,
                strategy: .avalanche
            )
            plans = DebtPayoffPlanner.compareAll(debts: debts, extraPayment: extraPayment ?? 0)
        } catch {
            plans = []
            planError = error.localizedDescription
        }
    }

    private func clearResults() {
        plans = []
        planError = nil
        didSave = false
    }

    /// Restore a saved plan the user opened from the sidebar or dashboard.
    private func restorePendingCalculation() {
        guard let id = mainViewModel.takePendingLoadID(for: .debtPayoff) else { return }

        var descriptor = FetchDescriptor<DebtPayoffCalculation>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        guard let saved = try? modelContext.fetch(descriptor).first else { return }

        calculationName = saved.name
        debts = saved.debts
        extraPayment = saved.extraPayment
        currency = saved.currency

        planError = nil
        didSave = false
        recalculate()
    }

    private func loadExample() {
        debts = [
            Debt(name: "Credit Card", balance: 8_500, annualRate: 22.9, minimumPayment: 210),
            Debt(name: "Car Loan", balance: 14_200, annualRate: 6.4, minimumPayment: 320),
            Debt(name: "Student Loan", balance: 21_000, annualRate: 4.5, minimumPayment: 240)
        ]
        if calculationName.isEmpty {
            calculationName = "Example Payoff Plan"
        }
        clearResults()
    }

    private func clearAll() {
        debts = []
        calculationName = ""
        extraPayment = 200
        clearResults()
    }

    private func saveCalculation() {
        guard canCalculate else { return }

        let calculation = DebtPayoffCalculation(
            name: calculationName,
            debts: debts,
            extraPayment: extraPayment ?? 0,
            strategy: bestStrategy,
            currency: currency
        )
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
        guard !plans.isEmpty else { return }

        let headers = ["Strategy", "Months", "Total Interest", "Total Paid", "Monthly Budget"]
        let rows = plans.map { plan in
            [
                "Strategy": plan.strategy.displayName,
                "Months": "\(plan.months)",
                "Total Interest": String(format: "%.2f", plan.totalInterest),
                "Total Paid": String(format: "%.2f", plan.totalPaid),
                "Monthly Budget": String(format: "%.2f", plan.monthlyBudget)
            ]
        }

        do {
            _ = try CalculationExporter.exportCSV(
                suggestedName: calculationName.isEmpty ? "Debt Payoff Plan" : calculationName,
                headers: headers,
                rows: rows
            )
        } catch {
            mainViewModel.handleError(.dataExportFailed(error.localizedDescription))
        }
    }
}

// MARK: - Supporting Views

private struct DebtRow: View {
    let debt: Debt
    let currency: Currency

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(debt.name)
                    .font(.body)
                    .fontWeight(.medium)
                Text("\(String(format: "%.2f%%", debt.annualRate)) • \(currency.formatValue(debt.minimumPayment))/mo minimum")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(currency.formatValue(debt.balance))
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

private struct StrategyCard: View {
    let plan: DebtPayoffPlan
    let currency: Currency
    let isBest: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(plan.strategy.displayName)
                    .font(.headline)
                Spacer()
                if isBest {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .help("Least interest of the strategies that retire the debt")
                }
            }

            Text(plan.strategy.subtitle)
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            Text(Formatters.formatDuration(years: Double(plan.months) / 12))
                .font(.title3)
                .fontWeight(.bold)

            Text("\(currency.formatValue(plan.totalInterest)) interest")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isBest ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isBest ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .help(plan.strategy.explanation)
    }
}

private struct DebtEditorSheet: View {
    let debt: Debt?
    let currency: Currency
    let onSave: (Debt) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var balance: Double? = nil
    @State private var rate: Double? = nil
    @State private var minimum: Double? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Debt") {
                    TextField("Name", text: $name)

                    CurrencyInputField(
                        title: "Balance",
                        value: $balance,
                        currency: currency,
                        isRequired: true,
                        helpText: "What you owe today"
                    )

                    PercentageInputField(
                        title: "Interest Rate",
                        value: $rate,
                        isRequired: true,
                        helpText: "The annual rate charged on this balance"
                    )

                    CurrencyInputField(
                        title: "Minimum Payment",
                        value: $minimum,
                        currency: currency,
                        isRequired: true,
                        helpText: "The smallest payment the lender accepts each month"
                    )
                }
            }
            .formStyle(.grouped)
            .navigationTitle(debt == nil ? "Add Debt" : "Edit Debt")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            Debt(
                                id: debt?.id ?? UUID(),
                                name: name.isEmpty ? "Debt" : name,
                                balance: balance ?? 0,
                                annualRate: rate ?? 0,
                                minimumPayment: minimum ?? 0
                            )
                        )
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .frame(minWidth: 460, minHeight: 380)
        .onAppear {
            if let debt {
                name = debt.name
                balance = debt.balance
                rate = debt.annualRate
                minimum = debt.minimumPayment
            }
        }
    }

    private var isValid: Bool {
        (balance ?? 0) > 0 && (rate ?? -1) >= 0 && (minimum ?? -1) >= 0
    }
}

#Preview {
    DebtPayoffCalculatorView()
        .environment(MainViewModel())
        .modelContainer(for: DebtPayoffCalculation.self, inMemory: true)
        .frame(width: 1200, height: 860)
}
