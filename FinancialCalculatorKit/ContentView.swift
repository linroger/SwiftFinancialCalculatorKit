//
//  ContentView.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    /// Owned by the app so menu-bar commands can drive the same navigation state.
    @Bindable var viewModel: MainViewModel

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
        } detail: {
            DetailView()
                .environment(viewModel)
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(item: $viewModel.presentedSheet) { sheet in
            switch sheet {
            case .calculatorPicker:
                CalculationSheetView()
                    .environment(viewModel)
            case .preferences:
                PreferencesView(viewModel: viewModel)
            case .help:
                HelpView()
            case .commandPalette:
                CommandPaletteView()
                    .environment(viewModel)
            }
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.currentError {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error.localizedDescription)
                    if let suggestion = error.recoverySuggestion {
                        Text(suggestion)
                            .font(.caption)
                    }
                }
            }
        }
    }
}

struct SidebarView: View {
    @Bindable var viewModel: MainViewModel
    @Environment(\.modelContext) private var modelContext

    // Queries for all calculation types
    @Query(sort: \TimeValueCalculation.lastModified, order: .reverse) private var timeValueCalculations: [TimeValueCalculation]
    @Query(sort: \LoanCalculation.lastModified, order: .reverse) private var loanCalculations: [LoanCalculation]
    @Query(sort: \InvestmentCalculation.lastModified, order: .reverse) private var investmentCalculations: [InvestmentCalculation]
    @Query(sort: \BondCalculation.lastModified, order: .reverse) private var bondCalculations: [BondCalculation]
    @Query(sort: \OptionsCalculation.lastModified, order: .reverse) private var optionsCalculations: [OptionsCalculation]
    @Query(sort: \MathExpressionCalculation.lastModified, order: .reverse) private var mathCalculations: [MathExpressionCalculation]
    @Query(sort: \DepreciationCalculation.lastModified, order: .reverse) private var depreciationCalculations: [DepreciationCalculation]
    @Query(sort: \CurrencyConversionCalculation.lastModified, order: .reverse) private var currencyCalculations: [CurrencyConversionCalculation]
    @Query(sort: \RetirementPlanCalculation.lastModified, order: .reverse) private var retirementCalculations: [RetirementPlanCalculation]
    @Query(sort: \DebtPayoffCalculation.lastModified, order: .reverse) private var debtPayoffCalculations: [DebtPayoffCalculation]
    @Query(sort: \UnitConversionCalculation.lastModified, order: .reverse) private var unitCalculations: [UnitConversionCalculation]

    // Legacy support
    @Query private var legacyCalculations: [FinancialCalculation]
    
