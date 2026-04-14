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

    @Test func optionGreeksProvideExpectedSignsForAtTheMoneyCall() async throws {
        let greeks = CalculationEngine.calculateOptionGreeks(
            spotPrice: 100,
            strikePrice: 100,
            timeToExpiry: 0.5,
            riskFreeRate: 5,
            volatility: 20,
            optionType: .call
        )

        #expect(greeks.delta > 0.4 && greeks.delta < 0.7)
        #expect(greeks.gamma > 0)
        #expect(greeks.theta < 0)
        #expect(greeks.vega > 0)
        #expect(greeks.rho > 0)
    }

    @Test func bondRiskMeasuresArePositiveForStandardCouponBond() async throws {
        let measures = CalculationEngine.calculateBondRiskMeasures(
            faceValue: 1_000,
            couponRate: 5,
            marketRate: 4.5,
            yearsToMaturity: 7,
            paymentsPerYear: 2
        )

        #expect(measures.macaulayDuration > 0)
        #expect(measures.modifiedDuration > 0)
        #expect(measures.convexity > 0)
        #expect(measures.macaulayDuration > measures.modifiedDuration)
    }

    @Test func tvmSnapshotBuildsGrowthMilestonesAndScenarioLadder() async throws {
        let snapshot = TVMAnalysisEngine.buildSnapshot(
            solveFor: .futureValue,
            presentValue: 10_000,
            futureValue: nil,
            payment: 250,
            annualInterestRate: 7,
            numberOfYears: 10,
            paymentFrequency: .monthly,
            paymentsAtBeginning: false
            result: nil
        )

        #expect(snapshot != nil)
        #expect(snapshot?.resolvedFutureValue ?? 0 > 0)
        #expect(snapshot?.effectiveAnnualRate ?? 0 > 7)
        #expect(!(snapshot?.growthTimeline.isEmpty ?? true))
        #expect(!(snapshot?.milestones.isEmpty ?? true))
        #expect(snapshot?.scenarios.count == 3)
        #expect(snapshot?.netGrowth ?? 0 > 0)
    }

}
