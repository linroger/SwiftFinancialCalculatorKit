//
//  LoanCalculatorView.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import SwiftUI
import SwiftData

/// Comprehensive loan calculator with amortization schedule and charts
struct LoanCalculatorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(MainViewModel.self) private var mainViewModel
    
    @State private var calculation: LoanCalculation?
    @State private var calculationName: String = ""
    @State private var principalAmount: Double? = nil
    @State private var annualInterestRate: Double? = nil
    @State private var loanTermYears: Double? = nil
    @State private var downPayment: Double? = nil
    @State private var extraPayment: Double? = nil
    @State private var paymentFrequency: PaymentFrequency = .monthly
    @State private var loanType: LoanType = .standardLoan
    @State private var currency: Currency = .usd
    
    @State private var isCalculating: Bool = false
    @State private var calculationResult: CalculationResult?
    @State private var validationErrors: [String] = []
    @State private var showAmortizationTable: Bool = false
    
    private var isMortgage: Bool {
        loanType == .mortgage
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                
                HStack(alignment: .top, spacing: 24) {
                    inputSection
                    resultSection
                }
                
                if showAmortizationTable, let result = calculationResult, let tableData = result.tableData {
                    AmortizationTableView(
                        tableData: tableData,
                        currency: currency
                    )
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
                
                if calculationResult != nil {
                    Button(showAmortizationTable ? "Hide Schedule" : "Show Schedule") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showAmortizationTable.toggle()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Button("Save") {
                    saveCalculation()
                }
                .disabled(calculationResult == nil || calculationName.isEmpty)
                
                Button("Clear") {
                    clearAll()
                }
                .buttonStyle(.bordered)
            }
        }
        .onAppear {
            loadUserPreferences()
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isMortgage ? "Mortgage Calculator" : "Loan Calculator")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(isMortgage ? 
                         "Calculate mortgage payments, total interest, and create detailed amortization schedules for home loans." :
                         "Calculate loan payments, interest costs, and payment schedules for various types of loans.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    Picker("Loan Type", selection: $loanType) {
                        ForEach(LoanType.allCases) { type in
                            Text(type.displayName)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                    
                    HStack(spacing: 8) {
                        Text("Currency:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Currency", selection: $currency) {
                            ForEach(Currency.allCases.prefix(8)) { curr in
                                Text("\(curr.symbol) \(curr.rawValue)")
                                    .tag(curr)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                    }
                }
            }
            
            if !validationErrors.isEmpty {
                ErrorBanner(errors: validationErrors)
            }
        }
    }
    
    @ViewBuilder
    private var inputSection: some View {
        VStack(spacing: 20) {
            GroupBox("Loan Details") {
                VStack(spacing: 16) {
                    InputFieldView(
                        title: "Calculation Name",
                        value: $calculationName,
                        placeholder: isMortgage ? "My Mortgage Calculation" : "My Loan Calculation",
                        validation: .required,
                        helpText: "Give this calculation a descriptive name for easy reference",
                        isRequired: true
                    )
                    
                    CurrencyInputField(
                        title: isMortgage ? "Home Price" : "Loan Amount",
                        subtitle: isMortgage ? "Total purchase price" : "Principal amount borrowed",
                        value: $principalAmount,
                        currency: currency,
                        isRequired: true,
                        helpText: isMortgage ? "The total purchase price of the home" : "The total amount you want to borrow"
                    )
                    
                    if isMortgage {
                        CurrencyInputField(
                            title: "Down Payment",
                            subtitle: "Initial payment amount",
                            value: $downPayment,
                            currency: currency,
                            helpText: "The amount you pay upfront (typically 10-20% of home price)"
                        )
                    }
                    
                    PercentageInputField(
                        title: "Annual Interest Rate",
                        subtitle: "APR (Annual Percentage Rate)",
                        value: $annualInterestRate,
                        isRequired: true,
                        helpText: "The annual interest rate charged by the lender"
                    )
                    
                    InputFieldView(
                        title: "Loan Term",
                        subtitle: "Repayment period in years",
                        value: Binding(
                            get: { loanTermYears?.description ?? "" },
                            set: { loanTermYears = Double($0) }
                        ),
                        placeholder: isMortgage ? "30" : "5",
                        keyboardType: .decimalPad,
                        validation: .positiveNumber,
                        helpText: "The number of years to repay the loan",
                        isRequired: true
                    )
                    
                    Picker("Payment Frequency", selection: $paymentFrequency) {
                        ForEach(PaymentFrequency.allCases.filter { $0 != .daily && $0 != .weekly }) { freq in
                            Text(freq.displayName)
                                .tag(freq)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    CurrencyInputField(
                        title: "Extra Payment",
                        subtitle: "Additional amount per payment",
                        value: $extraPayment,
                        currency: currency,
                        helpText: "Additional amount to pay each period to reduce principal faster"
                    )
                }
                .padding(16)
            }
            .groupBoxStyle(FinancialGroupBoxStyle())
        }
        .frame(maxWidth: 400)
    }
    
    @ViewBuilder
    private var resultSection: some View {
        VStack(spacing: 20) {
            if isCalculating {
                LoadingResultView()
            } else if let result = calculationResult {
                ResultDisplayView(
                    result: result,
                    currency: currency
                )
                
                // Quick summary cards
                quickSummaryCards
                
            } else {
                placeholderResultView
            }
            
            // Loan insights
            LoanInsightsView(
                principalAmount: principalAmount ?? 0,
                interestRate: annualInterestRate ?? 0,
                termYears: loanTermYears ?? 0,
                isMortgage: isMortgage
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var quickSummaryCards: some View {
        if let result = calculationResult {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                SummaryCard(
                    title: "Total Interest",
                    value: result.secondaryValues["Total Interest"] ?? 0,
                    currency: currency,
                    icon: "percent",
                    color: .orange
                )
                
                SummaryCard(
                    title: "Total Payments",
                    value: result.secondaryValues["Total Payments"] ?? 0,
                    currency: currency,
                    icon: "dollarsign.circle",
                    color: .blue
                )
                
                if let timeWithExtra = result.secondaryValues["Time Saved (Years)"], timeWithExtra > 0 {
                    SummaryCard(
                        title: "Time Saved",
                        value: timeWithExtra,
                        currency: currency,
                        icon: "clock.arrow.circlepath",
                        color: .green,
                        isTime: true
                    )
                    
                    SummaryCard(
                        title: "Interest Saved",
                        value: result.secondaryValues["Interest Saved"] ?? 0,
                        currency: currency,
                        icon: "minus.circle",
                        color: .green
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var placeholderResultView: some View {
        VStack(spacing: 16) {
            Image(systemName: isMortgage ? "house" : "creditcard")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
            
            Text("Enter loan details and tap Calculate")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(isMortgage ? 
                 "Fill in your mortgage details above to calculate monthly payments and see the amortization schedule." :
                 "Fill in your loan details above to calculate payments and total interest costs.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var canCalculate: Bool {
        return principalAmount != nil &&
               annualInterestRate != nil &&
               loanTermYears != nil &&
               !calculationName.isEmpty
    }
    
    private func performCalculation() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isCalculating = true
            validationErrors = []
        }
        
        guard let principal = principalAmount,
              let rate = annualInterestRate,
              let term = loanTermYears else {
            validationErrors = ["Please fill in all required fields"]
            isCalculating = false
            return
        }
        
        // Create a temporary calculation for validation and result computation
        let tempCalculation = LoanCalculation(
            name: calculationName,
            principalAmount: principal,
            annualInterestRate: rate,
            loanTermYears: term,
            paymentFrequency: paymentFrequency,
            downPayment: downPayment ?? 0,
            extraPayment: extraPayment ?? 0,
            loanType: loanType,
            currency: currency
        )
        
        // Simulate calculation delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isCalculating = false
                
                if tempCalculation.isValid {
                    calculationResult = tempCalculation.result
                    calculation = tempCalculation
                } else {
                    validationErrors = tempCalculation.validationErrors
                    calculationResult = nil
                }
            }
        }
    }
    
    private func saveCalculation() {
        guard let calc = calculation else { return }
        
        modelContext.insert(calc)
        
        do {
            try modelContext.save()
            
            // Show success feedback
            withAnimation(.easeInOut(duration: 0.2)) {
                // Could add a success indicator here
            }
        } catch {
            mainViewModel.handleError(.dataExportFailed("Failed to save calculation: \(error.localizedDescription)"))
        }
    }
    
    private func clearAll() {
        withAnimation(.easeInOut(duration: 0.3)) {
            principalAmount = nil
            annualInterestRate = nil
            loanTermYears = nil
            downPayment = nil
            extraPayment = nil
            calculationResult = nil
            validationErrors = []
            calculationName = ""
            showAmortizationTable = false
        }
    }
    
    private func loadUserPreferences() {
        currency = mainViewModel.userPreferences.defaultCurrency
        paymentFrequency = mainViewModel.userPreferences.defaultPaymentFrequency
    }
}

/// Summary card component for key metrics
struct SummaryCard: View {
    let title: String
    let value: Double
    let currency: Currency
    let icon: String
    let color: Color
    let isTime: Bool
    
    init(title: String, value: Double, currency: Currency, icon: String, color: Color, isTime: Bool = false) {
        self.title = title
        self.value = value
        self.currency = currency
        self.icon = icon
        self.color = color
        self.isTime = isTime
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedValue)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var formattedValue: String {
        if isTime {
            let years = Int(value)
            let months = Int((value - Double(years)) * 12)
            if years > 0 && months > 0 {
                return "\(years)y \(months)m"
            } else if years > 0 {
                return "\(years) years"
            } else {
                return "\(months) months"
            }
        } else {
            return currency.formatValue(value)
        }
    }
}

/// Amortization table view with pagination
struct AmortizationTableView: View {
    let tableData: [TableRow]
    let currency: Currency
    
    @State private var currentPage: Int = 0
    @State private var searchText: String = ""
    
    private let itemsPerPage = 50
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Amortization Schedule")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                HStack {
                    TextField("Search payments...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                    
                    Text("\(filteredData.count) payments")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if !filteredData.isEmpty {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        ForEach(columnHeaders, id: \.self) { header in
                            Text(header)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                        }
                    }
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    // Data rows
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(paginatedData.enumerated()), id: \.offset) { index, row in
                                HStack {
                                    ForEach(columnHeaders, id: \.self) { header in
                                        Text(row.values[header] ?? "")
                                            .font(.system(.body, design: .monospaced))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 8)
                                    }
                                }
                                .padding(.vertical, 8)
                                .background(
                                    Color(NSColor.controlBackgroundColor)
                                        .opacity(index % 2 == 0 ? 0 : 0.3)
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 400)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                )
                
                // Pagination
                if totalPages > 1 {
                    HStack {
                        Button("Previous") {
                            if currentPage > 0 {
                                currentPage -= 1
                            }
                        }
                        .disabled(currentPage == 0)
                        
                        Spacer()
                        
                        Text("Page \(currentPage + 1) of \(totalPages)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Next") {
                            if currentPage < totalPages - 1 {
                                currentPage += 1
                            }
                        }
                        .disabled(currentPage >= totalPages - 1)
                    }
                    .padding(.horizontal)
                }
            } else {
                Text("No payment data available")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(40)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    private var columnHeaders: [String] {
        guard !tableData.isEmpty else { return [] }
        return ["Payment #", "Payment", "Principal", "Interest", "Balance"]
    }
    
    private var filteredData: [TableRow] {
        if searchText.isEmpty {
            return tableData
        } else {
            return tableData.filter { row in
                row.values.values.contains { value in
                    value.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
    }
    
    private var paginatedData: [TableRow] {
        let startIndex = currentPage * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, filteredData.count)
        return Array(filteredData[startIndex..<endIndex])
    }
    
    private var totalPages: Int {
        return (filteredData.count + itemsPerPage - 1) / itemsPerPage
    }
}

/// Loan insights and tips component
struct LoanInsightsView: View {
    let principalAmount: Double
    let interestRate: Double
    let termYears: Double
    let isMortgage: Bool
    
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.yellow)
                    
                    Text(isMortgage ? "Mortgage Insights" : "Loan Tips")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(insights, id: \.0) { insight, description in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.body)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(insight)
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.yellow.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var insights: [(String, String)] {
        var tips: [(String, String)] = []
        
        if interestRate > 7 {
            tips.append(("High Interest Rate", "Consider shopping around for better rates or improving your credit score"))
        }
        
        if isMortgage && termYears > 15 {
            tips.append(("Consider Shorter Term", "A 15-year mortgage typically offers lower rates and saves significant interest"))
        }
        
        if principalAmount > 0 {
            tips.append(("Extra Payments", "Adding just $50-100 extra per payment can save thousands in interest"))
        }
        
        if isMortgage {
            tips.append(("PMI Consideration", "If down payment is less than 20%, you may need private mortgage insurance"))
            tips.append(("Total Housing Costs", "Remember to budget for property taxes, insurance, and maintenance"))
        }
        
        tips.append(("Emergency Fund", "Maintain 3-6 months of payments in savings before taking on debt"))
        
        return tips
    }
}

#Preview {
    LoanCalculatorView()
        .environment(MainViewModel())
        .modelContainer(for: LoanCalculation.self, inMemory: true)
        .frame(width: 1200, height: 800)
}