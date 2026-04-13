//
//  DepreciationCalculatorView.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import SwiftUI
import SwiftData
import Charts

/// Comprehensive depreciation calculator for asset depreciation analysis
struct DepreciationCalculatorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(MainViewModel.self) private var mainViewModel
    
    @State private var calculation: DepreciationCalculation?
    @State private var calculationName: String = ""
    @State private var assetCost: Double = 100000.0
    @State private var salvageValue: Double = 10000.0
    @State private var usefulLife: Double = 5.0
    @State private var currentYear: Double = 1.0
    @State private var method: DepreciationMethod = .straightLine
    @State private var macrsClass: MACRSPropertyClass?
    @State private var decliningBalanceRate: Double = 2.0
    @State private var currency: Currency = .usd
    
    @State private var isCalculating: Bool = false
    @State private var calculationResult: CalculationResult?
    @State private var validationErrors: [String] = []
    @State private var showingDepreciationSchedule: Bool = false
    @State private var showingMethodComparison: Bool = false
    
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
                    
                    Button("View Full Schedule") {
                        showingDepreciationSchedule = true
                    }
                    .disabled(calculationResult == nil)
                    
                    Button("Compare Methods") {
                        showingMethodComparison = true
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
        .sheet(isPresented: $showingDepreciationSchedule) {
            if calculationResult != nil {
                DepreciationScheduleView(
                    depreciationData: currentDepreciationData,
                    currency: currency
                )
            }
        }
        .sheet(isPresented: $showingMethodComparison) {
            MethodComparisonView(
                assetCost: assetCost,
                salvageValue: salvageValue,
                usefulLife: usefulLife,
                currency: currency
            )
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
                    Text("Depreciation Calculator")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Calculate asset depreciation using various methods including straight-line, declining balance, and MACRS")
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
                    
                    Text("Asset Depreciation Tool")
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
            // Basic asset information
            GroupBox("Asset Information") {
                VStack(spacing: 16) {
                    // Calculation name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Asset Name")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        TextField("Enter asset name", text: $calculationName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Asset cost
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Asset Cost")
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Button(action: {}) {
                                Image(systemName: "questionmark.circle")
                            }
                            .buttonStyle(.plain)
                            .help("The initial cost or acquisition value of the asset")
                        }
                        
                        CurrencyInputField(
                            value: $assetCost,
                            currency: currency,
                            placeholder: "Asset cost"
                        ) { newValue in
                            assetCost = max(0, newValue)
                            clearResults()
                        }
                    }
                    
                    // Salvage value
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Salvage Value")
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Button(action: {}) {
                                Image(systemName: "questionmark.circle")
                            }
                            .buttonStyle(.plain)
                            .help("The estimated value of the asset at the end of its useful life")
                        }
                        
                        CurrencyInputField(
                            value: $salvageValue,
                            currency: currency,
                            placeholder: "Salvage value"
                        ) { newValue in
                            salvageValue = max(0, min(newValue, assetCost))
                            clearResults()
                        }
                    }
                    
                    // Useful life
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Useful Life (Years)")
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Button(action: {}) {
                                Image(systemName: "questionmark.circle")
                            }
                            .buttonStyle(.plain)
                            .help("The expected productive life of the asset in years")
                        }
                        
                        TextField("Years", value: $usefulLife, format: .number.precision(.fractionLength(0)))
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: usefulLife) { _, newValue in
                                usefulLife = max(1, newValue)
                                currentYear = min(currentYear, usefulLife)
                                clearResults()
                            }
                    }
                    
                    // Current year
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calculate Depreciation for Year")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Picker("Year", selection: $currentYear) {
                            ForEach(1...Int(usefulLife), id: \.self) { year in
                                Text("Year \(year)").tag(Double(year))
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: currentYear) { _, _ in
                            clearResults()
                        }
                    }
                }
                .padding(16)
            }
            .groupBoxStyle(FinancialGroupBoxStyle())
            
            // Depreciation method
            GroupBox("Depreciation Method") {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Method")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Picker("Method", selection: $method) {
                            ForEach(DepreciationMethod.allCases) { depMethod in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(depMethod.displayName)
                                        .font(.body)
                                    Text(depMethod.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(depMethod)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .onChange(of: method) { _, _ in
                            clearResults()
                        }
                    }
                    
                    // Method-specific inputs
                    Group {
                        if method == .decliningBalance {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Declining Balance Rate")
                                        .font(.headline)
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    Button(action: {}) {
                                        Image(systemName: "questionmark.circle")
                                    }
                                    .buttonStyle(.plain)
                                    .help("Common rates: 2.0 (double declining), 1.5 (150% declining)")
                                }
                                
                                TextField("Rate", value: $decliningBalanceRate, format: .number.precision(.fractionLength(1)))
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: decliningBalanceRate) { _, newValue in
                                        decliningBalanceRate = max(1.0, newValue)
                                        clearResults()
                                    }
                                
                                HStack {
                                    Button("1.5x") { decliningBalanceRate = 1.5 }
                                    Button("2.0x") { decliningBalanceRate = 2.0 }
                                    Button("2.5x") { decliningBalanceRate = 2.5 }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        
                        if method == .macrs {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("MACRS Property Class")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                
                                Picker("MACRS Class", selection: $macrsClass) {
                                    Text("Select Property Class").tag(MACRSPropertyClass?.none)
                                    ForEach(MACRSPropertyClass.allCases) { propertyClass in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(propertyClass.displayName)
                                                .font(.body)
                                            Text(propertyClass.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .tag(MACRSPropertyClass?.some(propertyClass))
                                    }
                                }
                                .pickerStyle(.menu)
                                .onChange(of: macrsClass) { _, _ in
                                    clearResults()
                                }
                            }
                        }
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
                        Text("Year \(Int(currentYear)) Depreciation")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(result.formattedPrimaryValue)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        HStack {
                            Text(method.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if !result.explanation.isEmpty {
                            Text(result.explanation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
                .groupBoxStyle(FinancialGroupBoxStyle())
                
                // Secondary metrics
                if !result.secondaryValues.isEmpty {
                    GroupBox("Asset Details") {
                        VStack(spacing: 12) {
                            ForEach(Array(result.secondaryValues.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                                DetailRow(
                                    title: key,
                                    value: formatSecondaryValue(key: key, value: value),
                                    isHighlighted: key.contains("Book Value") || key.contains("Cumulative")
                                )
                            }
                        }
                        .padding(16)
                    }
                    .groupBoxStyle(FinancialGroupBoxStyle())
                }
                
                // Depreciation insights
                GroupBox("Depreciation Analysis") {
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
                    Button("View Full Schedule") {
                        showingDepreciationSchedule = true
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    
                    Button("Compare Methods") {
                        showingMethodComparison = true
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            } else {
                // Placeholder when no results
                GroupBox {
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.down.right.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("Enter asset details and calculate to see depreciation")
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
            // Depreciation schedule visualization
            if let chartData = calculationResult?.chartData, !chartData.isEmpty {
                FinancialChartView(
                    data: chartData,
                    chartType: .bar,
                    title: "Annual Depreciation Schedule",
                    currency: currency,
                    height: 300
                )
            }
            
            // Book value over time
            GroupBox("Asset Book Value Over Time") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Book Value Decline")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Chart {
                        ForEach(generateBookValueData(), id: \.year) { point in
                            LineMark(
                                x: .value("Year", point.year),
                                y: .value("Book Value", point.bookValue)
                            )
                            .foregroundStyle(.blue)
                            .interpolationMethod(.stepStart)
                            
                            // Highlight current year
                            if point.year == Int(currentYear) {
                                PointMark(
                                    x: .value("Year", point.year),
                                    y: .value("Book Value", point.bookValue)
                                )
                                .foregroundStyle(.red)
                                .symbolSize(100)
                            }
                        }
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let year = value.as(Int.self) {
                                    Text("Year \(year)")
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let bookValue = value.as(Double.self) {
                                    Text(currency.symbol + Formatters.formatAbbreviated(bookValue))
                                }
                            }
                        }
                    }
                    
                    Text("Red dot shows current year book value")
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
        assetCost > 0 &&
        salvageValue >= 0 &&
        salvageValue < assetCost &&
        usefulLife > 0 &&
        currentYear > 0 &&
        currentYear <= usefulLife &&
        (method != .macrs || macrsClass != nil)
    }
    
    private var canSave: Bool {
        canCalculate && calculationResult?.isValid == true
    }
    
    private var currentDepreciationData: (assetCost: Double, salvageValue: Double, usefulLife: Double, method: DepreciationMethod) {
        (assetCost, salvageValue, usefulLife, method)
    }
    
    private func performCalculation() {
        guard canCalculate else {
            validateInputs()
            return
        }
        
        isCalculating = true
        validationErrors = []
        
        // Create temporary calculation object
        let tempCalculation = DepreciationCalculation(
            name: calculationName,
            assetCost: assetCost,
            salvageValue: salvageValue,
            usefulLife: usefulLife,
            currentYear: currentYear,
            method: method,
            decliningBalanceRate: decliningBalanceRate,
            currency: currency
        )
        
        if method == .macrs {
            tempCalculation.macrsClass = macrsClass
        }
        
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
            validationErrors.append("Asset name is required")
        }
        
        if assetCost <= 0 {
            validationErrors.append("Asset cost must be positive")
        }
        
        if salvageValue < 0 {
            validationErrors.append("Salvage value cannot be negative")
        }
        
        if salvageValue >= assetCost {
            validationErrors.append("Salvage value must be less than asset cost")
        }
        
        if usefulLife <= 0 {
            validationErrors.append("Useful life must be positive")
        }
        
        if currentYear <= 0 || currentYear > usefulLife {
            validationErrors.append("Current year must be between 1 and useful life")
        }
        
        if method == .macrs && macrsClass == nil {
            validationErrors.append("MACRS property class is required")
        }
    }
    
    private func clearResults() {
        calculationResult = nil
        validationErrors = []
    }
    
    private func resetFields() {
        calculationName = ""
        assetCost = 100000.0
        salvageValue = 10000.0
        usefulLife = 5.0
        currentYear = 1.0
        method = .straightLine
        macrsClass = nil
        decliningBalanceRate = 2.0
        clearResults()
    }
    
    private func saveCalculation() {
        guard let result = calculationResult, result.isValid else { return }
        
        let depreciationCalculation = DepreciationCalculation(
            name: calculationName,
            assetCost: assetCost,
            salvageValue: salvageValue,
            usefulLife: usefulLife,
            currentYear: currentYear,
            method: method,
            decliningBalanceRate: decliningBalanceRate,
            currency: currency
        )
        
        if method == .macrs {
            depreciationCalculation.macrsClass = macrsClass
        }
        
        modelContext.insert(depreciationCalculation)
        
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
        if key.contains("Rate") || key.contains("%") {
            return String(format: "%.2f%%", value)
        } else if key.contains("Year") || key.contains("Life") {
            return String(format: "%.0f", value)
        } else if key.contains("Cost") || key.contains("Value") || key.contains("Depreciation") {
            return currency.formatValue(value)
        } else {
            return Formatters.decimalFormatter(decimalPlaces: 2).string(from: NSNumber(value: value)) ?? "0.00"
        }
    }
    
    private func generateInsights() -> [String] {
        guard let result = calculationResult, result.isValid else { return [] }
        
        var insights: [String] = []
        
        let depreciationRate = (result.secondaryValues["Depreciation Rate"] ?? 0) / 100
        if depreciationRate > 0.3 {
            insights.append("High depreciation rate in early years - good for tax benefits")
        } else if depreciationRate < 0.1 {
            insights.append("Low depreciation rate - conserves asset value")
        }
        
        let bookValue = result.secondaryValues["Book Value"] ?? 0
        let assetCostValue = result.secondaryValues["Asset Cost"] ?? assetCost
        let remainingValue = bookValue / assetCostValue
        
        if remainingValue > 0.7 {
            insights.append("Asset retains most of its book value")
        } else if remainingValue < 0.3 {
            insights.append("Asset has depreciated significantly")
        }
        
        switch method {
        case .straightLine:
            insights.append("Straight-line provides consistent depreciation for financial reporting")
        case .decliningBalance:
            insights.append("Accelerated depreciation provides larger tax deductions in early years")
        case .sumOfYearsDigits:
            insights.append("Moderate acceleration balances tax benefits and book value")
        case .macrs:
            insights.append("MACRS method required for US tax depreciation purposes")
        }
        
        if method != .macrs && salvageValue > 0 {
            let salvagePercent = (salvageValue / assetCost) * 100
            insights.append("Salvage value of \(String(format: "%.0f%%", salvagePercent)) reduces total depreciation")
        }
        
        return insights
    }
    
    private func generateBookValueData() -> [BookValuePoint] {
        let tempCalculation = DepreciationCalculation(
            name: calculationName,
            assetCost: assetCost,
            salvageValue: salvageValue,
            usefulLife: usefulLife,
            currentYear: currentYear,
            method: method,
            decliningBalanceRate: decliningBalanceRate,
            currency: currency
        )
        
        if method == .macrs {
            tempCalculation.macrsClass = macrsClass
        }
        
        let schedule = tempCalculation.generateDepreciationSchedule()
        var points: [BookValuePoint] = []
        
        // Add initial point
        points.append(BookValuePoint(year: 0, bookValue: assetCost))
        
        // Add points for each year
        for entry in schedule {
            points.append(BookValuePoint(year: entry.year, bookValue: entry.bookValue))
        }
        
        return points
    }
}

// MARK: - Supporting Views

struct DepreciationScheduleView: View {
    let depreciationData: (assetCost: Double, salvageValue: Double, usefulLife: Double, method: DepreciationMethod)
    let currency: Currency
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary
                    GroupBox("Asset Summary") {
                        VStack(alignment: .leading, spacing: 12) {
                            DetailRow(title: "Asset Cost", value: currency.formatValue(depreciationData.assetCost))
                            DetailRow(title: "Salvage Value", value: currency.formatValue(depreciationData.salvageValue))
                            DetailRow(title: "Depreciable Base", value: currency.formatValue(depreciationData.assetCost - depreciationData.salvageValue))
                            DetailRow(title: "Useful Life", value: "\(Int(depreciationData.usefulLife)) years")
                            DetailRow(title: "Method", value: depreciationData.method.displayName)
                        }
                        .padding()
                    }
                    
                    // Depreciation schedule table
                    GroupBox("Depreciation Schedule") {
                        let schedule = generateDepreciationSchedule()
                        Table(schedule) {
                            TableColumn("Year") { entry in
                                Text("\(entry.year)")
                            }
                            .width(60)
                            
                            TableColumn("Depreciation") { entry in
                                Text(currency.formatValue(entry.depreciation))
                                    .font(.system(.body, design: .monospaced))
                            }
                            .width(120)
                            
                            TableColumn("Cumulative") { entry in
                                Text(currency.formatValue(entry.cumulativeDepreciation))
                                    .font(.system(.body, design: .monospaced))
                            }
                            .width(120)
                            
                            TableColumn("Book Value") { entry in
                                Text(currency.formatValue(entry.bookValue))
                                    .font(.system(.body, design: .monospaced))
                            }
                            .width(120)
                        }
                        .frame(height: 300)
                    }
                }
                .padding()
            }
            .navigationTitle("Depreciation Schedule")
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
    
    private func generateDepreciationSchedule() -> [DepreciationEntry] {
        let tempCalculation = DepreciationCalculation(
            name: "Temp",
            assetCost: depreciationData.assetCost,
            salvageValue: depreciationData.salvageValue,
            usefulLife: depreciationData.usefulLife,
            method: depreciationData.method
        )
        
        return tempCalculation.generateDepreciationSchedule()
    }
}

struct MethodComparisonView: View {
    let assetCost: Double
    let salvageValue: Double
    let usefulLife: Double
    let currency: Currency
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Depreciation Method Comparison")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding()
                    
                    // Comparison chart
                    GroupBox("Annual Depreciation Comparison") {
                        Chart {
                            ForEach(DepreciationMethod.allCases.filter { $0 != .macrs }, id: \.self) { method in
                                ForEach(generateMethodData(method: method), id: \.year) { point in
                                    LineMark(
                                        x: .value("Year", point.year),
                                        y: .value("Depreciation", point.depreciation)
                                    )
                                    .foregroundStyle(by: .value("Method", method.displayName))
                                    .interpolationMethod(.stepStart)
                                }
                            }
                        }
                        .frame(height: 300)
                        .chartXAxis {
                            AxisMarks { value in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel {
                                    if let year = value.as(Int.self) {
                                        Text("Year \(year)")
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks { value in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel {
                                    if let depreciation = value.as(Double.self) {
                                        Text(currency.symbol + Formatters.formatAbbreviated(depreciation))
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    
                    // Method comparison table
                    GroupBox("Method Characteristics") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(DepreciationMethod.allCases.filter { $0 != .macrs }, id: \.self) { method in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(method.displayName)
                                            .font(.headline)
                                        Text(method.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(calculateFirstYearDepreciation(method: method))
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.medium)
                                }
                                .padding(.vertical, 4)
                                
                                if method != DepreciationMethod.allCases.last {
                                    Divider()
                                }
                            }
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Method Comparison")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 700, minHeight: 600)
    }
    
    private func generateMethodData(method: DepreciationMethod) -> [MethodComparisonPoint] {
        let tempCalculation = DepreciationCalculation(
            name: "Temp",
            assetCost: assetCost,
            salvageValue: salvageValue,
            usefulLife: usefulLife,
            method: method
        )
        
        let schedule = tempCalculation.generateDepreciationSchedule()
        return schedule.map { entry in
            MethodComparisonPoint(year: entry.year, depreciation: entry.depreciation)
        }
    }
    
    private func calculateFirstYearDepreciation(method: DepreciationMethod) -> String {
        let data = generateMethodData(method: method)
        let firstYear = data.first?.depreciation ?? 0
        return currency.formatValue(firstYear)
    }
}

// MARK: - Supporting Types

struct BookValuePoint {
    let year: Int
    let bookValue: Double
}

struct MethodComparisonPoint {
    let year: Int
    let depreciation: Double
}

#Preview {
    DepreciationCalculatorView()
        .environment(MainViewModel())
        .modelContainer(for: DepreciationCalculation.self, inMemory: true)
        .frame(width: 1200, height: 800)
}