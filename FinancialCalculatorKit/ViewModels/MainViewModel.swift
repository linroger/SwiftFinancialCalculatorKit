//
//  MainViewModel.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import Foundation
import SwiftUI
import SwiftData

/// Main view model coordinating the entire application state
@Observable
class MainViewModel {
    enum PresentedSheet: String, Identifiable {
        case calculatorPicker
        case preferences
        case help

        var id: String { rawValue }
    }

    /// Currently selected calculation type. `nil` means dashboard.
    var selectedCalculationType: CalculationType? = nil
    
    /// Selected calculation for editing
    var selectedCalculation: FinancialCalculation?
    
    /// Search text for filtering calculations
    var searchText: String = ""
    
    /// Show favorites only
    var showFavoritesOnly: Bool = false
    
    /// User preferences
    var userPreferences: UserPreferences = UserPreferences()
    
    /// Error handling
    var currentError: FinancialCalculatorError?
    var showingError: Bool = false
    
    /// Sheet presentation state
    var presentedSheet: PresentedSheet?
    
    /// Initialize with default settings
    init() {
        loadUserPreferences()
    }

    /// Load user preferences from storage
    private func loadUserPreferences() {
        userPreferences = UserPreferences.load()
    }

    /// Save user preferences
    func saveUserPreferences() {
        userPreferences.save()
    }
    
    /// Create a new calculation of the specified type
    func createNewCalculation(type: CalculationType?) {
        selectedCalculationType = type
        selectedCalculation = nil
        presentedSheet = .calculatorPicker
    }
    
    /// Edit an existing calculation
    func editCalculation(_ calculation: FinancialCalculation) {
        selectedCalculation = calculation
        selectedCalculationType = calculation.calculationType
        presentedSheet = .calculatorPicker
    }

    /// Open an existing calculator in the detail pane.
    func openCalculator(_ type: CalculationType) {
        selectedCalculationType = type
        selectedCalculation = nil
    }

    /// Return the detail pane to the dashboard.
    func showDashboard() {
        selectedCalculationType = nil
        selectedCalculation = nil
    }

    /// Open the preferences sheet.
    func showPreferences() {
        presentedSheet = .preferences
    }

    /// Open the help sheet.
    func showHelp() {
        presentedSheet = .help
    }

    /// Dismiss any active sheet.
    func dismissSheet() {
        presentedSheet = nil
    }
    
    /// Delete a calculation
    func deleteCalculation(_ calculation: FinancialCalculation, from context: ModelContext) {
        context.delete(calculation)
        
        // If this was the selected calculation, clear selection
        if selectedCalculation?.id == calculation.id {
            selectedCalculation = nil
        }
        
        try? context.save()
    }
    
    /// Toggle favorite status of a calculation
    func toggleFavorite(_ calculation: FinancialCalculation, in context: ModelContext) {
        calculation.toggleFavorite()
        try? context.save()
    }
    
    /// Handle errors
    func handleError(_ error: FinancialCalculatorError) {
        currentError = error
        showingError = true
    }
    
    /// Clear current error
    func clearError() {
        currentError = nil
        showingError = false
    }
    
    /// Filter calculations based on search and favorites
    func filteredCalculations(_ calculations: [FinancialCalculation]) -> [FinancialCalculation] {
        var filtered = calculations
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { calculation in
                calculation.name.localizedCaseInsensitiveContains(searchText) ||
                calculation.notes.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filter by favorites if enabled
        if showFavoritesOnly {
            filtered = filtered.filter { $0.isFavorite }
        }
        
        // Sort by last modified date (most recent first)
        return filtered.sorted { $0.lastModified > $1.lastModified }
    }
}

/// UserDefaults keys shared between the preferences model and the currency
/// formatter, which honors the number-format settings app-wide.
enum PreferenceKeys {
    static let defaultCurrency = "preferences.defaultCurrency"
    static let defaultPaymentFrequency = "preferences.defaultPaymentFrequency"
    static let decimalPlaces = "preferences.decimalPlaces"
    static let useThousandsSeparator = "preferences.useThousandsSeparator"
}

/// User preferences model. Every property here is consumed somewhere in the
/// app — settings that would have no effect are not offered.
@Observable
class UserPreferences {
    /// Default currency for new calculations
    var defaultCurrency: Currency = .usd

