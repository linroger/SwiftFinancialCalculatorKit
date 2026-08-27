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
    
    @State private var calculationName: String = ""
    @State private var faceValue: Double = 1000.0
    @State private var couponRate: Double = 5.0
    @State private var marketRate: Double? = nil
    @State private var currentPrice: Double? = nil
    @State private var yearsToMaturity: Double = 5.0
    @State private var paymentsPerYear: Double = 2.0
    @State private var solveFor: BondSolveFor = .price
    @State private var currency: Currency = .usd
    
    @State private var calculationResult: CalculationResult?
    @State private var validationErrors: [String] = []
    @State private var showingSensitivityAnalysis: Bool = false
    @State private var showingCashFlowSchedule: Bool = false
    @State private var showingSaveConfirmation: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                
                HStack(alignment: .top, spacing: 24) {
                    inputSection
                    resultSection
                }
                
                if hasSolution {
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
                .help("More actions")
                .accessibilityLabel("More Actions")
            }
        }
        .sheet(isPresented: $showingSensitivityAnalysis) {
            if let result = calculationResult {
                SensitivityAnalysisView(
                    baseResult: result,
                    bondData: currentBondData,
                    currency: currency
                )
            }
        }
        .sheet(isPresented: $showingCashFlowSchedule) {
            if let result = calculationResult {
                CashFlowScheduleView(
                    cashFlows: result.chartData ?? [],
                    bondData: currentBondData,
                    currency: currency
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
                    if hasSolution {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }

                    if showingSaveConfirmation {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                            .transition(.opacity)
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
        CurrencyInputField(
            title: "Face Value (Par Value)",
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

    @ViewBuilder
    private var couponRateField: some View {
        PercentageInputField(
            title: "Coupon Rate (Annual)",
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
    
    @ViewBuilder
    private var yearsToMaturityField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Years to Maturity")
                    .font(.headline)
                    .fontWeight(.medium)

                Spacer()

                Image(systemName: "questionmark.circle")
                    .foregroundColor(.secondary)
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
        PercentageInputField(
            title: "Required Yield (Market Rate)",
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

    @ViewBuilder
    private var currentPriceField: some View {
        CurrencyInputField(
            title: "Current Market Price",
            value: Binding(
                get: { currentPrice },
                set: {
                    currentPrice = $0.map { max(0, $0) }
                    clearResults()
                }
            ),
            currency: currency,
            isRequired: true,
            helpText: "The current trading price of the bond"
        )
    }
    
    @ViewBuilder
    private var settingsSection: some View {
        GroupBox("Settings") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Currency")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Picker("Currency", selection: $currency) {
                    ForEach(Currency.allCases) { curr in
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
                
                // Action buttons — only meaningful when a real solution exists
                if hasSolution {
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
            
            GroupBox("Rate Shock Profile") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Bond Price Under Rate Shocks")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Chart {
                        ForEach(generateRateShockData(), id: \.shockBps) { point in
                            LineMark(
                                x: .value("Shock", point.shockBps),
                                y: .value("Price", point.price)
                            )
                            .foregroundStyle(.blue)
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let shock = value.as(Double.self) {
                                    Text("\(Int(shock))bp")
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
                                    Text(currency.formatValue(price))
                                }
                            }
                        }
                    }
                    
                    Text("This chart uses actual repricing at each shocked market rate, so it reflects the bond's non-linear response rather than a generic sample curve.")
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
        canCalculate && hasSolution
    }

    /// True when the current result is a real solved value — the "No solution"
    /// sentinel passes `isValid` but carries no secondary values.
    private var hasSolution: Bool {
        guard let result = calculationResult else { return false }
        return result.isValid && !result.secondaryValues.isEmpty
    }
    
    private var currentBondData: (faceValue: Double, couponRate: Double, yearsToMaturity: Double, paymentsPerYear: Double) {
        (faceValue, couponRate, yearsToMaturity, paymentsPerYear)
    }
    
    private func performCalculation() {
        guard canCalculate else {
            validateInputs()
            return
        }
        
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
        calculationResult = tempCalculation.result

        if calculationResult?.isValid != true {
            validationErrors = tempCalculation.validationErrors
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
        
        bondCalculation.updateTimestamp()
        modelContext.insert(bondCalculation)

        do {
            try modelContext.save()
            withAnimation {
                showingSaveConfirmation = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showingSaveConfirmation = false
                }
            }
        } catch {
            mainViewModel.handleError(.dataExportFailed("Failed to save calculation: \(error.localizedDescription)"))
        }
    }

    private func exportResults() {
        guard let result = calculationResult else { return }

        do {
            try CalculationExporter.exportResult(
                suggestedName: calculationName.isEmpty ? "Bond Analysis" : calculationName,
                primaryLabel: solveFor.displayName,
                result: result
            )
        } catch {
            mainViewModel.handleError(.dataExportFailed("Failed to export results: \(error.localizedDescription)"))
        }
    }

    private func formatSecondaryValue(key: String, value: Double) -> String {
        if key == "Total Payments" {
            return String(format: "%.0f", value)
        } else if key.contains("Rate") || key.contains("Yield") || key.contains("%") {
            return String(format: "%.3f%%", value)
        } else if key.contains("Premium") || key.contains("Discount") || key.contains("Value") || key.contains("Price") || key.contains("Coupon") {
            return currency.formatValue(value)
        } else {
            return Formatters.decimalFormatter(decimalPlaces: 2).string(from: NSNumber(value: value)) ?? "0.00"
        }
    }
    
    private func generateInsights() -> [String] {
        guard hasSolution, let result = calculationResult else { return [] }
        
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
    
    private func generateRateShockData() -> [RateShockPoint] {
        let baseYield = marketRate ?? calculationResult?.primaryValue ?? couponRate

        return stride(from: -200.0, through: 200.0, by: 50.0).map { shock in
            let shockedYield = max(baseYield + (shock / 100), 0.01)
            let price = CalculationEngine.calculateBondPrice(
                faceValue: faceValue,
                couponRate: couponRate,
                marketRate: shockedYield,
                yearsToMaturity: yearsToMaturity,
                paymentsPerYear: paymentsPerYear
            )
            return RateShockPoint(shockBps: shock, price: price)
        }
    }
}

// MARK: - Supporting Views

struct SensitivityAnalysisView: View {
    let baseResult: CalculationResult
    let bondData: (faceValue: Double, couponRate: Double, yearsToMaturity: Double, paymentsPerYear: Double)
    let currency: Currency
    @Environment(\.dismiss) private var dismiss

    private struct SensitivityPoint: Identifiable {
        let id = UUID()
        let shockBps: Double
        let repriced: Double
        let estimated: Double
    }

    private var referenceYield: Double {
        baseResult.secondaryValues["Market Rate"] ?? baseResult.primaryValue
    }

    private var currentPrice: Double {
        baseResult.secondaryValues["Current Price"] ?? baseResult.primaryValue
    }

    private var riskMeasures: CalculationEngine.BondRiskMeasures {
        CalculationEngine.calculateBondRiskMeasures(
            faceValue: bondData.faceValue,
            couponRate: bondData.couponRate,
            marketRate: referenceYield,
            yearsToMaturity: bondData.yearsToMaturity,
            paymentsPerYear: bondData.paymentsPerYear
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Interest Rate Sensitivity Analysis")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding()

                    GroupBox("Repricing vs Duration+Convexity Estimate") {
                        Chart {
                            ForEach(generateSensitivityData()) { point in
                                LineMark(
                                    x: .value("Shock", point.shockBps),
                                    y: .value("Actual Repricing", point.repriced)
                                )
                                .foregroundStyle(.blue)
                                .interpolationMethod(.catmullRom)

                                LineMark(
                                    x: .value("Shock", point.shockBps),
                                    y: .value("Estimated", point.estimated)
                                )
                                .foregroundStyle(.orange)
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                            }
                        }
                        .frame(height: 300)
                        .chartXAxis {
                            AxisMarks { value in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel {
                                    if let shock = value.as(Double.self) {
                                        Text("\(Int(shock))bp")
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
                                        Text(currency.formatValue(price))
                                    }
                                }
                            }
                        }
                        .padding()
                    }

                    GroupBox("Risk Metrics") {
                        VStack(alignment: .leading, spacing: 12) {
                            DetailRow(title: "Modified Duration", value: String(format: "%.2f years", riskMeasures.modifiedDuration))
                            DetailRow(title: "Macaulay Duration", value: String(format: "%.2f years", riskMeasures.macaulayDuration))
                            DetailRow(title: "Convexity", value: String(format: "%.2f", riskMeasures.convexity))

                            Divider()

                            Text("Blue is the actual repriced bond. Orange is the duration-plus-convexity approximation, which is often how risk desks estimate shock sensitivity before a full repricing run.")
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
        .frame(minWidth: 720, minHeight: 560)
    }

    private func generateSensitivityData() -> [SensitivityPoint] {
        stride(from: -200.0, through: 200.0, by: 25.0).map { shock in
            let shockedYield = max(referenceYield + (shock / 100), 0.01)
            let repriced = CalculationEngine.calculateBondPrice(
                faceValue: bondData.faceValue,
                couponRate: bondData.couponRate,
                marketRate: shockedYield,
                yearsToMaturity: bondData.yearsToMaturity,
                paymentsPerYear: bondData.paymentsPerYear
            )
            let estimatedChange = CalculationEngine.estimateBondPriceChange(
                currentPrice: currentPrice,
                modifiedDuration: riskMeasures.modifiedDuration,
                convexity: riskMeasures.convexity,
                yieldChange: shock / 10000
            )

            return SensitivityPoint(
                shockBps: shock,
                repriced: repriced,
                estimated: currentPrice + estimatedChange
            )
        }
    }
}

struct CashFlowScheduleView: View {
    let cashFlows: [ChartDataPoint]
    let bondData: (faceValue: Double, couponRate: Double, yearsToMaturity: Double, paymentsPerYear: Double)
    let currency: Currency
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary
                    GroupBox("Cash Flow Summary") {
                        VStack(alignment: .leading, spacing: 12) {
                            DetailRow(title: "Number of Coupon Payments", value: "\(Int(bondData.yearsToMaturity * bondData.paymentsPerYear))")
                            DetailRow(title: "Coupon per Payment", value: currency.formatValue(bondData.faceValue * bondData.couponRate / 100 / bondData.paymentsPerYear))
                            DetailRow(title: "Total Interest", value: currency.formatValue(bondData.faceValue * bondData.couponRate / 100 * bondData.yearsToMaturity))
                            DetailRow(title: "Principal at Maturity", value: currency.formatValue(bondData.faceValue))
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
                                Text(currency.formatValue(flow.y))
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

struct RateShockPoint {
    let shockBps: Double
    let price: Double
}

#Preview {
    BondCalculatorView()
        .environment(MainViewModel())
        .modelContainer(for: BondCalculation.self, inMemory: true)
        .frame(width: 1200, height: 800)
}
