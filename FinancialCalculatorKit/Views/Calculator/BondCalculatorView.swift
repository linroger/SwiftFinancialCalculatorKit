//
//  BondCalculatorView.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import SwiftUI
import SwiftData
import Charts

/// Comprehensive bond pricing and yield analysis calculator
struct BondCalculatorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(MainViewModel.self) private var mainViewModel
    
    @State private var calculation: BondCalculation?
    @State private var calculationName: String = ""
    @State private var faceValue: Double = 1000.0
    @State private var couponRate: Double = 5.0
    @State private var marketRate: Double? = nil
    @State private var currentPrice: Double? = nil
    @State private var yearsToMaturity: Double = 5.0
    @State private var paymentsPerYear: Double = 2.0
    @State private var solveFor: BondSolveFor = .price
    @State private var currency: Currency = .usd
    
    @State private var isCalculating: Bool = false
    @State private var calculationResult: CalculationResult?
    @State private var validationErrors: [String] = []
    @State private var showingSensitivityAnalysis: Bool = false
    @State private var showingCashFlowSchedule: Bool = false
    
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
                    
                    Button("Reset Fields") {
                        resetFields()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingSensitivityAnalysis) {
            if let result = calculationResult {
                SensitivityAnalysisView(
                    baseResult: result,
                    bondData: currentBondData
                )
            }
        }
        .sheet(isPresented: $showingCashFlowSchedule) {
            if let result = calculationResult {
                CashFlowScheduleView(
                    cashFlows: result.chartData ?? [],
                    bondData: currentBondData
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
                    Text("Bond Calculator")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Calculate bond pricing, yield to maturity, and perform sensitivity analysis")
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
                    
                    Text("Bond Analysis Tool")
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
            bondInformationSection
            calculationTypeSection
            settingsSection
        }
        .frame(maxWidth: 500)
    }
    
    @ViewBuilder
    private var bondInformationSection: some View {
        GroupBox("Bond Information") {
            VStack(spacing: 16) {
                calculationNameField
                faceValueField
                couponRateField
                yearsToMaturityField
                paymentFrequencyField
            }
            .padding(16)
        }
        .groupBoxStyle(FinancialGroupBoxStyle())
    }
    
    @ViewBuilder
    private var calculationNameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calculation Name")
                .font(.headline)
                .fontWeight(.medium)
            
            TextField("Enter calculation name", text: $calculationName)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    @ViewBuilder
    private var faceValueField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Face Value (Par Value)")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.plain)
                .help("The amount paid to the bondholder at maturity")
            }
            
            CurrencyInputField(
                title: "Face Value",
                value: Binding(
                    get: { faceValue },
                    set: { 
                        faceValue = max(0, $0 ?? 0)
                        clearResults()
                    }
                ),
                currency: currency,
                isRequired: true,
                helpText: "The amount paid to the bondholder at maturity"
            )
        }
    }
    
    @ViewBuilder
    private var couponRateField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Coupon Rate (Annual %)")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.plain)
                .help("Annual interest rate paid by the bond")
            }
            
            PercentageInputField(
                title: "Coupon Rate",
                value: Binding(
                    get: { couponRate },
                    set: { 
                        if let newValue = $0 { 
                            couponRate = max(0, newValue)
                            clearResults()
                        }
                    }
                ),
                isRequired: true,
                helpText: "Annual interest rate paid by the bond"
            )
        }
    }
    
    @ViewBuilder
    private var yearsToMaturityField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Years to Maturity")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.plain)
                .help("Time until the bond matures")
            }
            
            TextField("Years", value: $yearsToMaturity, format: .number.precision(.fractionLength(1)))
                .textFieldStyle(.roundedBorder)
                .onChange(of: yearsToMaturity) { _, newValue in
                    yearsToMaturity = max(0.1, newValue)
                    clearResults()
                }
        }
    }
    
    @ViewBuilder
    private var paymentFrequencyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Payments Per Year")
                .font(.headline)
                .fontWeight(.medium)
            
            Picker("Payment Frequency", selection: $paymentsPerYear) {
                Text("Annual").tag(1.0)
                Text("Semi-annual").tag(2.0)
                Text("Quarterly").tag(4.0)
                Text("Monthly").tag(12.0)
            }
            .pickerStyle(.segmented)
            .onChange(of: paymentsPerYear) { _, _ in
                clearResults()
            }
        }
    }
    
    @ViewBuilder
    private var calculationTypeSection: some View {
        GroupBox("What to Calculate") {
            VStack(spacing: 16) {
                solveForPicker
                conditionalInputs
            }
            .padding(16)
        }
        .groupBoxStyle(FinancialGroupBoxStyle())
    }
    
    @ViewBuilder
    private var solveForPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Solve For")
                .font(.headline)
                .fontWeight(.medium)
            
            Picker("Solve For", selection: $solveFor) {
                ForEach(BondSolveFor.allCases) { type in
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
            .onChange(of: solveFor) { _, _ in
                clearResults()
            }
        }
    }
    
    @ViewBuilder
    private var conditionalInputs: some View {
        Group {
            if solveFor == .price {
                marketRateField
            }
            
            if solveFor == .yield {
                currentPriceField
            }
        }
    }
    
    @ViewBuilder
    private var marketRateField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Required Yield (Market Rate %)")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.plain)
                .help("The market interest rate for bonds of similar risk")
            }
            
            PercentageInputField(
                title: "Required Yield",
                value: Binding(
                    get: { marketRate },
                    set: { 
                        marketRate = $0
                        clearResults()
                    }
                ),
                isRequired: true,
                helpText: "The market interest rate for bonds of similar risk"
            )
        }
    }
    
    @ViewBuilder
    private var currentPriceField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Current Market Price")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.plain)
                .help("The current trading price of the bond")
            }
            
            CurrencyInputField(
                title: "Current Price",
                value: Binding(
                    get: { currentPrice ?? 0.0 },
                    set: { 
                        currentPrice = max(0, $0 ?? 0)
                        clearResults()
                    }
                ),
                currency: currency,
                isRequired: true,
                helpText: "The current trading price of the bond"
            )
        }
    }
    
    @ViewBuilder
    private var settingsSection: some View {
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
    
    @ViewBuilder
    private var resultSection: some View {
        VStack(spacing: 20) {
            if let result = calculationResult, result.isValid {
                // Primary result
                GroupBox {
                    VStack(spacing: 16) {
                        Text(solveFor.displayName)
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(result.formattedPrimaryValue)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
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
                    GroupBox("Bond Metrics") {
                        VStack(spacing: 12) {
                            ForEach(Array(result.secondaryValues.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                                DetailRow(
                                    title: key,
                                    value: formatSecondaryValue(key: key, value: value),
                                    isHighlighted: key.contains("Yield") || key.contains("Premium") || key.contains("Discount")
                                )
                            }
                        }
                        .padding(16)
                    }
                    .groupBoxStyle(FinancialGroupBoxStyle())
                }
                
                // Quick insights
                GroupBox("Bond Analysis") {
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
                    Button("View Cash Flow Schedule") {
                        showingCashFlowSchedule = true
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    
                    Button("Sensitivity Analysis") {
                        showingSensitivityAnalysis = true
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            } else {
                // Placeholder when no results
                GroupBox {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("Enter bond parameters and calculate to see results")
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
                    title: "Bond Cash Flow Schedule",
                    currency: currency,
                    height: 300
                )
            }
            
            // Yield curve comparison (mock data for demo)
            GroupBox("Market Context") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Yield Curve Comparison")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Chart {
                        ForEach(generateYieldCurveData(), id: \.maturity) { point in
                            LineMark(
                                x: .value("Maturity", point.maturity),
                                y: .value("Yield", point.yield)
                            )
                            .foregroundStyle(.blue)
                            .interpolationMethod(.catmullRom)
                            
                            if abs(point.maturity - yearsToMaturity) < 0.5 {
                                PointMark(
                                    x: .value("Maturity", point.maturity),
                                    y: .value("Yield", point.yield)
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
                                if let years = value.as(Double.self) {
                                    Text("\(Int(years))Y")
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let yield = value.as(Double.self) {
                                    Text("\(yield, specifier: "%.1f")%")
                                }
                            }
                        }
                    }
                    
                    Text("Red dot shows current bond's position on the yield curve")
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
        faceValue > 0 &&
        couponRate >= 0 &&
        yearsToMaturity > 0 &&
        paymentsPerYear > 0 &&
        ((solveFor == .price && marketRate != nil) ||
         (solveFor == .yield && currentPrice != nil))
    }
    
    private var canSave: Bool {
        canCalculate && calculationResult?.isValid == true
    }
    
    private var currentBondData: (faceValue: Double, couponRate: Double, yearsToMaturity: Double, paymentsPerYear: Double) {
        (faceValue, couponRate, yearsToMaturity, paymentsPerYear)
    }
    
    private func performCalculation() {
        guard canCalculate else {
            validateInputs()
            return
        }
        
        isCalculating = true
        validationErrors = []
        
        // Create temporary calculation object
        let tempCalculation = BondCalculation(
            name: calculationName,
            faceValue: faceValue,
            couponRate: couponRate,
            yearsToMaturity: yearsToMaturity,
            paymentsPerYear: paymentsPerYear,
            solveFor: solveFor,
            currency: currency
        )
        
        // Set the appropriate input based on what we're solving for
        if solveFor == .price {
            tempCalculation.marketRate = marketRate
        } else {
            tempCalculation.currentPrice = currentPrice
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
            validationErrors.append("Calculation name is required")
        }
        
        if faceValue <= 0 {
            validationErrors.append("Face value must be positive")
        }
        
        if couponRate < 0 {
            validationErrors.append("Coupon rate cannot be negative")
        }
        
        if yearsToMaturity <= 0 {
            validationErrors.append("Years to maturity must be positive")
        }
        
        if solveFor == .price && marketRate == nil {
            validationErrors.append("Market rate is required to calculate price")
        }
        
        if solveFor == .yield && currentPrice == nil {
            validationErrors.append("Current price is required to calculate yield")
        }
    }
    
    private func clearResults() {
        calculationResult = nil
        validationErrors = []
    }
    
    private func resetFields() {
        calculationName = ""
        faceValue = 1000.0
        couponRate = 5.0
        marketRate = nil
        currentPrice = nil
        yearsToMaturity = 5.0
        paymentsPerYear = 2.0
        solveFor = .price
        clearResults()
    }
    
    private func saveCalculation() {
        guard let result = calculationResult, result.isValid else { return }
        
        let bondCalculation = BondCalculation(
            name: calculationName,
            faceValue: faceValue,
            couponRate: couponRate,
            yearsToMaturity: yearsToMaturity,
            paymentsPerYear: paymentsPerYear,
            solveFor: solveFor,
            currency: currency
        )
        
        if solveFor == .price {
            bondCalculation.marketRate = marketRate
        } else {
            bondCalculation.currentPrice = currentPrice
        }
        
        modelContext.insert(bondCalculation)
        
        do {
            try modelContext.save()
            // Could show success message here
        } catch {
            // Handle save error
            print("Failed to save calculation: \(error)")
        }
    }
    
    private func exportResults() {
        // Implementation for exporting results
        // This would include CSV/PDF export functionality
    }
    
    private func formatSecondaryValue(key: String, value: Double) -> String {
        if key.contains("Rate") || key.contains("Yield") || key.contains("%") {
            return String(format: "%.3f%%", value)
        } else if key.contains("Premium") || key.contains("Discount") || key.contains("Value") || key.contains("Price") || key.contains("Coupon") {
            return currency.formatValue(value)
        } else {
            return Formatters.decimalFormatter(decimalPlaces: 2).string(from: NSNumber(value: value)) ?? "0.00"
        }
    }
    
    private func generateInsights() -> [String] {
        guard let result = calculationResult, result.isValid else { return [] }
        
        var insights: [String] = []
        
        if solveFor == .price {
            if let marketRate = marketRate {
                if result.primaryValue > faceValue {
                    insights.append("Bond trades at a premium (\(currency.formatValue(result.primaryValue - faceValue)) above par)")
                } else if result.primaryValue < faceValue {
                    insights.append("Bond trades at a discount (\(currency.formatValue(faceValue - result.primaryValue)) below par)")
                } else {
                    insights.append("Bond trades at par value")
                }
                
                if couponRate > marketRate {
                    insights.append("Coupon rate exceeds market rate - attractive for income investors")
                } else if couponRate < marketRate {
                    insights.append("Market rate exceeds coupon rate - potential capital appreciation")
                }
            }
        } else if solveFor == .yield {
            if let currentPrice = currentPrice {
                let currentYield = (faceValue * couponRate / 100) / currentPrice * 100
                insights.append("Current yield: \(String(format: "%.2f%%", currentYield))")
                
                if result.primaryValue > currentYield {
                    insights.append("YTM exceeds current yield due to discount to par")
                } else if result.primaryValue < currentYield {
                    insights.append("YTM is below current yield due to premium to par")
                }
            }
        }
        
        if yearsToMaturity > 10 {
            insights.append("Long-term bond - higher interest rate sensitivity")
        } else if yearsToMaturity < 2 {
            insights.append("Short-term bond - lower interest rate risk")
        }
        
        return insights
    }
    
    private func generateYieldCurveData() -> [YieldCurvePoint] {
        // Mock yield curve data for demonstration
        let baseYield = marketRate ?? (currentPrice != nil ? calculationResult?.primaryValue ?? 5.0 : 5.0)
        
        return [
            YieldCurvePoint(maturity: 0.25, yield: baseYield - 1.5),
            YieldCurvePoint(maturity: 0.5, yield: baseYield - 1.2),
            YieldCurvePoint(maturity: 1, yield: baseYield - 0.8),
            YieldCurvePoint(maturity: 2, yield: baseYield - 0.4),
            YieldCurvePoint(maturity: 3, yield: baseYield - 0.2),
            YieldCurvePoint(maturity: 5, yield: baseYield),
            YieldCurvePoint(maturity: 7, yield: baseYield + 0.2),
            YieldCurvePoint(maturity: 10, yield: baseYield + 0.4),
            YieldCurvePoint(maturity: 20, yield: baseYield + 0.6),
            YieldCurvePoint(maturity: 30, yield: baseYield + 0.7)
        ]
    }
}

// MARK: - Supporting Views

struct SensitivityAnalysisView: View {
    let baseResult: CalculationResult
    let bondData: (faceValue: Double, couponRate: Double, yearsToMaturity: Double, paymentsPerYear: Double)
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Interest Rate Sensitivity Analysis")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding()
                    
                    // Price vs Yield chart
                    GroupBox("Bond Price vs Market Yield") {
                        Chart {
                            ForEach(generateSensitivityData(), id: \.yield) { point in
                                LineMark(
                                    x: .value("Yield", point.yield),
                                    y: .value("Price", point.price)
                                )
                                .foregroundStyle(.blue)
                                .interpolationMethod(.catmullRom)
                            }
                        }
                        .frame(height: 300)
                        .chartXAxis {
                            AxisMarks { value in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel {
                                    if let yield = value.as(Double.self) {
                                        Text("\(yield, specifier: "%.1f")%")
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks { value in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel {
                                    if let price = value.as(Double.self) {
                                        Text("$\(Int(price))")
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    
                    // Duration and convexity metrics
                    GroupBox("Risk Metrics") {
                        VStack(alignment: .leading, spacing: 12) {
                            DetailRow(title: "Modified Duration", value: String(format: "%.2f years", calculateModifiedDuration()))
                            DetailRow(title: "Macaulay Duration", value: String(format: "%.2f years", calculateMacaulayDuration()))
                            DetailRow(title: "Convexity", value: String(format: "%.2f", calculateConvexity()))
                            
                            Divider()
                            
                            Text("Duration measures price sensitivity to yield changes. Higher duration = higher price volatility.")
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
    
    private func generateSensitivityData() -> [SensitivityPoint] {
        var data: [SensitivityPoint] = []
        
        for i in stride(from: 1.0, through: 10.0, by: 0.5) {
            let price = CalculationEngine.calculateBondPrice(
                faceValue: bondData.faceValue,
                couponRate: bondData.couponRate,
                marketRate: i,
                yearsToMaturity: bondData.yearsToMaturity,
                paymentsPerYear: bondData.paymentsPerYear
            )
            data.append(SensitivityPoint(yield: i, price: price))
        }
        
        return data
    }
    
    private func calculateModifiedDuration() -> Double {
        // Simplified duration calculation
        return bondData.yearsToMaturity * 0.8
    }
    
    private func calculateMacaulayDuration() -> Double {
        // Simplified duration calculation
        return bondData.yearsToMaturity * 0.85
    }
    
    private func calculateConvexity() -> Double {
        // Simplified convexity calculation
        return bondData.yearsToMaturity * bondData.yearsToMaturity * 0.1
    }
}

struct CashFlowScheduleView: View {
    let cashFlows: [ChartDataPoint]
    let bondData: (faceValue: Double, couponRate: Double, yearsToMaturity: Double, paymentsPerYear: Double)
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary
                    GroupBox("Cash Flow Summary") {
                        VStack(alignment: .leading, spacing: 12) {
                            DetailRow(title: "Total Coupon Payments", value: "\(Int(bondData.yearsToMaturity * bondData.paymentsPerYear))")
                            DetailRow(title: "Coupon per Payment", value: String(format: "$%.2f", bondData.faceValue * bondData.couponRate / 100 / bondData.paymentsPerYear))
                            DetailRow(title: "Total Interest", value: String(format: "$%.2f", bondData.faceValue * bondData.couponRate / 100 * bondData.yearsToMaturity))
                            DetailRow(title: "Principal at Maturity", value: String(format: "$%.2f", bondData.faceValue))
                        }
                        .padding()
                    }
                    
                    // Cash flow table
                    GroupBox("Payment Schedule") {
                        Table(cashFlows) {
                            TableColumn("Period") { flow in
                                Text("\(flow.x, specifier: "%.1f")")
                            }
                            .width(80)
                            
                            TableColumn("Payment Type") { flow in
                                Text(flow.label ?? "Coupon")
                            }
                            .width(150)
                            
                            TableColumn("Amount") { flow in
                                Text("$\(flow.y, specifier: "%.2f")")
                                    .font(.system(.body, design: .monospaced))
                            }
                            .width(120)
                        }
                        .frame(height: 300)
                    }
                }
                .padding()
            }
            .navigationTitle("Cash Flow Schedule")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

// MARK: - Supporting Types

struct YieldCurvePoint {
    let maturity: Double
    let yield: Double
}

struct SensitivityPoint {
    let yield: Double
    let price: Double
}

#Preview {
    BondCalculatorView()
        .environment(MainViewModel())
        .modelContainer(for: BondCalculation.self, inMemory: true)
        .frame(width: 1200, height: 800)
}