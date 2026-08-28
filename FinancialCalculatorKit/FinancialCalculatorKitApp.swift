//
//  FinancialCalculatorKitApp.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import SwiftUI
import SwiftData

@main
struct FinancialCalculatorKitApp: App {
    let sharedModelContainer: ModelContainer

    /// Owned here so the menu bar can drive navigation with real shortcuts.
    @State private var viewModel = MainViewModel()

    init() {
        // Register custom transformers BEFORE creating the ModelContainer
        ValueTransformer.setValueTransformer(
            CashFlowsTransformer(),
            forName: NSValueTransformerName("CashFlowsTransformer")
        )
        
        ValueTransformer.setValueTransformer(
            StringDoubleMapTransformer(),
            forName: NSValueTransformerName("StringDoubleMapTransformer")
        )

        // Now create the ModelContainer
        let schema = Schema([
            FinancialCalculation.self,
            TimeValueCalculation.self,
            LoanCalculation.self,
            BondCalculation.self,
            InvestmentCalculation.self,
            DepreciationCalculation.self,
            OptionsCalculation.self,
            MathExpressionCalculation.self,
            CurrencyConversionCalculation.self,
            RetirementPlanCalculation.self,
            DebtPayoffCalculation.self,
            UnitConversionCalculation.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            sharedModelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
        .modelContainer(sharedModelContainer)
        .windowResizability(.contentSize)
        .commands {
            CalculatorCommands(viewModel: viewModel)
        }
    }
}

/// Menu-bar commands. Every calculator gets a real keyboard shortcut, and the
/// Help menu points at the in-app documentation.
struct CalculatorCommands: Commands {
    @Bindable var viewModel: MainViewModel

    /// The first nine calculators, in sidebar order, get ⌘1…⌘9.
    private var shortcutTargets: [(type: CalculationType, key: KeyEquivalent)] {
        let keys: [KeyEquivalent] = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
        return zip(CalculationType.allCases, keys).map { ($0, $1) }
    }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Calculation") {
                viewModel.createNewCalculation(type: viewModel.selectedCalculationType)
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandMenu("Calculators") {
            Button("Quick Open…") {
                viewModel.showCommandPalette()
            }
            .keyboardShortcut("k", modifiers: .command)

            Button("Compare Scenarios…") {
                viewModel.showScenarioComparison()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])

            Button("Dashboard") {
                viewModel.showDashboard()
            }
            .keyboardShortcut("0", modifiers: .command)

            Divider()

            ForEach(shortcutTargets, id: \.type) { target in
                Button(target.type.displayName) {
                    viewModel.openCalculator(target.type)
                }
                .keyboardShortcut(target.key, modifiers: .command)
            }

            // Anything past ⌘9 stays reachable, just without a shortcut
            let remaining = CalculationType.allCases.dropFirst(shortcutTargets.count)
            if !remaining.isEmpty {
                Divider()
                ForEach(Array(remaining), id: \.self) { type in
                    Button(type.displayName) {
                        viewModel.openCalculator(type)
                    }
                }
            }

            Divider()

            Toggle("Show Favorites Only", isOn: $viewModel.showFavoritesOnly)
                .keyboardShortcut("f", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .help) {
            Button("FinancialCalculatorKit Help") {
                viewModel.showHelp()
            }
            .keyboardShortcut("/", modifiers: [.command, .shift])
        }
    }
}