    var body: some View {
        List(selection: $viewModel.selectedCalculationType) {
            // Dashboard Link
            NavigationLink(value: Optional<CalculationType>.none) {
                Label("Dashboard", systemImage: "square.grid.2x2")
            }
            .tag(Optional<CalculationType>.none)

            ForEach(CalculationCategory.allCases) { category in
                Section(category.rawValue) {
                    ForEach(CalculationType.allCases.filter { $0.category == category }) { type in
                        NavigationLink(value: type) {
                            Label(type.displayName, systemImage: type.systemImage)
                        }
                        .tag(type)
                    }
                }
            }
            
            Section("Recent Calculations") {
                ForEach(allRecentCalculations) { item in
                    RecentCalculationRowView(item: item)
                        .environment(viewModel)
                        .contextMenu {
                            Button(item.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                   systemImage: item.isFavorite ? "heart.slash" : "heart") {
                                toggleFavorite(item)
                            }
                            Divider()
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                delete(item)
                            }
                        }
                }
                .onDelete(perform: deleteCalculations)
            }
        }
        .navigationTitle("Financial Kit")
        .navigationSplitViewColumnWidth(min: 250, ideal: 280)
        .searchable(text: $viewModel.searchText, prompt: "Search...")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { viewModel.createNewCalculation(type: viewModel.selectedCalculationType) }) {
                    Image(systemName: "plus")
                }
                .help("New calculation")
                .keyboardShortcut("n")
                .accessibilityLabel("New Calculation")
                .accessibilityIdentifier("toolbar.newCalculation")

                Button(action: { viewModel.showFavoritesOnly.toggle() }) {
                    Image(systemName: viewModel.showFavoritesOnly ? "heart.fill" : "heart")
                }
                .help(viewModel.showFavoritesOnly ? "Show all calculations" : "Show favorites only")
                .accessibilityLabel("Toggle Favorites Filter")
                .accessibilityIdentifier("toolbar.favoritesFilter")
            }
            
            ToolbarItemGroup(placement: .secondaryAction) {
                Button(action: viewModel.showPreferences) {
                    Image(systemName: "gear")
                }
                .help("Preferences")
                .keyboardShortcut(",", modifiers: .command)
                .accessibilityLabel("Preferences")
                .accessibilityIdentifier("toolbar.preferences")
                
                Button(action: viewModel.showHelp) {
                    Image(systemName: "questionmark.circle")
                }
                .help("Help")
                .keyboardShortcut("/", modifiers: [.command, .shift])
                .accessibilityLabel("Help")
                .accessibilityIdentifier("toolbar.help")
            }
        }
    }
    
    private var allRecentCalculations: [RecentCalculationItem] {
        var items: [RecentCalculationItem] = []
        
        for calc in timeValueCalculations.prefix(3) {
            items.append(RecentCalculationItem(
                id: calc.id,
                name: calc.name,
                calculationType: .timeValue,
                lastModified: calc.lastModified,
                isFavorite: calc.isFavorite
            ))
        }
        
        for calc in loanCalculations.prefix(3) {
            items.append(RecentCalculationItem(
                id: calc.id,
                name: calc.name,
                calculationType: .loan,
                lastModified: calc.lastModified,
                isFavorite: calc.isFavorite
            ))
        }
        
        for calc in investmentCalculations.prefix(3) {
            items.append(RecentCalculationItem(
                id: calc.id,
                name: calc.name,
                calculationType: .investment,
                lastModified: calc.lastModified,
                isFavorite: calc.isFavorite
            ))
        }
        
        for calc in bondCalculations.prefix(2) {
            items.append(RecentCalculationItem(
                id: calc.id,
                name: calc.name,
                calculationType: .bond,
                lastModified: calc.lastModified,
                isFavorite: calc.isFavorite
            ))
        }
        
        for calc in optionsCalculations.prefix(2) {
            items.append(RecentCalculationItem(
                id: calc.id,
                name: calc.name,
                calculationType: .options,
                lastModified: calc.lastModified,
                isFavorite: calc.isFavorite
            ))
        }
        
        for calc in mathCalculations.prefix(2) {
            items.append(RecentCalculationItem(
                id: calc.id,
                name: calc.name,
                calculationType: .mathExpression,
                lastModified: calc.lastModified,
                isFavorite: calc.isFavorite
            ))
        }
        
        for calc in depreciationCalculations.prefix(2) {
            items.append(RecentCalculationItem(
                id: calc.id,
                name: calc.name,
                calculationType: .depreciation,
                lastModified: calc.lastModified,
                isFavorite: calc.isFavorite
            ))
        }

        for calc in currencyCalculations.prefix(2) {
            items.append(RecentCalculationItem(
                id: calc.id,
                name: calc.name,
                calculationType: .currency,
                lastModified: calc.lastModified,
                isFavorite: calc.isFavorite
            ))
        }

        for calc in retirementCalculations.prefix(3) {
            items.append(RecentCalculationItem(
                id: calc.id,
                name: calc.name,
                calculationType: .retirement,
                lastModified: calc.lastModified,
                isFavorite: calc.isFavorite
            ))
        }

        for calc in debtPayoffCalculations.prefix(3) {
            items.append(RecentCalculationItem(
                id: calc.id,
                name: calc.name,
                calculationType: .debtPayoff,
                lastModified: calc.lastModified,
                isFavorite: calc.isFavorite
            ))
        }

        for calc in unitCalculations.prefix(2) {
            items.append(RecentCalculationItem(
                id: calc.id,
                name: calc.name,
                calculationType: .conversion,
                lastModified: calc.lastModified,
                isFavorite: calc.isFavorite
            ))
        }

        // Filter by search text if needed
        var filtered = items
        if !viewModel.searchText.isEmpty {
            filtered = items.filter { $0.name.localizedCaseInsensitiveContains(viewModel.searchText) }
        }
        
        // Filter by favorites if needed
        if viewModel.showFavoritesOnly {
            filtered = filtered.filter { $0.isFavorite }
        }
        
        // Sort by last modified and return top 10
        return filtered
            .sorted { $0.lastModified > $1.lastModified }
            .prefix(10)
            .map { $0 }
    }
    
    private func deleteCalculations(offsets: IndexSet) {
        let items = allRecentCalculations
        for index in offsets where items.indices.contains(index) {
            delete(items[index])
        }
    }

    /// Delete the underlying SwiftData model backing a recent-calculation row.
    private func delete(_ item: RecentCalculationItem) {
        switch item.calculationType {
        case .timeValue:
            if let calc = timeValueCalculations.first(where: { $0.id == item.id }) {
                modelContext.delete(calc)
            }
        case .loan, .mortgage:
            if let calc = loanCalculations.first(where: { $0.id == item.id }) {
                modelContext.delete(calc)
            }
        case .investment:
            if let calc = investmentCalculations.first(where: { $0.id == item.id }) {
                modelContext.delete(calc)
            }
        case .bond:
            if let calc = bondCalculations.first(where: { $0.id == item.id }) {
                modelContext.delete(calc)
            }
        case .options:
            if let calc = optionsCalculations.first(where: { $0.id == item.id }) {
                modelContext.delete(calc)
            }
        case .mathExpression:
            if let calc = mathCalculations.first(where: { $0.id == item.id }) {
                modelContext.delete(calc)
            }
        case .depreciation:
            if let calc = depreciationCalculations.first(where: { $0.id == item.id }) {
                modelContext.delete(calc)
            }
        case .currency:
            if let calc = currencyCalculations.first(where: { $0.id == item.id }) {
                modelContext.delete(calc)
            }
        case .retirement:
            if let calc = retirementCalculations.first(where: { $0.id == item.id }) {
                modelContext.delete(calc)
            }
        case .debtPayoff:
            if let calc = debtPayoffCalculations.first(where: { $0.id == item.id }) {
                modelContext.delete(calc)
            }
        case .conversion:
            if let calc = unitCalculations.first(where: { $0.id == item.id }) {
                modelContext.delete(calc)
            }
        }
        try? modelContext.save()
    }

    /// Toggle the favorite flag on the underlying SwiftData model.
    private func toggleFavorite(_ item: RecentCalculationItem) {
        switch item.calculationType {
        case .timeValue:
            timeValueCalculations.first(where: { $0.id == item.id })?.toggleFavorite()
        case .loan, .mortgage:
            loanCalculations.first(where: { $0.id == item.id })?.toggleFavorite()
        case .investment:
            investmentCalculations.first(where: { $0.id == item.id })?.toggleFavorite()
        case .bond:
            bondCalculations.first(where: { $0.id == item.id })?.toggleFavorite()
        case .options:
            optionsCalculations.first(where: { $0.id == item.id })?.toggleFavorite()
        case .mathExpression:
            mathCalculations.first(where: { $0.id == item.id })?.toggleFavorite()
        case .depreciation:
            depreciationCalculations.first(where: { $0.id == item.id })?.toggleFavorite()
        case .currency:
            currencyCalculations.first(where: { $0.id == item.id })?.toggleFavorite()
        case .retirement:
            retirementCalculations.first(where: { $0.id == item.id })?.toggleFavorite()
        case .debtPayoff:
            debtPayoffCalculations.first(where: { $0.id == item.id })?.toggleFavorite()
        case .conversion:
            unitCalculations.first(where: { $0.id == item.id })?.toggleFavorite()
        }
        try? modelContext.save()
    }
}

