//
//  InputFieldView.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import SwiftUI

/// Reusable input field component with validation and native macOS styling
struct InputFieldView: View {
    let title: String
    let subtitle: String?
    @Binding var value: String
    let placeholder: String
    let keyboardType: KeyboardType
    let validation: ValidationRule?
    let helpText: String?
    let isRequired: Bool
    
    @State private var isEditing: Bool = false
    @State private var validationError: String?
    @FocusState private var isFocused: Bool
    
    init(
        title: String,
        subtitle: String? = nil,
        value: Binding<String>,
        placeholder: String = "",
        keyboardType: KeyboardType = .default,
        validation: ValidationRule? = nil,
        helpText: String? = nil,
        isRequired: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self._value = value
        self.placeholder = placeholder
        self.keyboardType = keyboardType
        self.validation = validation
        self.helpText = helpText
        self.isRequired = isRequired
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title and help button
            HStack(alignment: .center, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        if isRequired {
                            Text("*")
                                .foregroundColor(.red)
                                .font(.headline)
                        }
                    }
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if let helpText = helpText {
                    Button(action: {}) {
                        Image(systemName: "questionmark.circle")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(helpText)
                }
            }
            
            // Input field
            TextField(placeholder, text: $value)
                .textFieldStyle(FinancialTextFieldStyle(
                    isEditing: isEditing,
                    hasError: validationError != nil,
                    isFocused: isFocused
                ))
                .focused($isFocused)
                .onSubmit {
                    isEditing = false
                    validateInput()
                }
                .onChange(of: value) { _, newValue in
                    if validationError != nil {
                        validateInput() // Re-validate on change if there's an error
                    }
                }
            
            // Error message
            if let error = validationError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: validationError)
    }
    
    private func validateInput() {
        guard let validation = validation else {
            validationError = nil
            return
        }
        
        let result = validation.validate(value)
        validationError = result.isValid ? nil : result.errorMessage
    }
}

/// Custom text field style for financial inputs
struct FinancialTextFieldStyle: TextFieldStyle {
    let isEditing: Bool
    let hasError: Bool
    let isFocused: Bool
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(.body, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: isFocused)
            .animation(.easeInOut(duration: 0.15), value: hasError)
    }
    
    private var borderColor: Color {
        if hasError {
            return .red
        } else if isFocused {
            return .accentColor
        } else {
            return Color(NSColor.separatorColor)
        }
    }
    
    private var borderWidth: CGFloat {
        if hasError || isFocused {
            return 2.0
        } else {
            return 1.0
        }
    }
}

/// Simple keyboard type enum for cross-platform compatibility
enum KeyboardType {
    case `default`
    case decimalPad
    case numberPad
}

/// Input validation result
struct InputValidationResult: Sendable {
    let isValid: Bool
    let errorMessage: String?
}

/// Validation rules for input fields
struct ValidationRule: Sendable {
    let validate: @Sendable (String) -> InputValidationResult
    
    static let positiveNumber = ValidationRule { value in
        guard !value.isEmpty else {
            return InputValidationResult(isValid: false, errorMessage: "This field is required")
        }
        
        guard let number = Double(value), number > 0 else {
            return InputValidationResult(isValid: false, errorMessage: "Must be a positive number")
        }
        
        return InputValidationResult(isValid: true, errorMessage: nil)
    }
    
    static let nonNegativeNumber = ValidationRule { value in
        guard !value.isEmpty else {
            return InputValidationResult(isValid: false, errorMessage: "This field is required")
        }
        
        guard let number = Double(value), number >= 0 else {
            return InputValidationResult(isValid: false, errorMessage: "Must be zero or positive")
        }
        
        return InputValidationResult(isValid: true, errorMessage: nil)
    }
    
    static let percentage = ValidationRule { value in
        guard !value.isEmpty else {
            return InputValidationResult(isValid: false, errorMessage: "This field is required")
        }
        
        guard let number = Double(value), number >= 0, number <= 100 else {
            return InputValidationResult(isValid: false, errorMessage: "Must be between 0 and 100")
        }
        
        return InputValidationResult(isValid: true, errorMessage: nil)
    }
    
    static let required = ValidationRule { value in
        guard !value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty else {
            return InputValidationResult(isValid: false, errorMessage: "This field is required")
        }
        
        return InputValidationResult(isValid: true, errorMessage: nil)
    }
}


/// Specialized input field for currency amounts
struct CurrencyInputField: View {
    let title: String
    let subtitle: String?
    @Binding var value: Double?
    let currency: Currency
    let isRequired: Bool
    let helpText: String?
    
