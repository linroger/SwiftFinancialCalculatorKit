//
//  CommandPaletteView.swift
//  FinancialCalculatorKit
//
//  ⌘K palette for jumping to any calculator or app action without leaving the
//  keyboard. Matches on name, category, and description, so "amortization" or
//  "greeks" finds the right tool even when the calculator is not named that.
//

import SwiftUI
import SwiftData

/// One selectable row in the palette.
struct PaletteCommand: Identifiable {
    enum Action {
        case openCalculator(CalculationType)
        case openSaved(id: UUID, type: CalculationType)
        case showDashboard
        case newCalculation
        case compareScenarios
        case preferences
        case help
        case toggleFavorites
    }

    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
    /// Extra words that should match this command without being displayed
    let keywords: String
    let action: Action

    /// Filter and rank commands for a query. Every whitespace-separated term
    /// must appear somewhere in the title, subtitle, or keywords, so adding
    /// words narrows the list. Title matches outrank description matches.
    static func matching(_ query: String, in commands: [PaletteCommand]) -> [PaletteCommand] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return commands }

        let terms = trimmed.lowercased().split(separator: " ").map(String.init)
        guard let leadTerm = terms.first else { return commands }

        return commands
            .compactMap { command -> (PaletteCommand, Int)? in
                let haystack = "\(command.title) \(command.subtitle) \(command.keywords)".lowercased()
                guard terms.allSatisfy({ haystack.contains($0) }) else { return nil }

                let title = command.title.lowercased()
                let score: Int
                if title.hasPrefix(leadTerm) {
                    score = 0
                } else if title.contains(leadTerm) {
                    score = 1
                } else {
                    score = 2
                }
                return (command, score)
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    /// Terms users actually search for that do not appear in a calculator's name.
    static func keywords(for type: CalculationType) -> String {
        switch type {
        case .timeValue: return "pv fv pmt annuity compound discount rate"
        case .loan: return "amortization schedule payment refinance interest"
        case .mortgage: return "home house loan amortization escrow refinance"
        case .debtPayoff: return "avalanche snowball credit card loan debt payoff strategy"
        case .retirement: return "401k ira nest egg withdrawal monte carlo savings"
        case .bond: return "ytm yield duration convexity coupon par"
        case .investment: return "npv irr mirr payback cash flow capital budgeting"
        case .options: return "black scholes greeks delta gamma theta vega call put"
        case .mathExpression: return "formula evaluate variables parser"
        case .depreciation: return "macrs straight line declining balance asset"
        case .currency: return "exchange rate fx convert forex"
        case .conversion: return "units metric imperial length mass temperature"
        }
    }

    /// Every calculator as a palette command.
    static func calculatorCommands() -> [PaletteCommand] {
        CalculationType.allCases.map { type in
            PaletteCommand(
                title: type.displayName,
                subtitle: type.description,
                systemImage: type.systemImage,
                keywords: "\(type.category.rawValue) \(keywords(for: type))",
                action: .openCalculator(type)
            )
        }
    }
}

