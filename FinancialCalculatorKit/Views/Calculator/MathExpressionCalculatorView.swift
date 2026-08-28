//
//  MathExpressionCalculatorView.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/9/25.
//

import SwiftUI
import SwiftData
import LaTeXSwiftUI

/// Advanced mathematical expression calculator with financial functions
struct MathExpressionCalculatorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(MainViewModel.self) private var mainViewModel
    
    @State private var calculation: MathExpressionCalculation?
    @State private var calculationName: String = "My Expression"
    @State private var expression: String = ""
    @State private var result: Double?
    @State private var variables: [String: Double] = [:]
    @State private var history: [ExpressionHistory] = []
    @State private var selectedExample: ExampleExpression?
    @State private var showingVariableEditor: Bool = false
    @State private var errorMessage: String?

    let examples: [ExampleExpression] = [
        ExampleExpression(
            name: "Compound Interest",
            expression: "P * (1 + r)^t",
            description: "Calculate compound interest where P=principal, r=rate, t=time",
            variables: ["P": 1000, "r": 0.05, "t": 10]
        ),
        ExampleExpression(
            name: "Present Value of Annuity",
            expression: "PMT * ((1 - (1 + r)^(-n)) / r)",
            description: "Present value of ordinary annuity",
            variables: ["PMT": 1000, "r": 0.08, "n": 10]
        ),
        ExampleExpression(
            name: "Black-Scholes d1",
            expression: "(ln(S/K) + (r + 0.5*sigma^2)*T) / (sigma*sqrt(T))",
            description: "Black-Scholes d1 parameter",
            variables: ["S": 100, "K": 100, "r": 0.05, "sigma": 0.2, "T": 0.25]
        ),
        ExampleExpression(
            name: "Gordon Growth Model",
            expression: "D / (r - g)",
            description: "Stock value from next dividend D, required return r, growth g",
            variables: ["D": 2.5, "r": 0.08, "g": 0.03]
        ),
        ExampleExpression(
            name: "Sharpe Ratio",
            expression: "(Rp - Rf) / sigma_p",
            description: "Risk-adjusted return measure",
            variables: ["Rp": 0.12, "Rf": 0.03, "sigma_p": 0.15]
        )
    ]
    
    var body: some View {
        HSplitView {
            // Left panel - Expression input and controls
            VStack(spacing: 20) {
                headerSection
                expressionInputSection
                variablesSection
                examplesSection
            }
            .frame(minWidth: 400, maxWidth: 500)
            .padding(20)
            
            // Right panel - Results and history
            VStack(spacing: 20) {
                resultSection
                historySection
            }
            .frame(minWidth: 400)
            .padding(20)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Calculate") {
                    evaluateExpression()
                }
                .buttonStyle(.borderedProminent)
                .disabled(expression.isEmpty)
                .keyboardShortcut(.return, modifiers: [.command])
                
                Button("Save") {
                    saveCalculation()
                }
                .disabled(result == nil || calculationName.isEmpty)
                .help(calculationName.isEmpty ? "Enter a calculation name to save" : "Save this calculation")

                Button("Clear") {
                    clearAll()
                }
                .buttonStyle(.bordered)
                
                Button("Variables") {
                    showingVariableEditor = true
                }
                .buttonStyle(.bordered)
            }
        }
        .sheet(isPresented: $showingVariableEditor) {
            VariableEditorView(variables: $variables)
        }
        .onAppear {
            // Load default variables
            if variables.isEmpty {
                variables = defaultVariables
            }
            restorePendingCalculation()
        }
        .onChange(of: mainViewModel.pendingLoadID) { _, _ in
            restorePendingCalculation()
        }
    }

    /// Restore a saved expression the user opened from the sidebar or dashboard.
    private func restorePendingCalculation() {
        guard let id = mainViewModel.takePendingLoadID(for: .mathExpression) else { return }

        var descriptor = FetchDescriptor<MathExpressionCalculation>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let saved = try? modelContext.fetch(descriptor).first else { return }

        calculationName = saved.name
        expression = saved.expression
        variables = saved.variables
        calculation = saved
        errorMessage = nil

        // Re-evaluate rather than trusting a stored number
        evaluateExpression()
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mathematical Expression Calculator")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Evaluate complex mathematical expressions with financial functions and custom variables")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var expressionInputSection: some View {
        GroupBox("Expression") {
            VStack(spacing: 12) {
                // Name Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.headline)
                    TextField("Calculation Name", text: $calculationName)
                        .textFieldStyle(.roundedBorder)
                }

                // Expression input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mathematical Expression")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    TextField("Enter expression (e.g., P * (1 + r)^t)", text: $expression, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1...5)
                        .onSubmit {
                            evaluateExpression()
                        }
                        .onChange(of: expression) { _, _ in
                            // A changed expression invalidates the displayed result
                            result = nil
                            errorMessage = nil
                        }
                }
                
                // Error display
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.red.opacity(0.1))
                        )
                }
                
                // Function reference
                DisclosureGroup("Available Functions") {
                    VStack(alignment: .leading, spacing: 4) {
                        functionReferenceItem("Trigonometric", "sin, cos, tan, asin, acos, atan")
                        functionReferenceItem("Exponential", "exp, ln, log2, log10, sqrt, cbrt, x^y")
                        functionReferenceItem("Other", "abs, ceil, floor, round, sgn, hypot, atan2")
                        functionReferenceItem("Constants", "pi, e, sqrt2, phi")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(16)
        }
        .groupBoxStyle(FinancialGroupBoxStyle())
    }
    
    @ViewBuilder
    private var variablesSection: some View {
        GroupBox("Variables") {
            VStack(spacing: 12) {
                HStack {
                    Text("Defined Variables")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button("Edit") {
                        showingVariableEditor = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                if variables.isEmpty {
                    Text("No variables defined")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(Array(variables.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                                VStack(spacing: 2) {
                                    Text(key)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text(String(format: "%.4g", value))
                                        .font(.caption2)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }
            }
            .padding(16)
        }
        .groupBoxStyle(FinancialGroupBoxStyle())
    }
    
    @ViewBuilder
    private var examplesSection: some View {
        GroupBox("Example Expressions") {
            VStack(spacing: 12) {
                ForEach(examples) { example in
                    Button(action: {
                        loadExample(example)
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(example.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(example.expression)
                                .font(.caption)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            Text(example.description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .groupBoxStyle(FinancialGroupBoxStyle())
    }
    
    @ViewBuilder
    private var resultSection: some View {
        GroupBox("Result") {
            VStack(spacing: 16) {
                if let result = result {
                    VStack(spacing: 8) {
                        Text("Result")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(formatResult(result))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                        
                        // Additional formats
                        VStack(spacing: 4) {
                            HStack {
                                Text("Scientific:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text(String(format: "%.6e", result))
                                    .font(.caption)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                            
                            HStack {
                                Text("Percentage:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text(String(format: "%.4f%%", result * 100))
                                    .font(.caption)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(.top, 8)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "function")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("Enter an expression to calculate")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
        }
        .groupBoxStyle(FinancialGroupBoxStyle())
    }
    
    @ViewBuilder
    private var historySection: some View {
        GroupBox("Calculation History") {
            VStack(spacing: 12) {
                HStack {
                    Text("Recent Calculations")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    if !history.isEmpty {
                        Button("Clear History") {
                            history.removeAll()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                if history.isEmpty {
                    Text("No calculations yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 100)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(history.reversed()) { item in
                                HistoryItemView(item: item) {
                                    expression = item.expression
                                    variables = item.variables
                                    result = item.result
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }
            }
            .padding(16)
        }
        .groupBoxStyle(FinancialGroupBoxStyle())
    }
    
    // MARK: - Helper Methods
    
    private func evaluateExpression() {
        guard !expression.isEmpty else { return }

        errorMessage = nil

        guard let expressionResult = CalculationEngine.evaluateExpression(expression, with: variables),
              expressionResult.isFinite else {
            errorMessage = "Could not evaluate — check variables and syntax."
            result = nil
            return
        }

        result = expressionResult
        addToHistory()
    }
    
    private func addToHistory() {
        guard let result = result else { return }
        
        let historyItem = ExpressionHistory(
            expression: expression,
            variables: variables,
            result: result,
            timestamp: Date()
        )
        
        history.append(historyItem)
        
        // Keep only last 50 items
        if history.count > 50 {
            history.removeFirst()
        }
    }
    
    private func clearAll() {
        expression = ""
        result = nil
        errorMessage = nil
        calculationName = "My Expression"
        variables = defaultVariables
    }

    private var defaultVariables: [String: Double] {
        [
            "pi": Double.pi,
            "e": 2.718281828459045,
            "sqrt2": sqrt(2),
            "phi": (1 + sqrt(5)) / 2 // Golden ratio
        ]
    }
    
    private func loadExample(_ example: ExampleExpression) {
        expression = example.expression
        variables = variables.merging(example.variables) { _, new in new }
        calculationName = example.name
        errorMessage = nil
        result = nil
    }
    
    private func saveCalculation() {
        guard !calculationName.isEmpty, !expression.isEmpty else { return }

        let calc = MathExpressionCalculation(
            name: calculationName,
            expression: expression,
            variables: variables
        )
        calc.updateTimestamp()
        modelContext.insert(calc)

        do {
            try modelContext.save()
        } catch {
            mainViewModel.handleError(.dataExportFailed("Could not save the calculation: \(error.localizedDescription)"))
        }
    }

    private func formatResult(_ value: Double) -> String {
        if value.isInfinite {
            return value > 0 ? "∞" : "-∞"
        } else if value.isNaN {
            return "NaN"
        } else if abs(value) >= 1e6 || (abs(value) < 0.001 && value != 0) {
            return String(format: "%.4e", value)
        } else {
            return String(format: "%.8g", value)
        }
    }
    
    private func functionReferenceItem(_ category: String, _ functions: String) -> HStack<TupleView<(Text, Spacer, Text)>> {
        HStack {
            Text(category + ":")
                .fontWeight(.medium)
            Spacer()
            Text(functions)
        }
    }
}

// MARK: - Supporting Types

struct ExampleExpression: Identifiable {
    let id = UUID()
    let name: String
    let expression: String
    let description: String
    let variables: [String: Double]
}

struct ExpressionHistory: Identifiable {
    let id = UUID()
    let expression: String
    let variables: [String: Double]
    let result: Double
    let timestamp: Date
}

// MARK: - Supporting Views

struct HistoryItemView: View {
    let item: ExpressionHistory
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.expression)
                        .font(.body)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(item.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("= \(String(format: "%.6g", item.result))")
                        .font(.caption)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if !item.variables.isEmpty {
                        Text("\(item.variables.count) variables")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct VariableEditorView: View {
    @Binding var variables: [String: Double]
    @Environment(\.dismiss) private var dismiss
    
    @State private var newVariableName: String = ""
    @State private var newVariableValue: String = ""
    @State private var editingVariable: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Add new variable
                GroupBox("Add Variable") {
                    HStack {
                        TextField("Name", text: $newVariableName)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Value", text: $newVariableValue)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Add") {
                            addVariable()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newVariableName.isEmpty || newVariableValue.isEmpty)
                    }
                    .padding()
                }
                
                // Variables list
                GroupBox("Current Variables") {
                    if variables.isEmpty {
                        Text("No variables defined")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 100)
                    } else {
                        List {
                            ForEach(Array(variables.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                                HStack {
                                    Text(key)
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    if editingVariable == key {
                                        TextField("Value", value: Binding(
                                            get: { variables[key] ?? 0 },
                                            set: { variables[key] = $0 }
                                        ), format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 120)
                                        
                                        Button("Done") {
                                            editingVariable = nil
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    } else {
                                        Text(String(format: "%.6g", value))
                                            .font(.system(.body, design: .monospaced))
                                        
                                        Button("Edit") {
                                            editingVariable = key
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }
                            }
                            .onDelete(perform: deleteVariables)
                        }
                        .frame(height: 300)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Variable Editor")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }
    
    private func addVariable() {
        guard !newVariableName.isEmpty,
              let value = Double(newVariableValue) else { return }
        
        variables[newVariableName] = value
        newVariableName = ""
        newVariableValue = ""
    }
    
    private func deleteVariables(offsets: IndexSet) {
        let sortedKeys = variables.keys.sorted()
        for index in offsets {
            let key = sortedKeys[index]
            variables.removeValue(forKey: key)
        }
    }
}

#Preview {
    MathExpressionCalculatorView()
        .environment(MainViewModel())
        .frame(width: 1000, height: 700)
}
