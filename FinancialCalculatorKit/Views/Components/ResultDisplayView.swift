//
//  ResultDisplayView.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import SwiftUI

/// Beautiful result display component with proper formatting and animations
struct ResultDisplayView: View {
    let result: CalculationResult
    let currency: Currency
    let showSecondaryValues: Bool
    let showExplanation: Bool
    
    @State private var isExpanded: Bool = false
    
    init(
        result: CalculationResult,
        currency: Currency = .usd,
        showSecondaryValues: Bool = true,
        showExplanation: Bool = true
    ) {
        self.result = result
        self.currency = currency
        self.showSecondaryValues = showSecondaryValues
        self.showExplanation = showExplanation
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Primary result card
            primaryResultCard
            
            // Secondary values
            if showSecondaryValues && !result.secondaryValues.isEmpty {
                secondaryValuesSection
            }
            
            // Explanation
            if showExplanation && !result.explanation.isEmpty {
                explanationSection
            }
        }
    }
    
    @ViewBuilder
    private var primaryResultCard: some View {
        VStack(spacing: 12) {
            Text("Result")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Text(result.formattedPrimaryValue)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            
            if result.primaryValue != 0 {
                Text(formatSecondaryResult())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    @ViewBuilder
    private var secondaryValuesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Details")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .buttonStyle(.plain)
                .help(isExpanded ? "Collapse details" : "Expand details")
            }
            
            if isExpanded {
                LazyVStack(spacing: 8) {
                    ForEach(Array(result.secondaryValues.keys.sorted()), id: \.self) { key in
                        if let value = result.secondaryValues[key] {
                            SecondaryValueRow(
                                title: key,
                                value: value,
                                currency: currency
                            )
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .font(.headline)
                    .foregroundColor(.accentColor)
                
                Text("Explanation")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Text(result.explanation)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func formatSecondaryResult() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        
        if let formattedNumber = formatter.string(from: NSNumber(value: result.primaryValue)) {
            return "\(currency.symbol)\(formattedNumber)"
        }
        return currency.formatValue(result.primaryValue)
    }
}

/// Row component for secondary values
struct SecondaryValueRow: View {
    let title: String
    let value: Double
    let currency: Currency
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(formattedValue)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private var formattedValue: String {
        // Determine if this is a currency value, percentage, or other
        if title.lowercased().contains("rate") || title.lowercased().contains("percentage") {
            return String(format: "%.3f%%", value)
        } else if title.lowercased().contains("year") || title.lowercased().contains("period") {
            return String(format: "%.1f", value)
        } else {
            return currency.formatValue(value)
        }
    }
}

/// Error result display for invalid calculations
struct ErrorResultView: View {
    let error: String
    let suggestions: [String]
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                Text("Calculation Error")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(error)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                    )
            )
            
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggestions:")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    ForEach(suggestions, id: \.self) { suggestion in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            Text(suggestion)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 1)
                        )
                )
            }
        }
    }
}

/// Loading result display
struct LoadingResultView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                .scaleEffect(1.2)
            
            Text("Calculating...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
        )
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            ResultDisplayView(
                result: CalculationResult(
                    primaryValue: 125000.50,
                    secondaryValues: [
                        "Total Interest": 75000.25,
                        "Total Payments": 200000.75,
                        "Interest Rate": 5.5,
                        "Number of Years": 15.0
                    ],
                    formattedPrimaryValue: "$125,000.50",
                    explanation: "This is the monthly payment required for a 15-year loan at 5.5% annual interest rate."
                ),
                currency: .usd
            )
            
            ErrorResultView(
                error: "Invalid input values provided",
                suggestions: [
                    "Ensure all required fields are filled",
                    "Check that numeric values are positive",
                    "Verify that percentages are between 0 and 100"
                ]
            )
            
            LoadingResultView()
        }
        .padding()
    }
    .frame(width: 400)
}