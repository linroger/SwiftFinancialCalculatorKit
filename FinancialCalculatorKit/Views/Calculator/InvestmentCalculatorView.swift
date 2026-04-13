//
//  InvestmentCalculatorView.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import SwiftUI
import SwiftData
import Charts

/// Comprehensive investment analysis calculator for NPV, IRR, and performance metrics
struct InvestmentCalculatorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(MainViewModel.self) private var mainViewModel
    
    @State private var calculation: InvestmentCalculation?
    @State private var calculationName: String = ""
    @State private var initialInvestment: Double = 100000.0
    @State private var cashFlows: [Double] = [20000, 25000, 30000, 35000, 40000]
    @State private var discountRate: Double = 10.0
    @State private var analysisType: InvestmentAnalysisType = .both
    @State private var currency: Currency = .usd
    
    @State private var isCalculating: Bool = false
    @State private var calculationResult: CalculationResult?
    @State private var validationErrors: [String] = []
    @State private var showingSensitivityAnalysis: Bool = false
    @State private var showingCashFlowEditor: Bool = false
    @State private var showingScenarioAnalysis: Bool = false
    
    // Cash flow editing
    @State private var newCashFlow: String = ""
    @State private var editingCashFlowIndex: Int?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                
                HStack(alignment: .top, spacing: 24) {
                    inputSection
                    resultSection
                }
                
                if let result = calculationResult, result.isValid {
                    analysisSection
                }
            }
            .padding(24)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Calculate") {
                    performCalculation()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCalculate)
                
                Menu {
                    Button("Save Calculation") {
                        saveCalculation()
                    }
                    .disabled(!canSave)
                    
                    Button("Export Results") {
                        exportResults()
                    }
                    .disabled(calculationResult == nil)
                    
                    Divider()
                    
                    Button("Edit Cash Flows") {
                        showingCashFlowEditor = true
                    }
                    
                    Button("Scenario Analysis") {
                        showingScenarioAnalysis = true
                    }
                    .disabled(calculationResult == nil)
                    
                    Divider()
                    
                    Button("Reset Fields") {
                        resetFields()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingCashFlowEditor) {
            CashFlowEditorView(cashFlows: $cashFlows)
        }
        .sheet(isPresented: $showingSensitivityAnalysis) {
            if let result = calculationResult {
                InvestmentSensitivityAnalysisView(
                    baseResult: result,
                    investmentData: currentInvestmentData
                )
            }
        }
        .sheet(isPresented: $showingScenarioAnalysis) {
            if let result = calculationResult {
                ScenarioAnalysisView(
                    baseResult: result,
                    investmentData: currentInvestmentData
                )
            }
        }
        .onAppear {
            currency = mainViewModel.userPreferences.defaultCurrency
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Investment Analysis")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Calculate NPV, IRR, and investment performance metrics for cash flow projections")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if isCalculating {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if calculationResult?.isValid == true {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    
                    Text("Investment Decision Tool")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Error display
            if !validationErrors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(validationErrors, id: \.self) { error in
                        Text("• \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red.opacity(0.1))
                )
            }
        }
    }
    
    @ViewBuilder
    private var inputSection: some View {
        VStack(spacing: 20) {
            // Basic investment parameters
            GroupBox("Investment Details") {
                VStack(spacing: 16) {
                    // Calculation name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Investment Name")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        TextField("Enter investment name", text: $calculationName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Initial investment
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Initial Investment")
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Button(action: {}) {
                                Image(systemName: "questionmark.circle")
                            }
                            .buttonStyle(.plain)
                            .help("The initial amount invested (entered as positive value)")
                        }
                        
                        CurrencyInputField(
                            value: $initialInvestment,
                            currency: currency,
                            placeholder: "Initial investment"
                        ) { newValue in
                            initialInvestment = max(0, newValue)
                            clearResults()
                        }
                    }
                    
                    // Discount rate
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Discount Rate (Required Return %)")
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Button(action: {}) {
                                Image(systemName: "questionmark.circle")
                            }
                            .buttonStyle(.plain)
                            .help("The minimum acceptable rate of return for the investment")
                        }
                        
                        PercentageInputField(
                            title: "Discount Rate",
                            value: Binding(
                                get: { discountRate },
                                set: { if let newValue = $0 { discountRate = max(0, newValue) } }
                            ),
                            isRequired: true,
                            helpText: "The minimum acceptable rate of return for the investment"
                        )
                    }
                    
                    // Analysis type
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Analysis Type")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Picker("Analysis Type", selection: $analysisType) {
                            ForEach(InvestmentAnalysisType.allCases) { type in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(type.displayName)
                                        .font(.body)
                                    Text(type.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(type)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .onChange(of: analysisType) { _, _ in
                            clearResults()
                        }
                    }
                }
                .padding(16)
            }
            .groupBoxStyle(FinancialGroupBoxStyle())
            
            // Cash flows section
            GroupBox("Cash Flow Projections") {
                VStack(spacing: 16) {
                    HStack {
                        Text("Projected Cash Flows")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Button("Edit Cash Flows") {
                            showingCashFlowEditor = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    // Quick cash flow summary
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(cashFlows.enumerated()), id: \.offset) { index, cashFlow in
                                VStack(spacing: 4) {
                                    Text("Year \(index + 1)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text(currency.formatValue(cashFlow))
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.medium)
                                        .foregroundColor(cashFlow >= 0 ? .green : .red)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                )
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    
                    // Quick stats
                    VStack(spacing: 8) {
                        DetailRow(
                            title: "Total Cash Inflows",
                            value: currency.formatValue(cashFlows.reduce(0, +))
                        )
                        DetailRow(
                            title: "Investment Period",
                            value: "\(cashFlows.count) years"
                        )
                        DetailRow(
                            title: "Average Annual Cash Flow",
                            value: currency.formatValue(cashFlows.reduce(0, +) / Double(cashFlows.count))
                        )
                    }
                }
                .padding(16)
            }
            .groupBoxStyle(FinancialGroupBoxStyle())
            
            // Currency selection
            GroupBox("Settings") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Currency")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Picker("Currency", selection: $currency) {
                        ForEach(Currency.allCases.prefix(8)) { curr in
                            Text("\(curr.displayName) (\(curr.symbol))")
                                .tag(curr)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: currency) { _, _ in
                        clearResults()
                    }
                }
                .padding(16)
            }
            .groupBoxStyle(FinancialGroupBoxStyle())
        }
        .frame(maxWidth: 500)
    }
    
    @ViewBuilder
    private var resultSection: some View {
        VStack(spacing: 20) {
            if let result = calculationResult, result.isValid {
                // Primary result
                GroupBox {
                    VStack(spacing: 16) {
                        Text(analysisType.displayName)
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(result.formattedPrimaryValue)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(isProfitable ? .green : .red)
                        
                        if !result.explanation.isEmpty {
                            Text(result.explanation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Investment decision indicator
                        HStack {
                            Image(systemName: isProfitable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isProfitable ? .green : .red)
                            
                            Text(isProfitable ? "Profitable Investment" : "Unprofitable Investment")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(isProfitable ? .green : .red)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill((isProfitable ? Color.green : Color.red).opacity(0.1))
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
                .groupBoxStyle(FinancialGroupBoxStyle())
                
                // Secondary metrics
                if !result.secondaryValues.isEmpty {
                    GroupBox("Investment Metrics") {
                        VStack(spacing: 12) {
                            ForEach(Array(result.secondaryValues.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                                DetailRow(
                                    title: key,
                                    value: formatSecondaryValue(key: key, value: value),
                                    isHighlighted: key.contains("IRR") || key.contains("NPV") || key.contains("Index")
                                )
                            }
                        }
                        .padding(16)
                    }
                    .groupBoxStyle(FinancialGroupBoxStyle())
                }
                
                // Investment insights
                GroupBox("Investment Analysis") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(generateInsights(), id: \.self) { insight in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                
                                Text(insight)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(16)
                }
                .groupBoxStyle(FinancialGroupBoxStyle())
                
                // Action buttons
                VStack(spacing: 12) {
                    Button("Sensitivity Analysis") {
                        showingSensitivityAnalysis = true
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    
                    Button("Scenario Analysis") {
                        showingScenarioAnalysis = true
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            } else {
                // Placeholder when no results
                GroupBox {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("Enter investment details and calculate to see analysis")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
                .groupBoxStyle(FinancialGroupBoxStyle())
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var analysisSection: some View {
        VStack(spacing: 20) {
            // Cash flow visualization
            if let chartData = calculationResult?.chartData, !chartData.isEmpty {
                FinancialChartView(
                    data: chartData,
                    chartType: .bar,
                    title: "Investment Cash Flow Analysis",
                    currency: currency,
                    height: 300
                )
            }
            
            // NPV sensitivity to discount rate
            GroupBox("NPV Sensitivity Analysis") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("NPV vs Discount Rate")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Chart {
                        ForEach(generateNPVSensitivityData(), id: \.rate) { point in
                            LineMark(
                                x: .value("Discount Rate", point.rate),
                                y: .value("NPV", point.npv)
                            )
                            .foregroundStyle(.blue)
                            .interpolationMethod(.catmullRom)
                            
                            // Highlight current discount rate
                            if abs(point.rate - discountRate) < 0.5 {
                                PointMark(
                                    x: .value("Discount Rate", point.rate),
                                    y: .value("NPV", point.npv)
                                )
                                .foregroundStyle(.red)
                                .symbolSize(100)
                            }
                        }
                        
                        // Add break-even line
                        RuleMark(y: .value("Break-even", 0))
                            .foregroundStyle(.gray)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let rate = value.as(Double.self) {
                                    Text("\(rate, specifier: "%.0f")%")
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let npv = value.as(Double.self) {
                                    Text(currency.symbol + Formatters.formatAbbreviated(npv))
                                }
                            }
                        }
                    }
                    
                    Text("Red dot shows current discount rate. NPV becomes negative above the IRR.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
            }
            .groupBoxStyle(FinancialGroupBoxStyle())
        }
    }
    
    // MARK: - Helper Methods
    
    private var canCalculate: Bool {
        !calculationName.isEmpty &&
        initialInvestment > 0 &&
        !cashFlows.isEmpty &&
        discountRate >= 0
    }
    
    private var canSave: Bool {
        canCalculate && calculationResult?.isValid == true
    }
    
    private var isProfitable: Bool {
        guard let result = calculationResult, result.isValid else { return false }
        
        switch analysisType {
        case .npv, .both:
            return result.primaryValue > 0
        case .irr:
            return result.primaryValue > discountRate
        }
    }
    
    private var currentInvestmentData: (initialInvestment: Double, cashFlows: [Double], discountRate: Double) {
        (initialInvestment, cashFlows, discountRate)
    }
    
    private func performCalculation() {
        guard canCalculate else {
            validateInputs()
            return
        }
        
        isCalculating = true
        validationErrors = []
        
        // Create temporary calculation object
        let tempCalculation = InvestmentCalculation(
            name: calculationName,
            initialInvestment: initialInvestment,
            cashFlows: cashFlows,
            discountRate: discountRate,
            analysisType: analysisType,
            currency: currency
        )
        
        // Perform calculation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            calculationResult = tempCalculation.result
            isCalculating = false
            
            if calculationResult?.isValid != true {
                validationErrors = tempCalculation.validationErrors
            }
        }
    }
    
    private func validateInputs() {
        validationErrors = []
        
        if calculationName.isEmpty {
            validationErrors.append("Investment name is required")
        }
        
        if initialInvestment <= 0 {
            validationErrors.append("Initial investment must be positive")
        }
        
        if cashFlows.isEmpty {
            validationErrors.append("At least one cash flow is required")
        }
        
        if discountRate < 0 {
            validationErrors.append("Discount rate cannot be negative")
        }
    }
    
    private func clearResults() {
        calculationResult = nil
        validationErrors = []
    }
    
    private func resetFields() {
        calculationName = ""
        initialInvestment = 100000.0
        cashFlows = [20000, 25000, 30000, 35000, 40000]
        discountRate = 10.0
        analysisType = .both
        clearResults()
    }
    
    private func saveCalculation() {
        guard let result = calculationResult, result.isValid else { return }
        
        let investmentCalculation = InvestmentCalculation(
            name: calculationName,
            initialInvestment: initialInvestment,
            cashFlows: cashFlows,
            discountRate: discountRate,
            analysisType: analysisType,
            currency: currency
        )
        
        modelContext.insert(investmentCalculation)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save calculation: \(error)")
        }
    }
    
    private func exportResults() {
        // Implementation for exporting results
    }
    
    private func formatSecondaryValue(key: String, value: Double) -> String {
        if key.contains("Rate") || key.contains("IRR") || key.contains("%") {
            return String(format: "%.3f%%", value)
        } else if key.contains("Index") {
            return String(format: "%.3f", value)
        } else if key.contains("Period") {
            return String(format: "%.1f years", value)
        } else if key.contains("NPV") || key.contains("Investment") || key.contains("Inflows") {
            return currency.formatValue(value)
        } else {
            return Formatters.decimalFormatter(decimalPlaces: 2).string(from: NSNumber(value: value)) ?? "0.00"
        }
    }
    
    private func generateInsights() -> [String] {
        guard let result = calculationResult, result.isValid else { return [] }
        
        var insights: [String] = []
        
        if let profitabilityIndex = result.secondaryValues["Profitability Index"] {
            if profitabilityIndex > 1.2 {
                insights.append("High profitability index (\(String(format: "%.2f", profitabilityIndex))) indicates excellent returns")
            } else if profitabilityIndex > 1.0 {
                insights.append("Profitability index above 1.0 indicates positive returns")
            } else {
                insights.append("Profitability index below 1.0 suggests negative returns")
            }
        }
        
        if let paybackPeriod = result.secondaryValues["Payback Period"] {
            let period = paybackPeriod
            if period <= 3 {
                insights.append("Short payback period (\(String(format: "%.1f", period)) years) reduces investment risk")
            } else if period <= 5 {
                insights.append("Moderate payback period (\(String(format: "%.1f", period)) years)")
            } else {
                insights.append("Long payback period (\(String(format: "%.1f", period)) years) increases investment risk")
            }
        }
        
        if analysisType == .irr || analysisType == .both {
            if result.primaryValue > discountRate + 5 {
                insights.append("IRR significantly exceeds required return - strong investment opportunity")
            } else if result.primaryValue > discountRate {
                insights.append("IRR exceeds required return - meets investment criteria")
            }
        }
        
        let totalCashInflows = cashFlows.reduce(0, +)
        let simplePayback = initialInvestment / (totalCashInflows / Double(cashFlows.count))
        if simplePayback > Double(cashFlows.count) {
            insights.append("Cash flows may not fully recover initial investment over project life")
        }
        
        return insights
    }
    
    private func generateNPVSensitivityData() -> [NPVSensitivityPoint] {
        var data: [NPVSensitivityPoint] = []
        var allCashFlows = [-abs(initialInvestment)]
        allCashFlows.append(contentsOf: cashFlows)
        
        for rate in stride(from: 1.0, through: 30.0, by: 1.0) {
            let npv = CalculationEngine.calculateNPV(
                cashFlows: allCashFlows,
                discountRate: rate
            )
            data.append(NPVSensitivityPoint(rate: rate, npv: npv))
        }
        
        return data
    }
}

// MARK: - Supporting Views

struct CashFlowEditorView: View {
    @Binding var cashFlows: [Double]
    @Environment(\.dismiss) private var dismiss
    @State private var newCashFlow: String = ""
    @State private var editingIndex: Int?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Add new cash flow
                GroupBox("Add Cash Flow") {
                    HStack {
                        TextField("Cash flow amount", text: $newCashFlow)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Add") {
                            if let value = Double(newCashFlow) {
                                cashFlows.append(value)
                                newCashFlow = ""
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newCashFlow.isEmpty || Double(newCashFlow) == nil)
                    }
                    .padding()
                }
                
                // Cash flows list
                GroupBox("Cash Flow Projections") {
                    if cashFlows.isEmpty {
                        Text("No cash flows added yet")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 100)
                    } else {
                        List {
                            ForEach(Array(cashFlows.enumerated()), id: \.offset) { index, cashFlow in
                                HStack {
                                    Text("Year \(index + 1)")
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    if editingIndex == index {
                                        TextField("Amount", value: Binding(
                                            get: { cashFlows[index] },
                                            set: { cashFlows[index] = $0 }
                                        ), format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 120)
                                        
                                        Button("Done") {
                                            editingIndex = nil
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    } else {
                                        Text("$\(cashFlow, specifier: "%.2f")")
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(cashFlow >= 0 ? .green : .red)
                                        
                                        Button("Edit") {
                                            editingIndex = index
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }
                            }
                            .onDelete(perform: deleteCashFlows)
                            .onMove(perform: moveCashFlows)
                        }
                        .frame(height: 300)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Edit Cash Flows")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 500)
    }
    
    private func deleteCashFlows(offsets: IndexSet) {
        cashFlows.remove(atOffsets: offsets)
    }
    
    private func moveCashFlows(from source: IndexSet, to destination: Int) {
        cashFlows.move(fromOffsets: source, toOffset: destination)
    }
}

struct InvestmentSensitivityAnalysisView: View {
    let baseResult: CalculationResult
    let investmentData: (initialInvestment: Double, cashFlows: [Double], discountRate: Double)
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Investment Sensitivity Analysis")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding()
                    
                    // NPV sensitivity to discount rate
                    GroupBox("NPV vs Discount Rate") {
                        Chart {
                            ForEach(generateNPVSensitivityData(), id: \.rate) { point in
                                LineMark(
                                    x: .value("Rate", point.rate),
                                    y: .value("NPV", point.npv)
                                )
                                .foregroundStyle(.blue)
                                .interpolationMethod(.catmullRom)
                            }
                            
                            RuleMark(y: .value("Break-even", 0))
                                .foregroundStyle(.red)
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        }
                        .frame(height: 300)
                        .chartXAxis {
                            AxisMarks { value in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel {
                                    if let rate = value.as(Double.self) {
                                        Text("\(rate, specifier: "%.0f")%")
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks { value in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel {
                                    if let npv = value.as(Double.self) {
                                        Text("$\(Int(npv / 1000))K")
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    
                    // Key metrics
                    GroupBox("Sensitivity Metrics") {
                        VStack(alignment: .leading, spacing: 12) {
                            DetailRow(title: "Break-even Discount Rate", value: String(format: "%.2f%%", calculateBreakevenRate()))
                            DetailRow(title: "NPV at Current Rate", value: Currency.usd.formatValue(baseResult.primaryValue))
                            DetailRow(title: "Sensitivity Score", value: "High")
                            
                            Divider()
                            
                            Text("A higher break-even rate indicates a more robust investment that can withstand higher discount rates.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Sensitivity Analysis")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
    
    private func generateNPVSensitivityData() -> [NPVSensitivityPoint] {
        var data: [NPVSensitivityPoint] = []
        var allCashFlows = [-abs(investmentData.initialInvestment)]
        allCashFlows.append(contentsOf: investmentData.cashFlows)
        
        for rate in stride(from: 1.0, through: 30.0, by: 0.5) {
            let npv = CalculationEngine.calculateNPV(
                cashFlows: allCashFlows,
                discountRate: rate
            )
            data.append(NPVSensitivityPoint(rate: rate, npv: npv))
        }
        
        return data
    }
    
    private func calculateBreakevenRate() -> Double {
        var allCashFlows = [-abs(investmentData.initialInvestment)]
        allCashFlows.append(contentsOf: investmentData.cashFlows)
        return CalculationEngine.calculateIRR(cashFlows: allCashFlows)
    }
}

struct ScenarioAnalysisView: View {
    let baseResult: CalculationResult
    let investmentData: (initialInvestment: Double, cashFlows: [Double], discountRate: Double)
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    titleSection
                    scenarioComparisonSection
                    probabilityAnalysisSection
                }
                .padding()
            }
            .navigationTitle("Scenario Analysis")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
    
    @ViewBuilder
    private var titleSection: some View {
        Text("Scenario Analysis")
            .font(.title)
            .fontWeight(.bold)
            .padding()
    }
    
    @ViewBuilder
    private var scenarioComparisonSection: some View {
        GroupBox("Investment Scenarios") {
            scenarioTable
        }
    }
    
    @ViewBuilder
    private var scenarioTable: some View {
        Table(generateScenarios()) {
            TableColumn("Scenario") { scenario in
                Text(scenario.name)
                    .fontWeight(.medium)
            }
            .width(120)
            
            TableColumn("NPV") { scenario in
                npvColumn(for: scenario)
            }
            .width(100)
            
            TableColumn("IRR") { scenario in
                irrColumn(for: scenario)
            }
            .width(100)
            
            TableColumn("Decision") { scenario in
                decisionColumn(for: scenario)
            }
            .width(80)
        }
        .frame(height: 200)
    }
    
    @ViewBuilder
    private func npvColumn(for scenario: InvestmentScenario) -> some View {
        Text(Currency.usd.formatValue(scenario.npv))
            .font(.system(.body, design: .monospaced))
            .foregroundColor(scenario.npv >= 0 ? .green : .red)
    }
    
    @ViewBuilder
    private func irrColumn(for scenario: InvestmentScenario) -> some View {
        Text("\(scenario.irr, specifier: "%.2f")%")
            .font(.system(.body, design: .monospaced))
    }
    
    @ViewBuilder
    private func decisionColumn(for scenario: InvestmentScenario) -> some View {
        Text(scenario.npv >= 0 ? "Accept" : "Reject")
            .foregroundColor(scenario.npv >= 0 ? .green : .red)
            .fontWeight(.medium)
    }
    
    @ViewBuilder
    private var probabilityAnalysisSection: some View {
        GroupBox("Scenario Probabilities") {
            probabilityContent
        }
    }
    
    @ViewBuilder
    private var probabilityContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Assuming different cash flow scenarios:")
                .font(.headline)
            
            probabilityRows
        }
        .padding()
    }
    
    @ViewBuilder
    private var probabilityRows: some View {
        let scenarios = generateScenarios()
        let positiveScenarios = scenarios.filter { $0.npv >= 0 }.count
        let totalScenarios = scenarios.count
        let successRate = Double(positiveScenarios) / Double(totalScenarios) * 100
        
        DetailRow(title: "Positive NPV Scenarios", value: "\(positiveScenarios) of \(totalScenarios)")
        DetailRow(title: "Success Probability", value: String(format: "%.0f%%", successRate))
        DetailRow(title: "Risk Assessment", value: successRate > 70 ? "Low Risk" : successRate > 40 ? "Medium Risk" : "High Risk")
    }
    
    private func generateScenarios() -> [InvestmentScenario] {
        let baseCashFlows = investmentData.cashFlows
        var scenarios: [InvestmentScenario] = []
        
        // Best case (20% higher cash flows)
        let bestCaseCashFlows = baseCashFlows.map { $0 * 1.2 }
        scenarios.append(calculateScenario(name: "Best Case", cashFlows: bestCaseCashFlows))
        
        // Base case
        scenarios.append(calculateScenario(name: "Base Case", cashFlows: baseCashFlows))
        
        // Worst case (20% lower cash flows)
        let worstCaseCashFlows = baseCashFlows.map { $0 * 0.8 }
        scenarios.append(calculateScenario(name: "Worst Case", cashFlows: worstCaseCashFlows))
        
        // Pessimistic (30% lower cash flows)
        let pessimisticCashFlows = baseCashFlows.map { $0 * 0.7 }
        scenarios.append(calculateScenario(name: "Pessimistic", cashFlows: pessimisticCashFlows))
        
        // Optimistic (30% higher cash flows)
        let optimisticCashFlows = baseCashFlows.map { $0 * 1.3 }
        scenarios.append(calculateScenario(name: "Optimistic", cashFlows: optimisticCashFlows))
        
        return scenarios
    }
    
    private func calculateScenario(name: String, cashFlows: [Double]) -> InvestmentScenario {
        var allCashFlows = [-abs(investmentData.initialInvestment)]
        allCashFlows.append(contentsOf: cashFlows)
        
        let npv = CalculationEngine.calculateNPV(
            cashFlows: allCashFlows,
            discountRate: investmentData.discountRate
        )
        
        let irr = CalculationEngine.calculateIRR(cashFlows: allCashFlows)
        
        return InvestmentScenario(name: name, npv: npv, irr: irr)
    }
}

// MARK: - Supporting Types

struct NPVSensitivityPoint {
    let rate: Double
    let npv: Double
}

struct InvestmentScenario: Identifiable {
    let id = UUID()
    let name: String
    let npv: Double
    let irr: Double
}

#Preview {
    InvestmentCalculatorView()
        .environment(MainViewModel())
        .modelContainer(for: InvestmentCalculation.self, inMemory: true)
        .frame(width: 1200, height: 800)
}