//
//  FinancialStyles.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import SwiftUI

/// Custom group box style for financial calculator components
struct FinancialGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            configuration.label
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            
            configuration.content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1) // Subtle highlight
        )
    }
}

/// Reusable detail row component for displaying key-value pairs
struct DetailRow: View {
    let title: String
    let value: String
    let isHighlighted: Bool
    
    init(title: String, value: String, isHighlighted: Bool = false) {
        self.title = title
        self.value = value
        self.isHighlighted = isHighlighted
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(isHighlighted ? .bold : .medium)
                .foregroundColor(isHighlighted ? .primary : .primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    isHighlighted ?
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.1))
                    : nil
                )
        }
        .padding(.vertical, 4)
    }
}

/// Enhanced button style for primary actions
struct FinancialButtonStyle: ButtonStyle {
    let style: FinancialButtonStyleType
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, weight: .semibold))
            .foregroundColor(foregroundColor(for: style))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor(for: style))
                    .shadow(color: shadowColor(for: style), radius: 4, x: 0, y: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
    
    private func backgroundColor(for style: FinancialButtonStyleType) -> Color {
        switch style {
        case .primary:
            return .accentColor
        case .secondary:
            return Color(NSColor.controlBackgroundColor)
        case .destructive:
            return .red
        }
    }
    
    private func foregroundColor(for style: FinancialButtonStyleType) -> Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return .primary
        case .destructive:
            return .white
        }
    }
    
    private func shadowColor(for style: FinancialButtonStyleType) -> Color {
        switch style {
        case .primary:
            return .accentColor.opacity(0.3)
        case .secondary:
            return .black.opacity(0.05)
        case .destructive:
            return .red.opacity(0.3)
        }
    }
}

enum FinancialButtonStyleType {
    case primary
    case secondary
    case destructive
}

/// Card style container for sections
struct FinancialCardStyle: ViewModifier {
    let padding: EdgeInsets
    
    init(padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
        self.padding = padding
    }
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                    .background(.ultraThinMaterial) // Glassmorphism effect
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
            )
    }
}

extension View {
    func financialCard(padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) -> some View {
        modifier(FinancialCardStyle(padding: padding))
    }
}

/// Extension for common financial app colors
extension Color {
    static let financialGreen = Color(red: 0.2, green: 0.7, blue: 0.3)
    static let financialRed = Color(red: 0.85, green: 0.3, blue: 0.3)
    static let financialBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    static let financialOrange = Color(red: 1.0, green: 0.58, blue: 0.0)
    static let financialPurple = Color(red: 0.68, green: 0.32, blue: 0.87)
}
