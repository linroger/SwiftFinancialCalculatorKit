//
//  ScenarioComparisonView.swift
//  FinancialCalculatorKit
//
//  Puts saved calculations of the same type side by side. Deliberately reports
//  differences against a baseline rather than declaring a winner — whether a
//  bigger number is better depends on the metric, and the app should not guess.
//

import SwiftUI
import SwiftData

/// A saved calculation flattened into something comparable, regardless of type.
struct ComparisonRecord: Identifiable, Equatable {
    let id: UUID
    let name: String
    let type: CalculationType
    let lastModified: Date
    let currency: Currency
    let primaryLabel: String
    let formattedPrimary: String
    let primaryValue: Double
    let secondaryValues: [String: Double]

    static func == (lhs: ComparisonRecord, rhs: ComparisonRecord) -> Bool {
        lhs.id == rhs.id
    }
}

struct ScenarioComparisonView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \TimeValueCalculation.lastModified, order: .reverse) private var timeValues: [TimeValueCalculation]
    @Query(sort: \LoanCalculation.lastModified, order: .reverse) private var loans: [LoanCalculation]
    @Query(sort: \BondCalculation.lastModified, order: .reverse) private var bonds: [BondCalculation]
    @Query(sort: \InvestmentCalculation.lastModified, order: .reverse) private var investments: [InvestmentCalculation]
    @Query(sort: \OptionsCalculation.lastModified, order: .reverse) private var options: [OptionsCalculation]
    @Query(sort: \DepreciationCalculation.lastModified, order: .reverse) private var depreciations: [DepreciationCalculation]
    @Query(sort: \RetirementPlanCalculation.lastModified, order: .reverse) private var retirementPlans: [RetirementPlanCalculation]
    @Query(sort: \DebtPayoffCalculation.lastModified, order: .reverse) private var debtPlans: [DebtPayoffCalculation]

    @State private var selectedType: CalculationType?
    @State private var selectedIDs: Set<UUID> = []

    /// Comparing more than this many columns stops being readable.
    private let maxSelections = 4

    var body: some View {
        NavigationStack {
            Group {
                if comparableTypes.isEmpty {
                    emptyState
                } else {
                    HSplitView {
                        pickerColumn
                            .frame(minWidth: 260, idealWidth: 300, maxWidth: 340)
                        comparisonColumn
                            .frame(minWidth: 480)
                    }
                }
            }
            .navigationTitle("Compare Scenarios")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 900, minHeight: 620)
        .onAppear {
            if selectedType == nil {
                selectedType = comparableTypes.first
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text("Nothing to compare yet")
                .font(.headline)

            Text("Save at least two calculations of the same kind — two loan scenarios, two retirement plans — and they will appear here side by side.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Picker

    private var pickerColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("Calculator", selection: $selectedType) {
                ForEach(comparableTypes, id: \.self) { type in
                    Text(type.displayName).tag(Optional(type))
                }
            }
            .pickerStyle(.menu)
            .padding(12)
            .onChange(of: selectedType) { _, _ in
                selectedIDs = []
            }

            Divider()

            List {
                ForEach(recordsForSelectedType) { record in
                    Toggle(isOn: binding(for: record.id)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.name)
                                .font(.body)
                            Text("\(record.formattedPrimary) · \(record.lastModified.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }

            Divider()

            Text(selectedIDs.count >= maxSelections
                 ? "Showing \(maxSelections) scenarios — deselect one to add another."
                 : "Select up to \(maxSelections) to compare.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(12)
        }
    }

    private func binding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { selectedIDs.contains(id) },
            set: { isOn in
                if isOn {
                    guard selectedIDs.count < maxSelections else { return }
                    selectedIDs.insert(id)
                } else {
                    selectedIDs.remove(id)
                }
            }
        )
    }

    // MARK: - Comparison

    @ViewBuilder
    private var comparisonColumn: some View {
        if selectedRecords.count < 2 {
            VStack(spacing: 12) {
                Image(systemName: "arrow.left")
                    .font(.title)
                    .foregroundColor(.secondary.opacity(0.6))
                Text("Pick two or more scenarios to compare")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 0) {
                    headerRow
                    Divider()
                    primaryRow
                    Divider()

                    ForEach(comparisonKeys, id: \.self) { key in
                        metricRow(key)
                        Divider()
                    }

                    baselineNote
                }
                .padding(16)
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("Metric")
                .font(.headline)
                .frame(width: 220, alignment: .leading)

            ForEach(Array(selectedRecords.enumerated()), id: \.element.id) { index, record in
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(index == 0 ? "Baseline" : "vs baseline")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 180, alignment: .leading)
            }
        }
        .padding(.vertical, 10)
    }

    private var primaryRow: some View {
        HStack(spacing: 0) {
            Text(selectedRecords.first?.primaryLabel ?? "Result")
                .font(.body)
                .fontWeight(.semibold)
                .frame(width: 220, alignment: .leading)

            ForEach(Array(selectedRecords.enumerated()), id: \.element.id) { index, record in
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.formattedPrimary)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)

                    if index > 0, let baseline = selectedRecords.first {
                        Text(deltaText(
                            key: record.primaryLabel,
                            value: record.primaryValue,
                            baseline: baseline.primaryValue,
                            currency: record.currency
                        ))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                }
                .frame(width: 180, alignment: .leading)
            }
        }
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.06))
    }

    private func metricRow(_ key: String) -> some View {
        HStack(spacing: 0) {
            Text(key)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 220, alignment: .leading)

            ForEach(Array(selectedRecords.enumerated()), id: \.element.id) { index, record in
                VStack(alignment: .leading, spacing: 2) {
                    if let value = record.secondaryValues[key] {
                        Text(SecondaryValueFormatter.format(key: key, value: value, currency: record.currency))
                            .font(.system(.body, design: .monospaced))

                        if index > 0,
                           let baseline = selectedRecords.first?.secondaryValues[key] {
                            Text(deltaText(
                                key: key,
                                value: value,
                                baseline: baseline,
                                currency: record.currency
                            ))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                    } else {
                        // A metric one scenario reports and another does not
                        Text("—")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 180, alignment: .leading)
            }
        }
        .padding(.vertical, 8)
    }

    private var baselineNote: some View {
        Text("Differences are measured against the first column. Whether a larger number is better depends on the metric, so no scenario is marked as the winner.")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 14)
            .frame(maxWidth: 560, alignment: .leading)
    }

    private func deltaText(key: String, value: Double, baseline: Double, currency: Currency) -> String {
        SecondaryValueFormatter.formatDelta(key: key, delta: value - baseline, currency: currency)
    }

    // MARK: - Data

    private var allRecords: [ComparisonRecord] {
        func map<T>(
            _ items: [T],
            _ type: CalculationType,
            name: (T) -> String,
            id: (T) -> UUID,
            date: (T) -> Date,
            currency: (T) -> Currency,
            result: (T) -> CalculationResult
        ) -> [ComparisonRecord] {
            items.map { item in
                let calculated = result(item)
                return ComparisonRecord(
                    id: id(item),
                    name: name(item),
                    type: type,
                    lastModified: date(item),
                    currency: currency(item),
                    primaryLabel: "Result",
                    formattedPrimary: calculated.formattedPrimaryValue,
                    primaryValue: calculated.primaryValue,
                    secondaryValues: calculated.secondaryValues
                )
            }
        }

        return map(timeValues, .timeValue, name: \.name, id: \.id, date: \.lastModified, currency: \.currency, result: \.result)
            + map(loans, .loan, name: \.name, id: \.id, date: \.lastModified, currency: \.currency, result: \.result)
            + map(bonds, .bond, name: \.name, id: \.id, date: \.lastModified, currency: \.currency, result: \.result)
            + map(investments, .investment, name: \.name, id: \.id, date: \.lastModified, currency: \.currency, result: \.result)
            + map(options, .options, name: \.name, id: \.id, date: \.lastModified, currency: \.currency, result: \.result)
            + map(depreciations, .depreciation, name: \.name, id: \.id, date: \.lastModified, currency: \.currency, result: \.result)
            + map(retirementPlans, .retirement, name: \.name, id: \.id, date: \.lastModified, currency: \.currency, result: \.result)
            + map(debtPlans, .debtPayoff, name: \.name, id: \.id, date: \.lastModified, currency: \.currency, result: \.result)
    }

    /// Only types with at least two saved records can be compared.
    private var comparableTypes: [CalculationType] {
        let grouped = Dictionary(grouping: allRecords, by: \.type)
        return CalculationType.allCases.filter { (grouped[$0]?.count ?? 0) >= 2 }
    }

    private var recordsForSelectedType: [ComparisonRecord] {
        guard let selectedType else { return [] }
        return allRecords.filter { $0.type == selectedType }
    }

    /// Selected records in the order they appear in the list, so the baseline
    /// column is stable rather than dependent on click order.
    private var selectedRecords: [ComparisonRecord] {
        recordsForSelectedType.filter { selectedIDs.contains($0.id) }
    }

    /// Union of every metric any selected scenario reports.
    private var comparisonKeys: [String] {
        var keys = Set<String>()
        for record in selectedRecords {
            keys.formUnion(record.secondaryValues.keys)
        }
        return keys.sorted()
    }
}

#Preview {
    ScenarioComparisonView()
        .modelContainer(for: LoanCalculation.self, inMemory: true)
}