/// Simple item for displaying recent calculations in the sidebar
struct RecentCalculationItem: Identifiable {
    let id: UUID
    let name: String
    let calculationType: CalculationType
    let lastModified: Date
    let isFavorite: Bool
}

struct RecentCalculationRowView: View {
    let item: RecentCalculationItem
    @Environment(MainViewModel.self) private var viewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if item.isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Text(item.calculationType.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(item.lastModified, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: open) {
                Image(systemName: "arrow.right.circle")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Open this saved calculation")
            .accessibilityLabel("Open \(item.name)")
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
    }

    private func open() {
        viewModel.openSavedCalculation(id: item.id, type: item.calculationType)
    }
}

struct DetailView: View {
    @Environment(MainViewModel.self) private var viewModel
    
    var body: some View {
        Group {
            if let type = viewModel.selectedCalculationType {
                switch type {
                case .timeValue:
                    TimeValueCalculatorView()
                case .loan, .mortgage:
                    LoanCalculatorView()
                case .debtPayoff:
                    DebtPayoffCalculatorView()
                case .retirement:
                    RetirementPlannerView()
                case .bond:
                    BondCalculatorView()
                case .investment:
                    InvestmentCalculatorView()
                case .options:
                    OptionsCalculatorView()
                case .mathExpression:
                    MathExpressionCalculatorView()
                case .depreciation:
                    DepreciationCalculatorView()
                case .currency:
                    CurrencyConverterView()
                case .conversion:
                    UnitConverterView()
                }
            } else {
                DashboardView()
            }
        }
        .navigationTitle(viewModel.selectedCalculationType?.displayName ?? "Dashboard")
        .frame(minWidth: 600, minHeight: 400)
    }
}

struct CalculationSheetView: View {
    @Environment(MainViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with type selection
                VStack(spacing: 16) {
                    Image(systemName: viewModel.selectedCalculationType?.systemImage ?? "plus.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                    
                    Text("New Calculation")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Select a calculator type to get started")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 24)
                
                Divider()
                
                // Calculator type grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(CalculationType.allCases) { type in
                            CalculatorTypeCard(
                                type: type,
                                isSelected: viewModel.selectedCalculationType == type,
                                action: {
                                    viewModel.openCalculator(type)
                                    viewModel.dismissSheet()
                                    dismiss()
                                }
                            )
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("New Calculation")
            .accessibilityIdentifier("sheet.newCalculation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.dismissSheet()
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}

struct CalculatorTypeCard: View {
    let type: CalculationType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: type.systemImage)
                    .font(.system(size: 32))
                    .foregroundColor(isSelected ? .white : .accentColor)
                
                Text(type.displayName)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(type.description)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color(NSColor.separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct PreferencesView: View {
    @Bindable var viewModel: MainViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Defaults for New Calculations") {
                    Picker("Default Currency", selection: $viewModel.userPreferences.defaultCurrency) {
                        ForEach(Currency.allCases) { currency in
                            Text("\(currency.displayName) (\(currency.symbol))")
                                .tag(currency)
                        }
                    }

                    Picker("Default Payment Frequency", selection: $viewModel.userPreferences.defaultPaymentFrequency) {
                        ForEach(PaymentFrequency.allCases) { frequency in
                            Text(frequency.displayName)
                                .tag(frequency)
                        }
                    }
                }

                Section {
                    Stepper("Decimal Places: \(viewModel.userPreferences.decimalPlaces)",
                           value: $viewModel.userPreferences.decimalPlaces,
                           in: 0...6)

                    Toggle("Use Thousands Separator",
                           isOn: $viewModel.userPreferences.useThousandsSeparator)
                } header: {
                    Text("Number Formatting")
                } footer: {
                    Text("Applies to all displayed currency amounts.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Preferences")
            .accessibilityIdentifier("sheet.preferences")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        viewModel.saveUserPreferences()
                        viewModel.dismissSheet()
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: HelpSectionType = .gettingStarted
    
    var body: some View {
        NavigationStack {
            HSplitView {
                // Sidebar
                List(HelpSectionType.allCases, selection: $selectedSection) { section in
                    Label(section.title, systemImage: section.icon)
                        .tag(section)
                }
                .listStyle(.sidebar)
                .frame(minWidth: 180, maxWidth: 220)
                
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        HStack {
                            Image(systemName: selectedSection.icon)
                                .font(.largeTitle)
                                .foregroundColor(.accentColor)
                            
                            VStack(alignment: .leading) {
                                Text(selectedSection.title)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                
                                Text(selectedSection.subtitle)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.bottom)
                        
                        // Content based on selection
                        selectedSection.content
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle("Help & Documentation")
            .accessibilityIdentifier("sheet.help")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}

enum HelpSectionType: String, CaseIterable, Identifiable {
    case gettingStarted
    case calculators
    case features
    case shortcuts
    case about
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .gettingStarted: return "Getting Started"
        case .calculators: return "Calculators"
        case .features: return "Features"
        case .shortcuts: return "Keyboard Shortcuts"
        case .about: return "About"
        }
    }
    
    var subtitle: String {
        switch self {
        case .gettingStarted: return "Learn the basics of FinancialCalculatorKit"
        case .calculators: return "Explore all available calculator types"
        case .features: return "Discover powerful features"
        case .shortcuts: return "Speed up your workflow"
        case .about: return "About this application"
        }
    }
    
    var icon: String {
        switch self {
        case .gettingStarted: return "graduationcap"
        case .calculators: return "function"
        case .features: return "star"
        case .shortcuts: return "keyboard"
        case .about: return "info.circle"
        }
    }
    
    @ViewBuilder
    var content: some View {
        switch self {
        case .gettingStarted:
            GettingStartedContent()
        case .calculators:
            CalculatorsHelpContent()
        case .features:
            FeaturesHelpContent()
        case .shortcuts:
            ShortcutsHelpContent()
        case .about:
            AboutHelpContent()
        }
    }
}

struct GettingStartedContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpStepView(
                number: 1,
                title: "Select a Calculator",
                description: "Choose a calculator type from the sidebar. Each calculator is designed for specific financial calculations.",
                icon: "sidebar.left"
            )
            
            HelpStepView(
                number: 2,
                title: "Enter Your Values",
                description: "Fill in the required fields with your financial data. Tooltips and help text guide you through each input.",
                icon: "textformat.123"
            )
            
            HelpStepView(
                number: 3,
                title: "View Results",
                description: "Instantly see calculated results with detailed breakdowns, charts, and explanations.",
                icon: "chart.bar.xaxis"
            )
            
            HelpStepView(
                number: 4,
                title: "Save & Export",
                description: "Save your calculations for future reference or export them in various formats.",
                icon: "square.and.arrow.down"
            )
        }
    }
}

struct HelpStepView: View {
    let number: Int
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 36, height: 36)
                
                Text("\(number)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(.accentColor)
                    Text(title)
                        .font(.headline)
                }
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

struct CalculatorsHelpContent: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(CalculationType.allCases) { type in
                CalculatorHelpCard(type: type)
            }
        }
    }
}

struct CalculatorHelpCard: View {
    let type: CalculationType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: type.systemImage)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text(type.displayName)
                    .font(.headline)
            }
            