struct CommandPaletteView: View {
    @Environment(MainViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \TimeValueCalculation.lastModified, order: .reverse) private var timeValues: [TimeValueCalculation]
    @Query(sort: \LoanCalculation.lastModified, order: .reverse) private var loans: [LoanCalculation]
    @Query(sort: \BondCalculation.lastModified, order: .reverse) private var bonds: [BondCalculation]
    @Query(sort: \InvestmentCalculation.lastModified, order: .reverse) private var investments: [InvestmentCalculation]
    @Query(sort: \OptionsCalculation.lastModified, order: .reverse) private var options: [OptionsCalculation]
    @Query(sort: \DepreciationCalculation.lastModified, order: .reverse) private var depreciations: [DepreciationCalculation]
    @Query(sort: \MathExpressionCalculation.lastModified, order: .reverse) private var expressions: [MathExpressionCalculation]
    @Query(sort: \RetirementPlanCalculation.lastModified, order: .reverse) private var retirementPlans: [RetirementPlanCalculation]
    @Query(sort: \DebtPayoffCalculation.lastModified, order: .reverse) private var debtPlans: [DebtPayoffCalculation]
    @Query(sort: \CurrencyConversionCalculation.lastModified, order: .reverse) private var currencyConversions: [CurrencyConversionCalculation]
    @Query(sort: \UnitConversionCalculation.lastModified, order: .reverse) private var unitConversions: [UnitConversionCalculation]

    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            resultList
        }
        .frame(width: 620, height: 420)
        .background(.regularMaterial)
        .onAppear { searchFocused = true }
        .onChange(of: query) { _, _ in selectedIndex = 0 }
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.title3)

            TextField("Jump to a calculator or action…", text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($searchFocused)
                .onSubmit(activateSelection)
                .onKeyPress(.downArrow) {
                    moveSelection(by: 1)
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    moveSelection(by: -1)
                    return .handled
                }
                .onKeyPress(.escape) {
                    dismiss()
                    return .handled
                }

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Results

    @ViewBuilder
    private var resultList: some View {
        if matches.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("Nothing matches “\(query)”")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(matches.enumerated()), id: \.element.id) { index, command in
                            PaletteRow(
                                command: command,
                                isSelected: index == selectedIndex
                            )
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedIndex = index
                                activateSelection()
                            }
                        }
                    }
                    .padding(8)
                }
                .onChange(of: selectedIndex) { _, newValue in
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Commands

    private var allCommands: [PaletteCommand] {
        var commands: [PaletteCommand] = [
            PaletteCommand(
                title: "Dashboard",
                subtitle: "Overview, statistics, and recent activity",
                systemImage: "square.grid.2x2",
                keywords: "home overview start",
                action: .showDashboard
            ),
            PaletteCommand(
                title: "New Calculation",
                subtitle: "Pick a calculator to start from",
                systemImage: "plus.circle",
                keywords: "create add",
                action: .newCalculation
            ),
            PaletteCommand(
                title: "Compare Scenarios",
                subtitle: "Put saved calculations side by side",
                systemImage: "square.on.square",
                keywords: "diff versus side by side scenarios",
                action: .compareScenarios
            )
        ]

        commands += PaletteCommand.calculatorCommands()

        commands += [
            PaletteCommand(
                title: viewModel.showFavoritesOnly ? "Show All Calculations" : "Show Favorites Only",
                subtitle: "Filter the sidebar list",
                systemImage: "heart",
                keywords: "filter starred",
                action: .toggleFavorites
            ),
            PaletteCommand(
                title: "Preferences",
                subtitle: "Currency, payment frequency, and number formatting",
                systemImage: "gear",
                keywords: "settings options config",
                action: .preferences
            ),
            PaletteCommand(
                title: "Help",
                subtitle: "Documentation and keyboard shortcuts",
                systemImage: "questionmark.circle",
                keywords: "docs guide manual",
                action: .help
            )
        ]

        return commands
    }

    /// Saved records, offered only once the user types — the full list would
    /// bury the calculators when the palette first opens.
    private var savedCommands: [PaletteCommand] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        func commands<T>(_ items: [T], _ type: CalculationType, name: (T) -> String, id: (T) -> UUID) -> [PaletteCommand] {
            items.prefix(20).map { item in
                PaletteCommand(
                    title: name(item),
                    subtitle: "Saved · \(type.displayName)",
                    systemImage: type.systemImage,
                    keywords: "saved \(type.displayName)",
                    action: .openSaved(id: id(item), type: type)
                )
            }
        }

        return commands(timeValues, .timeValue, name: \.name, id: \.id)
            + commands(loans, .loan, name: \.name, id: \.id)
            + commands(bonds, .bond, name: \.name, id: \.id)
            + commands(investments, .investment, name: \.name, id: \.id)
            + commands(options, .options, name: \.name, id: \.id)
            + commands(depreciations, .depreciation, name: \.name, id: \.id)
            + commands(expressions, .mathExpression, name: \.name, id: \.id)
            + commands(retirementPlans, .retirement, name: \.name, id: \.id)
            + commands(debtPlans, .debtPayoff, name: \.name, id: \.id)
            + commands(currencyConversions, .currency, name: \.name, id: \.id)
            + commands(unitConversions, .conversion, name: \.name, id: \.id)
    }

    private var matches: [PaletteCommand] {
        // Calculators rank first; saved records follow, so typing a calculator
        // name never buries it under similarly-named saved work
        PaletteCommand.matching(query, in: allCommands)
            + PaletteCommand.matching(query, in: savedCommands)
    }

    // MARK: - Interaction

    private func moveSelection(by offset: Int) {
        guard !matches.isEmpty else { return }
        selectedIndex = (selectedIndex + offset + matches.count) % matches.count
    }

    private func activateSelection() {
        guard matches.indices.contains(selectedIndex) else { return }
        let command = matches[selectedIndex]
        dismiss()

        switch command.action {
        case .openCalculator(let type):
            viewModel.openCalculator(type)
        case .openSaved(let id, let type):
            viewModel.openSavedCalculation(id: id, type: type)
        case .showDashboard:
            viewModel.showDashboard()
        case .newCalculation:
            viewModel.createNewCalculation(type: viewModel.selectedCalculationType)
        case .compareScenarios:
            viewModel.showScenarioComparison()
        case .preferences:
            viewModel.showPreferences()
        case .help:
            viewModel.showHelp()
        case .toggleFavorites:
            viewModel.showFavoritesOnly.toggle()
        }
    }
}

private struct PaletteRow: View {
    let command: PaletteCommand
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: command.systemImage)
                .font(.body)
                .foregroundColor(isSelected ? .white : .accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(command.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)

                Text(command.subtitle)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isSelected {
                Text("⏎")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
    }
}

#Preview {
    CommandPaletteView()
        .environment(MainViewModel())
}
