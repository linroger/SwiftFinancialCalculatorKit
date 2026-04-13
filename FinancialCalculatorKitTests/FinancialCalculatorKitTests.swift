//
//  FinancialCalculatorKitTests.swift
//  FinancialCalculatorKitTests
//
//  Created by Roger Lin on 6/9/25.
//

import Testing
@testable import FinancialCalculatorKit

struct FinancialCalculatorKitTests {

    @Test func createNewCalculationPresentsCalculatorPicker() async throws {
        let viewModel = MainViewModel()

        viewModel.createNewCalculation(type: .bond)

        #expect(viewModel.selectedCalculationType == .bond)
        #expect(viewModel.presentedSheet == .calculatorPicker)
    }

    @Test func sheetRoutingIsExclusive() async throws {
        let viewModel = MainViewModel()

        viewModel.showPreferences()
        #expect(viewModel.presentedSheet == .preferences)

        viewModel.showHelp()
        #expect(viewModel.presentedSheet == .help)

        viewModel.dismissSheet()
        #expect(viewModel.presentedSheet == nil)
    }

    @Test func openCalculatorAndDashboardResetSelection() async throws {
        let viewModel = MainViewModel()

        viewModel.openCalculator(.loan)
        #expect(viewModel.selectedCalculationType == .loan)

        viewModel.showDashboard()
        #expect(viewModel.selectedCalculationType == nil)
    }

}