            Text(type.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

struct FeaturesHelpContent: View {
    let features = [
        ("chart.line.uptrend.xyaxis", "Interactive Charts", "Visualize your financial data with dynamic charts that respond to input changes."),
        ("dollarsign.circle", "Multi-Currency Support", "Work with 16 currencies including USD, EUR, GBP, JPY, and more."),
        ("square.and.arrow.up", "CSV Export", "Export calculation results and schedules to CSV files."),
        ("clock.arrow.circlepath", "Calculation History", "Access your previous calculations quickly from the sidebar."),
        ("heart", "Favorites", "Mark frequently used calculations as favorites for quick access."),
        ("magnifyingglass", "Search", "Quickly find calculations using the search feature."),
        ("paintbrush", "Customizable", "Adjust decimal places, date formats, and default currencies."),
        ("keyboard", "Keyboard Shortcuts", "Speed up your workflow with convenient keyboard shortcuts.")
    ]
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(features, id: \.1) { feature in
                FeatureCard(icon: feature.0, title: feature.1, description: feature.2)
            }
        }
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

struct ShortcutsHelpContent: View {
    let shortcuts = [
        ("⌘ K", "Quick Open — jump to any calculator"),
        ("⌘ N", "New Calculation"),
        ("⌘ 0", "Go to Dashboard"),
        ("⌘ 1–9", "Jump to a calculator (Calculators menu)"),
        ("⌘ ⇧ F", "Show favorites only"),
        ("⌘ ,", "Preferences"),
        ("⌘ ⇧ /", "Help"),
        ("⌘ W", "Close Window"),
        ("⌘ Q", "Quit")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(shortcuts, id: \.0) { shortcut in
                HStack {
                    Text(shortcut.0)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                    
                    Text(shortcut.1)
                        .font(.body)
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }
}

struct AboutHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // App Info
            HStack(spacing: 16) {
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.linearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("FinancialCalculatorKit")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Version 1.0")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text("A comprehensive financial calculation toolkit for macOS")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Features Summary
            VStack(alignment: .leading, spacing: 12) {
                Text("Key Capabilities")
                    .font(.headline)
                
                Text("• Time Value of Money calculations (PV, FV, PMT, Rate, Periods)")
                Text("• Loan and mortgage analysis with amortization schedules")
                Text("• Retirement planning with nest-egg projection and gap analysis")
                Text("• Bond pricing and yield calculations")
                Text("• Investment analysis (NPV, IRR, MIRR)")
                Text("• Black-Scholes options pricing with Greeks")
                Text("• Depreciation calculations (Straight-line, Declining balance, MACRS)")
                Text("• Currency conversion with 16 currencies")
                Text("• Unit conversion for international calculations")
                Text("• Mathematical expression evaluator")
            }
            .font(.body)
            .foregroundColor(.secondary)
            
            Divider()
            
            // Credits
            VStack(alignment: .leading, spacing: 8) {
                Text("Credits")
                    .font(.headline)
                
                Text("Built with SwiftUI, SwiftData, and Swift Charts")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("Uses LaTeXSwiftUI for mathematical formula rendering")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("Uses MathParser for expression evaluation")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }
}

#Preview {
    ContentView(viewModel: MainViewModel())
        .modelContainer(for: FinancialCalculation.self, inMemory: true)
}