    /// Default payment frequency for new calculations
    var defaultPaymentFrequency: PaymentFrequency = .monthly

    /// Number format preferences, honored by Currency.formatValue
    var decimalPlaces: Int = 2
    var useThousandsSeparator: Bool = true

    /// Load preferences from UserDefaults, falling back to defaults for missing keys.
    static func load(from defaults: UserDefaults = .standard) -> UserPreferences {
        let preferences = UserPreferences()
        if let raw = defaults.string(forKey: PreferenceKeys.defaultCurrency),
           let currency = Currency(rawValue: raw) {
            preferences.defaultCurrency = currency
        }
        if let raw = defaults.string(forKey: PreferenceKeys.defaultPaymentFrequency),
           let frequency = PaymentFrequency(rawValue: raw) {
            preferences.defaultPaymentFrequency = frequency
        }
        if defaults.object(forKey: PreferenceKeys.decimalPlaces) != nil {
            preferences.decimalPlaces = min(max(defaults.integer(forKey: PreferenceKeys.decimalPlaces), 0), 6)
        }
        if defaults.object(forKey: PreferenceKeys.useThousandsSeparator) != nil {
            preferences.useThousandsSeparator = defaults.bool(forKey: PreferenceKeys.useThousandsSeparator)
        }
        return preferences
    }

    /// Persist preferences to UserDefaults.
    func save(to defaults: UserDefaults = .standard) {
        defaults.set(defaultCurrency.rawValue, forKey: PreferenceKeys.defaultCurrency)
        defaults.set(defaultPaymentFrequency.rawValue, forKey: PreferenceKeys.defaultPaymentFrequency)
        defaults.set(decimalPlaces, forKey: PreferenceKeys.decimalPlaces)
        defaults.set(useThousandsSeparator, forKey: PreferenceKeys.useThousandsSeparator)
    }
}

/// Supported chart types
enum ChartType: String, CaseIterable, Identifiable {
    case line = "line"
    case bar = "bar"
    case area = "area"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .line:
            return "Line Chart"
        case .bar:
            return "Bar Chart"
        case .area:
            return "Area Chart"
        }
    }
}

/// Application-specific errors
enum FinancialCalculatorError: LocalizedError, Identifiable {
    case invalidInput(String)
    case calculationFailed(String)
    case dataImportFailed(String)
    case dataExportFailed(String)
    case networkError(String)
    case fileAccessError(String)
    
    var id: String {
        switch self {
        case .invalidInput(let message):
            return "invalidInput_\(message)"
        case .calculationFailed(let message):
            return "calculationFailed_\(message)"
        case .dataImportFailed(let message):
            return "dataImportFailed_\(message)"
        case .dataExportFailed(let message):
            return "dataExportFailed_\(message)"
        case .networkError(let message):
            return "networkError_\(message)"
        case .fileAccessError(let message):
            return "fileAccessError_\(message)"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return "Invalid Input: \(message)"
        case .calculationFailed(let message):
            return "Calculation Failed: \(message)"
        case .dataImportFailed(let message):
            return "Import Failed: \(message)"
        case .dataExportFailed(let message):
            return "Export Failed: \(message)"
        case .networkError(let message):
            return "Network Error: \(message)"
        case .fileAccessError(let message):
            return "File Access Error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidInput:
            return "Please check your input values and try again."
        case .calculationFailed:
            return "Verify that all required fields are filled correctly."
        case .dataImportFailed:
            return "Check that the file format is correct and try again."
        case .dataExportFailed:
            return "Ensure you have write permissions to the selected location."
        case .networkError:
            return "Check your internet connection and try again."
        case .fileAccessError:
            return "Verify file permissions and try again."
        }
    }
}
