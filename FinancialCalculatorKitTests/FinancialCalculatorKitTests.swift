//
//  FinancialCalculatorKitTests.swift
//  FinancialCalculatorKitTests
//
//  Created by Roger Lin on 6/9/25.
//

import Testing
import Foundation
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
            paymentsAtBeginning: false,
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

    // MARK: - Options pricing

    @Test func blackScholesMatchesTextbookAtTheMoneyCall() async throws {
        // S=100, K=100, T=1y, r=5%, sigma=20% -> C = 10.4506 (standard reference value)
        let call = CalculationEngine.calculateBlackScholesOptionPrice(
            spotPrice: 100, strikePrice: 100, timeToExpiry: 1,
            riskFreeRate: 5, volatility: 20, optionType: .call
        )
        #expect(abs(call - 10.4506) < 0.001)
    }

    @Test func blackScholesSatisfiesPutCallParity() async throws {
        let s = 105.0, k = 95.0, t = 0.75, r = 4.0, v = 30.0
        let call = CalculationEngine.calculateBlackScholesOptionPrice(
            spotPrice: s, strikePrice: k, timeToExpiry: t,
            riskFreeRate: r, volatility: v, optionType: .call
        )
        let put = CalculationEngine.calculateBlackScholesOptionPrice(
            spotPrice: s, strikePrice: k, timeToExpiry: t,
            riskFreeRate: r, volatility: v, optionType: .put
        )
        let parity = s - k * Foundation.exp(-r / 100 * t)
        #expect(abs((call - put) - parity) < 1e-6)
    }

    @Test func inverseNormalCDFMatchesKnownQuantiles() async throws {
        #expect(abs(CalculationEngine.inverseNormalCDF(0.95) - 1.6449) < 0.001)
        #expect(abs(CalculationEngine.inverseNormalCDF(0.99) - 2.3263) < 0.001)
        #expect(abs(CalculationEngine.inverseNormalCDF(0.5)) < 1e-9)
    }

    // MARK: - Loans

    @Test func loanPaymentMatchesStandardMortgageFormula() async throws {
        // $300,000 at 6% for 30 years, monthly -> $1,798.65
        let loan = LoanCalculation(
            name: "Test",
            principalAmount: 300_000,
            annualInterestRate: 6,
            loanTermYears: 30
        )
        let payment = loan.calculateMonthlyPayment()
        #expect(abs(payment - 1_798.65) < 0.01)

        let schedule = loan.calculateAmortization()
        #expect(schedule.count == 360)
        #expect(abs(schedule.last?.remainingBalance ?? 1) < 0.01)

        let totalInterest = schedule.reduce(0) { $0 + $1.interestPayment }
        #expect(abs(totalInterest - 347_514.57) < 1.0)
    }

    @Test func extraPaymentShortensLoanAndSavesInterest() async throws {
        let loan = LoanCalculation(
            name: "Extra",
            principalAmount: 300_000,
            annualInterestRate: 6,
            loanTermYears: 30,
            extraPayment: 200
        )
        let result = loan.result
        #expect((result.secondaryValues["Time Saved (Years)"] ?? 0) > 1)
        #expect((result.secondaryValues["Interest Saved"] ?? 0) > 10_000)
    }

    // MARK: - Time value of money

    @Test func futureValueOfLumpSum() async throws {
        // 10,000 at 5% for 10 periods -> 16,288.95
        let fv = CalculationEngine.calculateFutureValue(
            presentValue: 10_000, payment: nil,
            interestRate: 5, numberOfPeriods: 10
        )
        #expect(abs(fv - 16_288.946) < 0.01)
    }

    @Test func paymentSolvesForSavingsGoal() async throws {
        // Reach 100,000 in 120 months at 0.5%/period with no starting balance -> 610.21/mo
        let pmt = CalculationEngine.calculatePayment(
            presentValue: nil, futureValue: 100_000,
            interestRate: 0.5, numberOfPeriods: 120
        )
        #expect(abs(pmt - 610.21) < 0.01)
    }

    @Test func tvmRoundTripsAcrossSolvers() async throws {
        // FV from PV+PMT, then recover the rate and the period count from it
        let fv = CalculationEngine.calculateFutureValue(
            presentValue: 5_000, payment: 200,
            interestRate: 0.5, numberOfPeriods: 120
        )
        let rate = CalculationEngine.calculateInterestRate(
            presentValue: 5_000, futureValue: fv,
            payment: 200, numberOfPeriods: 120
        )
        #expect(abs(rate - 0.5) < 0.001)

        let periods = CalculationEngine.calculateNumberOfPeriods(
            presentValue: 5_000, futureValue: fv,
            payment: 200, interestRate: 0.5
        )
        #expect(abs(periods - 120) < 0.001)
    }

    @Test func numberOfPeriodsReturnsNaNForUnreachableTarget() async throws {
        // Balance shrinks (withdrawals exceed growth) so the target is unreachable
        let periods = CalculationEngine.calculateNumberOfPeriods(
            presentValue: 1_000, futureValue: 2_000,
            payment: -100, interestRate: 0.5
        )
        #expect(periods.isNaN)
    }

    // MARK: - Investment analysis

    @Test func irrMatchesHandComputedValue() async throws {
        // -1000 then 3x500: IRR ~ 23.375%
        let irr = CalculationEngine.calculateIRR(cashFlows: [-1_000, 500, 500, 500])
        #expect(abs(irr - 23.375) < 0.01)
    }

    @Test func irrReturnsNaNWithoutSignChange() async throws {
        #expect(CalculationEngine.calculateIRR(cashFlows: [100, 200, 300]).isNaN)
        #expect(CalculationEngine.calculateIRR(cashFlows: []).isNaN)
    }

    @Test func mirrMatchesHandComputedValue() async throws {
        // FV of inflows at 10%: 500*1.21 + 500*1.1 + 500 = 1655; (1655/1000)^(1/3)-1 = 18.29%
        let mirr = CalculationEngine.calculateMIRR(
            cashFlows: [-1_000, 500, 500, 500],
            financeRate: 10, reinvestmentRate: 10
        )
        #expect(abs(mirr - 18.29) < 0.01)
    }

    @Test func npvOfSimpleSeries() async throws {
        // -1000 + 1100/1.1 = 0
        let npv = CalculationEngine.calculateNPV(cashFlows: [-1_000, 1_100], discountRate: 10)
        #expect(abs(npv) < 1e-9)
    }

    // MARK: - Bonds

    @Test func bondAtCouponRateTradesAtPar() async throws {
        let price = CalculationEngine.calculateBondPrice(
            faceValue: 1_000, couponRate: 5, marketRate: 5,
            yearsToMaturity: 10, paymentsPerYear: 2
        )
        #expect(abs(price - 1_000) < 1e-6)
    }

    @Test func bondPriceHandlesZeroMarketRate() async throws {
        // Undiscounted: 20 coupons of 25 + 1000 face = 1500
        let price = CalculationEngine.calculateBondPrice(
            faceValue: 1_000, couponRate: 5, marketRate: 0,
            yearsToMaturity: 10, paymentsPerYear: 2
        )
        #expect(abs(price - 1_500) < 1e-9)
    }

    @Test func bondYTMRoundTripsPrice() async throws {
        let price = CalculationEngine.calculateBondPrice(
            faceValue: 1_000, couponRate: 5, marketRate: 6.5,
            yearsToMaturity: 8, paymentsPerYear: 2
        )
        let ytm = CalculationEngine.calculateBondYTM(
            faceValue: 1_000, currentPrice: price, couponRate: 5,
            yearsToMaturity: 8, paymentsPerYear: 2
        )
        #expect(abs(ytm - 6.5) < 0.001)
    }

    @Test func shortMaturityBondDoesNotCrash() async throws {
        // Previously trapped on a 1...0 range
        let measures = CalculationEngine.calculateBondRiskMeasures(
            faceValue: 1_000, couponRate: 5, marketRate: 5,
            yearsToMaturity: 0.25, paymentsPerYear: 1
        )
        #expect(measures.macaulayDuration >= 0)
    }

    // MARK: - Depreciation

    @Test func straightLineDepreciationReachesSalvage() async throws {
        let calc = DepreciationCalculation(
            name: "SL", assetCost: 10_000, salvageValue: 1_000, usefulLife: 5
        )
        let schedule = calc.generateDepreciationSchedule()
        #expect(schedule.count == 5)
        #expect(abs((schedule.last?.bookValue ?? 0) - 1_000) < 0.01)
        #expect(abs((schedule.first?.depreciation ?? 0) - 1_800) < 0.01)
    }

    @Test func decliningBalanceSwitchesToStraightLineAndReachesSalvage() async throws {
        let calc = DepreciationCalculation(
            name: "DDB", assetCost: 10_000, salvageValue: 0,
            usefulLife: 5, method: .decliningBalance, decliningBalanceRate: 2.0
        )
        let schedule = calc.generateDepreciationSchedule()
        #expect(schedule.count == 5)
        // Without the straight-line switch, pure DDB strands ~778 above salvage
        #expect(abs(schedule.last?.bookValue ?? 1) < 0.01)
        let total = schedule.reduce(0) { $0 + $1.depreciation }
        #expect(abs(total - 10_000) < 0.01)
    }

    @Test func fractionalUsefulLifeDoesNotCrash() async throws {
        let calc = DepreciationCalculation(
            name: "Short", assetCost: 1_000, salvageValue: 0, usefulLife: 0.5
        )
        let schedule = calc.generateDepreciationSchedule()
        #expect(!schedule.isEmpty)
    }

    // MARK: - Expression evaluation

    @Test func expressionEvaluationResolvesVariables() async throws {
        let value = CalculationEngine.evaluateExpression(
            "P * (1 + r)^t",
            with: ["P": 1_000, "r": 0.05, "t": 2]
        )
        #expect(value != nil)
        #expect(abs((value ?? 0) - 1_102.5) < 1e-9)
    }

    @Test func expressionWithUnknownVariableFails() async throws {
        let value = CalculationEngine.evaluateExpression("x + 1", with: [:])
        #expect(value == nil)
    }

    // MARK: - Preferences persistence

    @Test func preferencesRoundTripThroughUserDefaults() async throws {
        let suiteName = "test.preferences.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = UserPreferences()
        preferences.defaultCurrency = .eur
        preferences.decimalPlaces = 4
        preferences.useThousandsSeparator = false
        preferences.save(to: defaults)

        let loaded = UserPreferences.load(from: defaults)
        #expect(loaded.defaultCurrency == .eur)
        #expect(loaded.decimalPlaces == 4)
        #expect(loaded.useThousandsSeparator == false)
    }

}