    @State private var stringValue: String = ""
    @State private var isEditing: Bool = false
    
    init(
        title: String,
        subtitle: String? = nil,
        value: Binding<Double?>,
        currency: Currency = .usd,
        isRequired: Bool = false,
        helpText: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self._value = value
        self.currency = currency
        self.isRequired = isRequired
        self.helpText = helpText
        
        // Initialize string value
        if let val = value.wrappedValue {
            self._stringValue = State(initialValue: String(format: "%.2f", val))
        }
    }
    
    init(
        value: Binding<Double>,
        currency: Currency = .usd,
        placeholder: String = "",
        onValueChange: @escaping (Double) -> Void = { _ in }
    ) {
        self.title = ""
        self.subtitle = nil
        self.currency = currency
        self.isRequired = false
        self.helpText = nil
        
        // Create a binding that converts between Double and Double?
        self._value = Binding(
            get: { value.wrappedValue },
            set: { newValue in
                if let newValue = newValue {
                    value.wrappedValue = newValue
                    onValueChange(newValue)
                }
            }
        )
        
        self._stringValue = State(initialValue: String(format: "%.2f", value.wrappedValue))
    }
    
    var body: some View {
        TextField(title, text: $stringValue, onEditingChanged: { editing in
            isEditing = editing
            if !editing {
                // Format the display when editing ends
                if let val = value {
                    stringValue = String(format: "%.2f", val)
                }
            }
        })
        .textFieldStyle(FinancialTextFieldStyle(
            isEditing: isEditing,
            hasError: false,
            isFocused: isEditing
        ))
        .onChange(of: stringValue) { _, newValue in
            // Update the value without formatting during editing
            if let doubleValue = Double(newValue) {
                value = doubleValue
            } else if newValue.isEmpty {
                value = nil
            }
        }
        .onChange(of: value) { _, newValue in
            // Only update string if not currently editing
            if !isEditing {
                if let val = newValue {
                    stringValue = String(format: "%.2f", val)
                } else if stringValue != "" {
                    stringValue = ""
                }
            }
        }
    }
}

/// Specialized input field for percentages
struct PercentageInputField: View {
    let title: String
    let subtitle: String?
    @Binding var value: Double?
    let isRequired: Bool
    let helpText: String?
    
    @State private var stringValue: String = ""
    @State private var isEditing: Bool = false
    
    init(
        title: String,
        subtitle: String? = nil,
        value: Binding<Double?>,
        isRequired: Bool = false,
        helpText: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self._value = value
        self.isRequired = isRequired
        self.helpText = helpText
        
        // Initialize string value
        if let val = value.wrappedValue {
            self._stringValue = State(initialValue: String(format: "%.3f", val))
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            TextField(title, text: $stringValue, onEditingChanged: { editing in
                isEditing = editing
                if !editing {
                    // Format the display when editing ends
                    if let val = value {
                        stringValue = String(format: "%.3f", val)
                    }
                }
            })
            .textFieldStyle(FinancialTextFieldStyle(
                isEditing: isEditing,
                hasError: false,
                isFocused: isEditing
            ))
            
            Text("%")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.top, subtitle != nil ? 24 : 0)
        }
        .onChange(of: stringValue) { _, newValue in
            // Update the value without formatting during editing
            if let doubleValue = Double(newValue) {
                value = doubleValue
            } else if newValue.isEmpty {
                value = nil
            }
        }
        .onChange(of: value) { _, newValue in
            // Only update string if not currently editing
            if !isEditing {
                if let val = newValue {
                    stringValue = String(format: "%.3f", val)
                } else if stringValue != "" {
                    stringValue = ""
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        InputFieldView(
            title: "Sample Input",
            subtitle: "This is a subtitle",
            value: Binding.constant(""),
            placeholder: "Enter value",
            validation: .required,
            helpText: "This is help text for the input field",
            isRequired: true
        )
        
        CurrencyInputField(
            title: "Amount",
            subtitle: "Principal loan amount",
            value: Binding.constant(100000),
            currency: .usd,
            isRequired: true,
            helpText: "Enter the total amount of the loan"
        )
        
        PercentageInputField(
            title: "Interest Rate",
            subtitle: "Annual percentage rate",
            value: Binding.constant(5.5),
            isRequired: true,
            helpText: "Enter the annual interest rate"
        )
    }
    .padding()
    .frame(width: 300)
}