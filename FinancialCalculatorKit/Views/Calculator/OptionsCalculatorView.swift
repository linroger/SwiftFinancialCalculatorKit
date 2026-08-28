//
//  OptionsCalculatorView.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/9/25.
//

import SwiftUI
import SwiftData
import Charts
import LaTeXSwiftUI

/// Advanced options pricing calculator using Black-Scholes model
struct OptionsCalculatorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(MainViewModel.self) private var mainViewModel
    
    @State private var calculation: OptionsCalculation?
    @State private var calculationName: String = ""
    @State private var spotPrice: Double = 100.0
    @State private var strikePrice: Double = 100.0
    @State private var timeToExpiry: Double = 0.25 // 3 months
    @State private var riskFreeRate: Double = 5.0
    @State private var volatility: Double = 20.0
    @State private var optionType: CalculationEngine.OptionType = .call
    @State private var currency: Currency = .usd
    
    @State private var calculationResult: CalculationResult?
    @State private var validationErrors: [String] = []
    @State private var showingGreeksAnalysis: Bool = false
    @State private var showingVolatilitySurface: Bool = false
    
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
                    
                    Button("Greeks Analysis") {
                        showingGreeksAnalysis = true
                    }
                    .disabled(calculationResult == nil)
                    
                    Button("Volatility Surface") {
                        showingVolatilitySurface = true
                    }
                    .disabled(calculationResult == nil)
                    
                    Divider()
                    
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
        .sheet(isPresented: $showingGreeksAnalysis) {
            if let result = calculationResult {
                GreeksAnalysisView(
                    baseResult: result,
                    optionData: currentOptionData
                )
            }
        }
        .sheet(isPresented: $showingVolatilitySurface) {
            if let result = calculationResult {
                VolatilitySurfaceView(
                    baseResult: result,
                    optionData: currentOptionData
                )
            }
        }
        .onAppear {
            currency = mainViewModel.userPreferences.defaultCurrency
            restorePendingCalculation()
        }
        .onChange(of: mainViewModel.pendingLoadID) { _, _ in
            restorePendingCalculation()
        }
    }

    /// Restore a saved option the user opened from the sidebar or dashboard.
    private func restorePendingCalculation() {
        guard let id = mainViewModel.takePendingLoadID(for: .options) else { return }

        var descriptor = FetchDescriptor<OptionsCalculation>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let saved = try? modelContext.fetch(descriptor).first else { return }

        calculationName = saved.name
        spotPrice = saved.spotPrice
        strikePrice = saved.strikePrice
        timeToExpiry = saved.timeToExpiry
        riskFreeRate = saved.riskFreeRate
        volatility = saved.volatility
        optionType = saved.optionType
        currency = saved.currency

        calculation = saved
        calculationResult = saved.result
        validationErrors = []
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Options Calculator")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Black-Scholes options pricing model with Greeks analysis")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if calculationResult != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    
                    Text("Advanced Derivatives Pricing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Black-Scholes Formula Display
            LaTeX("$$C = S_0 \\cdot N(d_1) - K \\cdot e^{-rT} \\cdot N(d_2)$$")
                .frame(height: 40)
                .padding(.vertical, 8)
            
            LaTeX("where $d_1 = \\frac{\\ln(S_0/K) + (r + \\sigma^2/2)T}{\\sigma\\sqrt{T}}$ and $d_2 = d_1 - \\sigma\\sqrt{T}$")
                .font(.caption)
                .foregroundColor(.secondary)
            
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
            // Basic option parameters
            GroupBox("Option Parameters") {
                VStack(spacing: 16) {
                    // Calculation name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calculation Name")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        TextField("Enter calculation name", text: $calculationName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Option type
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Option Type")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Picker("Option Type", selection: $optionType) {
                            Text("Call Option").tag(CalculationEngine.OptionType.call)
                            Text("Put Option").tag(CalculationEngine.OptionType.put)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: optionType) { _, _ in
                            clearResults()
                        }
                    }
                    
                    // Spot price
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Current Stock Price (S₀)")
                                .font(.headline)
                                .fontWeight(.medium)

                            Spacer()

                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.secondary)
                                .help("Current market price of the underlying asset")
                        }
                        
                        CurrencyInputField(
                            value: Binding(
                                get: { spotPrice },
                                set: { 
                                    spotPrice = max(0, $0)
                                    clearResults()
                                }
                            ),
                            currency: currency,
                            placeholder: "Spot Price"
                        )
                    }
                    
                    // Strike price
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Strike Price (K)")
                                .font(.headline)
                                .fontWeight(.medium)

                            Spacer()

                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.secondary)
                                .help("Exercise price of the option")
                        }
                        
                        CurrencyInputField(
                            value: Binding(
                                get: { strikePrice },
                                set: { 
                                    strikePrice = max(0, $0)
                                    clearResults()
                                }
                            ),
                            currency: currency,
                            placeholder: "Strike Price"
                        )
                    }
                    
                    // Time to expiry
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Time to Expiry (Years)")
                                .font(.headline)
                                .fontWeight(.medium)

                            Spacer()

                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.secondary)
                                .help("Time remaining until option expiration")
                        }
                        
                        TextField("Years", value: $timeToExpiry, format: .number.precision(.fractionLength(4)))
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: timeToExpiry) { _, newValue in
                                timeToExpiry = max(0.0001, newValue)
                                clearResults()
                            }
                    }
                }
                .padding(16)
            }
            .groupBoxStyle(FinancialGroupBoxStyle())
            
            // Market parameters
            GroupBox("Market Parameters") {
                VStack(spacing: 16) {
                    // Risk-free rate
                    PercentageInputField(
                        title: "Risk-Free Rate",
                        value: Binding(
                            get: { riskFreeRate },
                            set: {
                                if let newValue = $0 {
                                    riskFreeRate = max(0, newValue)
                                    clearResults()
                                }
                            }
                        ),
                        isRequired: true,
                        helpText: "Risk-free interest rate (e.g., Treasury rate)"
                    )

                    // Volatility
                    PercentageInputField(
                        title: "Volatility (σ)",
                        value: Binding(
                            get: { volatility },
                            set: {
                                if let newValue = $0 {
                                    volatility = max(0, newValue)
                                    clearResults()
                                }
                            }
                        ),
                        isRequired: true,
                        helpText: "Annualized volatility of the underlying asset"
                    )
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
        .frame(maxWidth: 500)
    }
    
    @ViewBuilder
    private var resultSection: some View {
        VStack(spacing: 20) {
            if let result = calculationResult {
                // Primary result - Option Price
                GroupBox {
                    VStack(spacing: 16) {
                        Text("\(optionType == .call ? "Call" : "Put") Option Price")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(currency.formatValue(result.primaryValue))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Black-Scholes theoretical value")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        // Moneyness indicator
                        HStack {
                            let moneyness = getMoneyness()
                            Image(systemName: getMoneynessSFSymbol(moneyness))
                                .foregroundColor(getMoneynesColor(moneyness))
                            
                            Text(moneyness)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(getMoneynesColor(moneyness))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(getMoneynesColor(getMoneyness()).opacity(0.1))
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
                .groupBoxStyle(FinancialGroupBoxStyle())
                
                GroupBox("Option Greeks") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        OptionGreekMetricCard(
                            title: "Delta",
                            subtitle: "Directional exposure",
                            value: result.secondaryValues["Delta"] ?? 0,
                            format: "%.4f"
                        )
                        OptionGreekMetricCard(
                            title: "Gamma",
                            subtitle: "Delta acceleration",
                            value: result.secondaryValues["Gamma"] ?? 0,
                            format: "%.6f"
                        )
                        OptionGreekMetricCard(
                            title: "Theta",
                            subtitle: "Daily decay",
                            value: result.secondaryValues["Theta"] ?? 0,
                            format: "%.4f"
                        )
                        OptionGreekMetricCard(
                            title: "Vega",
                            subtitle: "1 vol-point move",
                            value: result.secondaryValues["Vega"] ?? 0,
                            format: "%.4f"
                        )
                        OptionGreekMetricCard(
                            title: "Rho",
                            subtitle: "1 rate-point move",
                            value: result.secondaryValues["Rho"] ?? 0,
                            format: "%.4f"
                        )
                    }
                    .padding(16)
                }
                .groupBoxStyle(FinancialGroupBoxStyle())
                
                // Risk Metrics
                GroupBox("Risk Analysis") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(generateRiskInsights(result: result), id: \.self) { insight in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
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
                    Button("Greeks Analysis") {
                        showingGreeksAnalysis = true
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    
                    Button("Volatility Surface") {
                        showingVolatilitySurface = true
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
                        
                        Text("Enter option parameters and calculate to see pricing")
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
            // Option price sensitivity chart
            if let chartData = calculationResult?.chartData, !chartData.isEmpty {
                 FinancialChartView(
                    data: chartData,
                    chartType: .line,
                    title: "Price Sensitivity",
                    currency: currency,
                    height: 250
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var canCalculate: Bool {
        !calculationName.isEmpty &&
        spotPrice > 0 &&
        strikePrice > 0 &&
        timeToExpiry > 0 &&
        riskFreeRate >= 0 &&
        volatility > 0
    }
    
    private var canSave: Bool {
        canCalculate && calculationResult != nil
    }
    
    private var currentOptionData: (spotPrice: Double, strikePrice: Double, timeToExpiry: Double, riskFreeRate: Double, volatility: Double, optionType: CalculationEngine.OptionType) {
        (spotPrice, strikePrice, timeToExpiry, riskFreeRate, volatility, optionType)
    }
    
    private func performCalculation() {
        guard canCalculate else {
            validateInputs()
            return
        }
        
        validationErrors = []

        let tempCalculation = OptionsCalculation(
            name: calculationName,
            spotPrice: spotPrice,
            strikePrice: strikePrice,
            timeToExpiry: timeToExpiry,
            riskFreeRate: riskFreeRate,
            volatility: volatility,
            optionType: optionType,
            currency: currency
        )

        calculationResult = tempCalculation.result
        if !tempCalculation.isValid {
            validationErrors = tempCalculation.validationErrors
        } else {
            calculation = tempCalculation
        }
    }
    
    private func validateInputs() {
        validationErrors = []
        if calculationName.isEmpty { validationErrors.append("Calculation name is required") }
        if spotPrice <= 0 { validationErrors.append("Spot price must be positive") }
        if strikePrice <= 0 { validationErrors.append("Strike price must be positive") }
        if timeToExpiry <= 0 { validationErrors.append("Time to expiry must be positive") }
        if volatility <= 0 { validationErrors.append("Volatility must be positive") }
    }
    
    private func clearResults() {
        calculationResult = nil
        validationErrors = []
    }
    
    private func resetFields() {
        calculationName = ""
        spotPrice = 100.0
        strikePrice = 100.0
        timeToExpiry = 0.25
        riskFreeRate = 5.0
        volatility = 20.0
        optionType = .call
        clearResults()
    }
    
    private func exportResults() {
        guard let result = calculationResult else { return }
        do {
            _ = try CalculationExporter.exportResult(
                suggestedName: calculationName.isEmpty ? "Options Calculation" : calculationName,
                primaryLabel: "Option Premium",
                result: result
            )
        } catch {
            mainViewModel.handleError(.dataExportFailed(error.localizedDescription))
        }
    }

    private func saveCalculation() {
        guard let calc = calculation, calc.isValid else { return }
        // The name field doesn't invalidate results, so pick up its latest value here
        calc.name = calculationName.isEmpty ? calc.name : calculationName
        calc.updateTimestamp()
        modelContext.insert(calc)
        do {
            try modelContext.save()
        } catch {
            mainViewModel.handleError(.fileAccessError("Failed to save calculation: \(error.localizedDescription)"))
        }
    }
    
    private func getMoneyness() -> String {
        if optionType == .call {
            if spotPrice > strikePrice * 1.05 { return "In-the-Money" }
            else if spotPrice < strikePrice * 0.95 { return "Out-of-the-Money" }
            else { return "At-the-Money" }
        } else {
            if spotPrice < strikePrice * 0.95 { return "In-the-Money" }
            else if spotPrice > strikePrice * 1.05 { return "Out-of-the-Money" }
            else { return "At-the-Money" }
        }
    }
    
    private func getMoneynessSFSymbol(_ moneyness: String) -> String {
        switch moneyness {
        case "In-the-Money": return "arrow.up.circle.fill"
        case "Out-of-the-Money": return "arrow.down.circle.fill"
        default: return "minus.circle.fill"
        }
    }
    
    private func getMoneynesColor(_ moneyness: String) -> Color {
        switch moneyness {
        case "In-the-Money": return .green
        case "Out-of-the-Money": return .red
        default: return .orange
        }
    }
    
    private func generateRiskInsights(result: CalculationResult) -> [String] {
        var insights: [String] = []
        
        if let delta = result.secondaryValues["Delta"], abs(delta) > 0.7 {
            insights.append("High delta indicates strong correlation with underlying price movements")
        }
        
        if let gamma = result.secondaryValues["Gamma"], gamma > 0.05 {
            insights.append("High gamma suggests delta will change rapidly with price movements")
        }

        if let theta = result.secondaryValues["Theta"], theta < -0.10 {
            insights.append("Time decay is steep. Holding this option without conviction can be expensive.")
        }

        if let vega = result.secondaryValues["Vega"], vega > 0.20 {
            insights.append("The option is highly sensitive to volatility repricing.")
        }
        
        if timeToExpiry < 0.083 { // Less than 1 month
            insights.append("Short time to expiry increases time decay risk")
        }
        
        return insights
    }
}

#Preview {
    OptionsCalculatorView()
        .environment(MainViewModel())
        .frame(width: 1200, height: 800)
}
