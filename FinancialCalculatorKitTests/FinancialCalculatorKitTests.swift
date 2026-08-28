//
//  FinancialCalculatorKitTests.swift
//  FinancialCalculatorKitTests
//
//  Created by Roger Lin on 6/9/25.
//

import Testing
import Foundation
import SwiftData
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

    // MARK: - Retirement planning

    @Test func growingAnnuityPVMatchesBruteForceSum() async throws {
        let firstPayment = 1_000.0
        let r = 0.005
        let g = 0.002
        let n = 360

        let closedForm = RetirementPlanCalculation.growingAnnuityPresentValue(
            firstPayment: firstPayment, ratePerPeriod: r, growthPerPeriod: g, periods: n
        )

        var bruteForce = 0.0
        for k in 1...n {
            bruteForce += firstPayment * pow(1 + g, Double(k - 1)) / pow(1 + r, Double(k))
        }

        #expect(abs(closedForm - bruteForce) < 0.01)

        // Degenerate r == g case
        let equal = RetirementPlanCalculation.growingAnnuityPresentValue(
            firstPayment: 100, ratePerPeriod: 0.004, growthPerPeriod: 0.004, periods: 24
        )
        var equalSum = 0.0
        for k in 1...24 {
            equalSum += 100 * pow(1.004, Double(k - 1)) / pow(1.004, Double(k))
        }
        #expect(abs(equal - equalSum) < 1e-9)
    }

    @Test func retirementProjectionZeroRateSanity() async throws {
        // All rates zero: pure arithmetic
        let projection = RetirementPlanCalculation.project(
            currentAge: 60, retirementAge: 61, lifeExpectancy: 62,
            currentSavings: 1_200, monthlyContribution: 100,
            preRetirementReturn: 0, inRetirementReturn: 0, inflationRate: 0,
            desiredMonthlyIncome: 100
        )

        #expect(abs(projection.projectedNestEgg - 2_400) < 1e-9)
        #expect(abs(projection.requiredNestEgg - 1_200) < 1e-9)
        #expect(abs(projection.surplus - 1_200) < 1e-9)
        #expect(abs(projection.sustainableMonthlyIncomeToday - 200) < 1e-9)
        #expect(projection.depletionAge == nil)
    }

    @Test func retirementShortfallReportsDepletionAndExtraSavings() async throws {
        let projection = RetirementPlanCalculation.project(
            currentAge: 60, retirementAge: 61, lifeExpectancy: 62,
            currentSavings: 0, monthlyContribution: 0,
            preRetirementReturn: 0, inRetirementReturn: 0, inflationRate: 0,
            desiredMonthlyIncome: 1_000
        )

        #expect(projection.surplus < 0)
        #expect(abs(projection.additionalMonthlySavingsNeeded - 1_000) < 1e-9)
        #expect(projection.depletionAge != nil)
        #expect(abs((projection.depletionAge ?? 0) - (61 + 1.0 / 12)) < 0.001)
    }

    @Test func sustainableIncomeIsSelfConsistent() async throws {
        // Feeding the sustainable income back in as the desired income should
        // land the plan almost exactly at break-even
        let base = RetirementPlanCalculation.project(
            currentAge: 40, retirementAge: 65, lifeExpectancy: 90,
            currentSavings: 100_000, monthlyContribution: 1_500,
            preRetirementReturn: 6, inRetirementReturn: 4, inflationRate: 2.5,
            desiredMonthlyIncome: 6_000
        )

        let rebalanced = RetirementPlanCalculation.project(
            currentAge: 40, retirementAge: 65, lifeExpectancy: 90,
            currentSavings: 100_000, monthlyContribution: 1_500,
            preRetirementReturn: 6, inRetirementReturn: 4, inflationRate: 2.5,
            desiredMonthlyIncome: base.sustainableMonthlyIncomeToday
        )

        #expect(abs(rebalanced.surplus) < 1.0)
    }

    // MARK: - Restoring saved calculations

    @Test func openingASavedCalculationHandsTheIDToTheRightCalculator() async throws {
        let viewModel = MainViewModel()
        let id = UUID()

        viewModel.openSavedCalculation(id: id, type: .loan)
        #expect(viewModel.selectedCalculationType == .loan)

        // A calculator that does not own the selection must not consume it
        #expect(viewModel.takePendingLoadID(for: .bond) == nil)
        #expect(viewModel.pendingLoadID == id)

        // The owning calculator gets it exactly once
        #expect(viewModel.takePendingLoadID(for: .loan, .mortgage) == id)
        #expect(viewModel.takePendingLoadID(for: .loan, .mortgage) == nil)
        #expect(viewModel.pendingLoadID == nil)
    }

    @Test func openingABlankCalculatorClearsAnyPendingLoad() async throws {
        let viewModel = MainViewModel()
        viewModel.openSavedCalculation(id: UUID(), type: .loan)

        // Navigating to a fresh calculator must not drag the old record along
        viewModel.openCalculator(.loan)
        #expect(viewModel.pendingLoadID == nil)
        #expect(viewModel.takePendingLoadID(for: .loan) == nil)
    }

    @Test @MainActor func savedCalculationsFetchBackByIDWithEveryFieldIntact() async throws {
        let schema = Schema([
            FinancialCalculation.self, TimeValueCalculation.self, LoanCalculation.self,
            BondCalculation.self, InvestmentCalculation.self, DepreciationCalculation.self,
            OptionsCalculation.self, MathExpressionCalculation.self,
            CurrencyConversionCalculation.self, RetirementPlanCalculation.self,
            DebtPayoffCalculation.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)

        let loan = LoanCalculation(
            name: "Restored Mortgage", principalAmount: 420_000,
            annualInterestRate: 5.75, loanTermYears: 30,
            paymentFrequency: .monthly, downPayment: 84_000,
            extraPayment: 150, loanType: .mortgage, currency: .eur
        )
        context.insert(loan)

        let plan = DebtPayoffCalculation(
            name: "Restored Debts", debts: sampleDebts, extraPayment: 275, currency: .gbp
        )
        context.insert(plan)
        try context.save()

        // The same fetch the calculator views perform on restore
        let loanID = loan.id
        var loanDescriptor = FetchDescriptor<LoanCalculation>(predicate: #Predicate { $0.id == loanID })
        loanDescriptor.fetchLimit = 1
        let restoredLoan = try #require(try context.fetch(loanDescriptor).first)

        #expect(restoredLoan.name == "Restored Mortgage")
        #expect(restoredLoan.principalAmount == 420_000)
        #expect(restoredLoan.annualInterestRate == 5.75)
        #expect(restoredLoan.loanTermYears == 30)
        #expect(restoredLoan.downPayment == 84_000)
        #expect(restoredLoan.extraPayment == 150)
        #expect(restoredLoan.loanType == .mortgage)
        #expect(restoredLoan.currency == .eur)
        // The restored record must reproduce its own result
        #expect(restoredLoan.result.primaryValue > 0)

        let planID = plan.id
        var planDescriptor = FetchDescriptor<DebtPayoffCalculation>(predicate: #Predicate { $0.id == planID })
        planDescriptor.fetchLimit = 1
        let restoredPlan = try #require(try context.fetch(planDescriptor).first)

        #expect(restoredPlan.debts.count == 3)
        #expect(restoredPlan.debts.first?.name == "Credit Card")
        #expect(restoredPlan.extraPayment == 275)
        #expect(restoredPlan.currency == .gbp)
    }

    @Test @MainActor func unitConversionsPersistAndRestore() async throws {
        let schema = Schema([UnitConversionCalculation.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)

        // 100 °C in °F, the conversion the converter itself computes
        let converted = try #require(
            UnitConverterView.convertTemperature(100, from: "°C", to: "°F")
        )
        let saved = UnitConversionCalculation(
            name: "Boiling point",
            inputValue: 100,
            outputValue: converted,
            fromUnit: "°C",
            toUnit: "°F",
            category: .temperature
        )
        context.insert(saved)
        try context.save()

        let id = saved.id
        var descriptor = FetchDescriptor<UnitConversionCalculation>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        let restored = try #require(try context.fetch(descriptor).first)

        #expect(restored.name == "Boiling point")
        #expect(restored.category == .temperature)
        #expect(restored.fromUnit == "°C")
        #expect(restored.toUnit == "°F")
        #expect(abs(restored.outputValue - 212) < 1e-9)
        #expect(restored.calculationType == .conversion)
        #expect(restored.isValid)

        // The stored record describes itself without recomputing
        #expect(restored.result.formattedPrimaryValue == "212 °F")
        #expect(restored.result.explanation.contains("100 °C"))
    }

    // MARK: - Secondary value formatting

    @Test func secondaryValuesFormatByUnitNotJustByName() async throws {
        func format(_ key: String, _ value: Double) -> String {
            SecondaryValueFormatter.format(key: key, value: value, currency: .usd)
        }

        // Rate-ish keys render as percentages
        #expect(format("Annual Interest Rate", 5.25) == "5.250%")
        #expect(format("Effective Annual Rate", 5.116) == "5.116%")

        // Time keys render as plain numbers.
        // Avoid exact binary ties like 3.25 here — printf rounds those to even,
        // so 3.25 renders "3.2" and the assertion would be testing rounding mode
        // rather than the formatter's routing.
        #expect(format("Number of Years", 12.5) == "12.5")
        #expect(format("Payback Period", 3.26) == "3.3")

        // Everything else is money
        #expect(format("Total Interest", 1234.5).contains("1,234.50"))

        // "NPV at IRR" contains a rate word but holds money — the exception list
        // keeps it from rendering as a percentage
        #expect(format("NPV at IRR", 1234.5).contains("1,234.50"))

        // Counts stay whole
        #expect(format("Debts", 3) == "3")
        #expect(format("Number of Coupon Payments", 20) == "20")

        // Non-finite values never reach the user as "nan"
        #expect(format("Total Interest", .nan) == "—")
        #expect(format("Total Interest", .infinity) == "—")
    }

    @Test func deltasCarryTheirSignAndCollapseWhenNegligible() async throws {
        func delta(_ key: String, _ value: Double) -> String {
            SecondaryValueFormatter.formatDelta(key: key, delta: value, currency: .usd)
        }

        #expect(delta("Total Interest", 500).hasPrefix("+"))
        #expect(delta("Total Interest", -500).hasPrefix("−"))
        #expect(delta("Annual Interest Rate", 1.5) == "+1.500%")

        // Rounding noise should read as "no difference", not "+$0.00"
        #expect(delta("Total Interest", 0.001) == "—")
        #expect(delta("Total Interest", 0) == "—")
        #expect(delta("Total Interest", .nan) == "—")
    }

    // MARK: - Command palette

    @Test func paletteFindsCalculatorsByNameAndJargon() async throws {
        let commands = PaletteCommand.calculatorCommands()

        func titles(_ query: String) -> [String] {
            PaletteCommand.matching(query, in: commands).map(\.title)
        }

        // Direct name match ranks first
        #expect(titles("bond").first == "Bond Calculator")

        // Domain jargon that appears in no calculator name still finds the tool
        #expect(titles("greeks").contains("Options Calculator"))
        #expect(titles("amortization").contains("Loan Calculator"))
        #expect(titles("macrs").contains("Depreciation"))
        #expect(titles("snowball").contains("Debt Payoff Planner"))
        #expect(titles("401k").contains("Retirement Planner"))
        #expect(titles("ytm").contains("Bond Calculator"))
        #expect(titles("irr").contains("Investment Analysis"))

        // Case is ignored
        #expect(titles("GREEKS").contains("Options Calculator"))
    }

    @Test func paletteNarrowsAsTermsAreAdded() async throws {
        let commands = PaletteCommand.calculatorCommands()

        let broad = PaletteCommand.matching("calculator", in: commands).count
        let narrow = PaletteCommand.matching("bond calculator", in: commands).count

        #expect(narrow < broad)
        #expect(narrow >= 1)

        // Terms may match across different fields — "rate" is a keyword, "bond" a title
        #expect(PaletteCommand.matching("bond yield", in: commands).count == 1)
    }

    @Test func paletteReturnsEverythingForAnEmptyQuery() async throws {
        let commands = PaletteCommand.calculatorCommands()

        #expect(PaletteCommand.matching("", in: commands).count == commands.count)
        #expect(PaletteCommand.matching("   ", in: commands).count == commands.count)
        // Every calculator type is reachable from the palette
        #expect(commands.count == CalculationType.allCases.count)
    }

    @Test func paletteReturnsNothingForAnUnmatchedQuery() async throws {
        let commands = PaletteCommand.calculatorCommands()
        #expect(PaletteCommand.matching("zzzz-not-a-thing", in: commands).isEmpty)
    }

    @Test func paletteRanksTitlePrefixMatchesAboveKeywordMatches() async throws {
        let commands = PaletteCommand.calculatorCommands()
        let results = PaletteCommand.matching("loan", in: commands)

        // "Loan Calculator" starts with the term, so it outranks the
        // Mortgage and Debt Payoff entries that merely mention loans
        #expect(results.first?.title == "Loan Calculator")
        #expect(results.contains { $0.title == "Mortgage Calculator" })
        #expect(results.contains { $0.title == "Debt Payoff Planner" })
    }

    // MARK: - Debt payoff strategies

    /// Three debts whose rate order and balance order deliberately disagree,
    /// so avalanche and snowball genuinely diverge.
    private var sampleDebts: [Debt] {
        [
            Debt(name: "Credit Card", balance: 8_500, annualRate: 22.9, minimumPayment: 210),
            Debt(name: "Car Loan", balance: 3_200, annualRate: 6.4, minimumPayment: 320),
            Debt(name: "Student Loan", balance: 21_000, annualRate: 4.5, minimumPayment: 240)
        ]
    }

    @Test func avalancheNeverCostsMoreInterestThanSnowball() async throws {
        let avalanche = try DebtPayoffPlanner.plan(debts: sampleDebts, extraPayment: 200, strategy: .avalanche)
        let snowball = try DebtPayoffPlanner.plan(debts: sampleDebts, extraPayment: 200, strategy: .snowball)

        #expect(avalanche.totalInterest <= snowball.totalInterest)
        #expect(avalanche.months <= snowball.months)
        // Both spend the same budget, which is what makes the comparison fair
        #expect(avalanche.monthlyBudget == snowball.monthlyBudget)
    }

    @Test func strategiesTargetTheDebtTheyClaimTo() async throws {
        let avalanche = try DebtPayoffPlanner.plan(debts: sampleDebts, extraPayment: 200, strategy: .avalanche)
        let snowball = try DebtPayoffPlanner.plan(debts: sampleDebts, extraPayment: 200, strategy: .snowball)

        func month(_ plan: DebtPayoffPlan, _ name: String) throws -> Int {
            try #require(plan.milestones.first { $0.debtName == name }).month
        }
        func interest(_ plan: DebtPayoffPlan, _ name: String) throws -> Double {
            try #require(plan.milestones.first { $0.debtName == name }).interestPaid
        }

        // Note the order debts *retire* is not the order they are *targeted*:
        // the small Car Loan clears first under both strategies simply because
        // its own minimum outruns a 3,200 balance. What distinguishes the
        // strategies is which debt the surplus accelerates.

        // Avalanche accelerates the 22.9% card, so it clears sooner and cheaper
        #expect(try month(avalanche, "Credit Card") <= month(snowball, "Credit Card"))
        #expect(try interest(avalanche, "Credit Card") < interest(snowball, "Credit Card"))

        // Snowball accelerates the smallest balance, so it never clears later
        #expect(try month(snowball, "Car Loan") <= month(avalanche, "Car Loan"))

        // Every debt is eventually retired under both
        #expect(avalanche.milestones.count == 3)
        #expect(snowball.milestones.count == 3)
    }

    @Test func rolloverAndExtraPaymentBeatMinimumsOnly() async throws {
        let minimums = try DebtPayoffPlanner.plan(debts: sampleDebts, extraPayment: 0, strategy: .minimumsOnly)
        let avalanche = try DebtPayoffPlanner.plan(debts: sampleDebts, extraPayment: 200, strategy: .avalanche)

        #expect(avalanche.months < minimums.months)
        #expect(avalanche.totalInterest < minimums.totalInterest)
        // Minimums-only spends exactly the minimums, with nothing rolled over
        #expect(abs(minimums.monthlyBudget - 770) < 1e-9)
    }

    @Test func everyStrategyRepaysThePrincipalExactly() async throws {
        let startingBalance = sampleDebts.reduce(0) { $0 + $1.balance }

        for strategy in PayoffStrategy.allCases {
            let plan = try DebtPayoffPlanner.plan(debts: sampleDebts, extraPayment: 150, strategy: strategy)
            // Total paid must equal principal plus the interest that accrued
            #expect(abs(plan.totalPaid - (startingBalance + plan.totalInterest)) < 0.05)
            // And the balance timeline must actually reach zero
            #expect((plan.balanceTimeline.last?.totalBalance ?? 1) < 0.01)
        }
    }

    @Test func extraPaymentMonotonicallyShortensThePlan() async throws {
        let none = try DebtPayoffPlanner.plan(debts: sampleDebts, extraPayment: 0, strategy: .avalanche)
        let some = try DebtPayoffPlanner.plan(debts: sampleDebts, extraPayment: 250, strategy: .avalanche)
        let lots = try DebtPayoffPlanner.plan(debts: sampleDebts, extraPayment: 1_000, strategy: .avalanche)

        #expect(some.months < none.months)
        #expect(lots.months < some.months)
        #expect(lots.totalInterest < some.totalInterest)
        #expect(some.totalInterest < none.totalInterest)
    }

    @Test func aBudgetBelowTheAccruingInterestIsRejected() async throws {
        // 25% on 10,000 accrues ~208/month; a 50/month minimum cannot keep up
        let hopeless = [Debt(name: "Card", balance: 10_000, annualRate: 25, minimumPayment: 50)]

        #expect(throws: DebtPayoffError.self) {
            try DebtPayoffPlanner.plan(debts: hopeless, extraPayment: 0, strategy: .avalanche)
        }

        // Enough extra to outpace the interest makes it solvable again
        let plan = try DebtPayoffPlanner.plan(debts: hopeless, extraPayment: 400, strategy: .avalanche)
        #expect(plan.months > 0)
    }

    @Test func emptyDebtListIsRejected() async throws {
        #expect(throws: DebtPayoffError.self) {
            try DebtPayoffPlanner.plan(debts: [], extraPayment: 100, strategy: .avalanche)
        }
        // Zero balances count as nothing to pay off
        #expect(throws: DebtPayoffError.self) {
            try DebtPayoffPlanner.plan(
                debts: [Debt(name: "Paid", balance: 0, annualRate: 5, minimumPayment: 50)],
                extraPayment: 100,
                strategy: .avalanche
            )
        }
    }

    @Test func interestFreeDebtsRetireOnScheduleWithNoInterest() async throws {
        let debts = [
            Debt(name: "Family Loan", balance: 1_200, annualRate: 0, minimumPayment: 100),
            Debt(name: "Buy Now Pay Later", balance: 600, annualRate: 0, minimumPayment: 100)
        ]
        let plan = try DebtPayoffPlanner.plan(debts: debts, extraPayment: 0, strategy: .avalanche)

        #expect(plan.totalInterest < 1e-9)
        // 1,800 owed at 200/month clears in 9 months
        #expect(plan.months == 9)
        #expect(abs(plan.totalPaid - 1_800) < 0.01)
    }

    @Test func debtPayoffModelRoundTripsDebtsAndReportsAResult() async throws {
        let calculation = DebtPayoffCalculation(
            name: "Plan", debts: sampleDebts, extraPayment: 200, strategy: .avalanche
        )

        // Debts survive the JSON round-trip through the stored property
        #expect(calculation.debts.count == 3)
        #expect(calculation.debts.first?.name == "Credit Card")
        #expect(calculation.isValid)

        let result = calculation.result
        #expect(result.primaryValue > 0)
        #expect((result.secondaryValues["Total Interest"] ?? 0) > 0)
        #expect(result.chartData?.isEmpty == false)
    }

    // MARK: - Refinance analysis

    @Test func refinancePaymentAgreesWithTheLoanModel() async throws {
        let payment = RefinanceAnalyzer.monthlyPayment(
            principal: 300_000, annualRate: 6, months: 360
        )
        #expect(abs(payment - 1_798.65) < 0.01)

        // Zero-rate loans are straight division
        let zeroRate = RefinanceAnalyzer.monthlyPayment(principal: 12_000, annualRate: 0, months: 24)
        #expect(abs(zeroRate - 500) < 1e-9)
    }

    @Test func remainingBalanceMatchesAnIterativeAmortization() async throws {
        let principal = 300_000.0
        let rate = 6.0
        let term = 360
        let paymentsMade = 60

        // Walk the schedule by hand and compare against the closed form
        let payment = RefinanceAnalyzer.monthlyPayment(principal: principal, annualRate: rate, months: term)
        var balance = principal
        for _ in 0..<paymentsMade {
            balance += balance * (rate / 100 / 12)
            balance -= payment
        }

        let closedForm = RefinanceAnalyzer.remainingBalance(
            principal: principal, annualRate: rate, termMonths: term, paymentsMade: paymentsMade
        )
        #expect(abs(closedForm - balance) < 0.01)

        // Endpoints
        #expect(RefinanceAnalyzer.remainingBalance(
            principal: principal, annualRate: rate, termMonths: term, paymentsMade: 0
        ) == principal)
        #expect(RefinanceAnalyzer.remainingBalance(
            principal: principal, annualRate: rate, termMonths: term, paymentsMade: term
        ) < 0.01)
    }

    @Test func refinanceBreakEvenReflectsCashPaidAtClosing() async throws {
        // 250k at 6% with 25 years left, refinanced to 4.5% over the same 25 years
        let analysis = try #require(RefinanceAnalyzer.analyze(
            RefinanceScenario(
                currentBalance: 250_000, currentAnnualRate: 6, remainingMonths: 300,
                newAnnualRate: 4.5, newTermMonths: 300,
                closingCosts: 6_000, financeClosingCosts: false
            )
        ))

        #expect(analysis.monthlySavings > 0)
        #expect(analysis.upfrontCost == 6_000)

        // Break-even is the closing cost divided by the monthly saving
        let expected = Int((6_000 / analysis.monthlySavings).rounded(.up))
        #expect(analysis.breakEvenMonths == expected)

        // Same term at a lower rate must win on both axes
        #expect(analysis.lifetimeSavings > 0)
        #expect(analysis.newTotalInterest < analysis.currentRemainingInterest)
        #expect(!analysis.extendsTerm)
    }

    @Test func financingClosingCostsRemovesUpfrontCashButRaisesPrincipal() async throws {
        let scenario = RefinanceScenario(
            currentBalance: 250_000, currentAnnualRate: 6, remainingMonths: 300,
            newAnnualRate: 4.5, newTermMonths: 300,
            closingCosts: 6_000, financeClosingCosts: true
        )
        let analysis = try #require(RefinanceAnalyzer.analyze(scenario))

        #expect(analysis.upfrontCost == 0)
        #expect(analysis.newPrincipal == 256_000)
        // No cash at risk, so the saving starts immediately
        #expect(analysis.breakEvenMonths == 0)
    }

    @Test func stretchingTheTermCanLowerThePaymentAndRaiseTotalCost() async throws {
        // 22 years left, refinanced into a fresh 30 years at a slightly better rate
        let analysis = try #require(RefinanceAnalyzer.analyze(
            RefinanceScenario(
                currentBalance: 250_000, currentAnnualRate: 6, remainingMonths: 264,
                newAnnualRate: 5.5, newTermMonths: 360,
                closingCosts: 0, financeClosingCosts: false
            )
        ))

        #expect(analysis.extendsTerm)
        #expect(analysis.monthlySavings > 0)      // the payment falls
        #expect(analysis.lifetimeSavings < 0)     // yet the loan costs more overall
    }

    @Test func keepingTheOldPaymentRetiresTheNewLoanEarly() async throws {
        let analysis = try #require(RefinanceAnalyzer.analyze(
            RefinanceScenario(
                currentBalance: 250_000, currentAnnualRate: 6, remainingMonths: 300,
                newAnnualRate: 4.5, newTermMonths: 300,
                closingCosts: 0, financeClosingCosts: false
            )
        ))

        let months = try #require(analysis.samePaymentPayoffMonths)
        let saved = try #require(analysis.samePaymentInterestSaved)

        #expect(months < 300)
        #expect(saved > 0)
        #expect((analysis.samePaymentInterest ?? .infinity) < analysis.newTotalInterest)
    }

    @Test func refinanceRejectsUnusableInput() async throws {
        #expect(RefinanceAnalyzer.analyze(
            RefinanceScenario(
                currentBalance: 0, currentAnnualRate: 6, remainingMonths: 300,
                newAnnualRate: 4.5, newTermMonths: 300,
                closingCosts: 0, financeClosingCosts: false
            )
        ) == nil)

        #expect(RefinanceAnalyzer.analyze(
            RefinanceScenario(
                currentBalance: 250_000, currentAnnualRate: 6, remainingMonths: 300,
                newAnnualRate: 4.5, newTermMonths: 0,
                closingCosts: 0, financeClosingCosts: false
            )
        ) == nil)

        // A payment that cannot cover the first month's interest never retires the loan
        #expect(RefinanceAnalyzer.payoffMonths(principal: 100_000, annualRate: 6, payment: 100) == nil)
    }

    // MARK: - Monte Carlo retirement analysis

    /// Shared baseline: a comfortable plan used across the simulation tests.
    private func monteCarlo(
        volatility: Double,
        income: Double = 4_000,
        trials: RetirementMonteCarlo.TrialCount = .quick,
        seed: UInt64 = 0x5EED_5EED
    ) -> RetirementSimulationResult {
        RetirementMonteCarlo.analyze(
            currentAge: 40, retirementAge: 65, lifeExpectancy: 90,
            currentSavings: 200_000, monthlyContribution: 2_000,
            preRetirementReturn: 7, inRetirementReturn: 4,
            returnVolatility: volatility, inflationRate: 2.5,
            desiredMonthlyIncome: income, trials: trials, seed: seed
        )
    }

    @Test func monteCarloIsDeterministicForAGivenSeed() async throws {
        let first = monteCarlo(volatility: 12)
        let second = monteCarlo(volatility: 12)

        #expect(first.successProbability == second.successProbability)
        #expect(first.medianEndingBalance == second.medianEndingBalance)
        #expect(first.sustainableIncomeAt90 == second.sustainableIncomeAt90)
    }

    @Test func zeroVolatilityAgreesWithTheDeterministicProjection() async throws {
        // With no volatility every path is identical, so the outcome must be
        // all-or-nothing and must match the deterministic model's verdict.
        let simulated = monteCarlo(volatility: 0, income: 4_000)
        #expect(simulated.successProbability == 0 || simulated.successProbability == 1)

        let deterministic = RetirementPlanCalculation.project(
            currentAge: 40, retirementAge: 65, lifeExpectancy: 90,
            currentSavings: 200_000, monthlyContribution: 2_000,
            preRetirementReturn: 7, inRetirementReturn: 4, inflationRate: 2.5,
            desiredMonthlyIncome: 4_000
        )

        let deterministicSucceeds = deterministic.depletionAge == nil
        #expect((simulated.successProbability == 1) == deterministicSucceeds)
    }

    @Test func volatilityErodesAPlanThatHasMargin() async throws {
        // 4,000/mo sits well inside this plan's deterministic break-even (~5,930/mo),
        // so the only thing that can break it is sequence risk. Volatility drag bites
        // hard here: an independent reference implementation of the same model puts
        // calm near 98% and a 25%-volatility portfolio near 34%.
        let calm = monteCarlo(volatility: 4, income: 4_000)
        let stormy = monteCarlo(volatility: 25, income: 4_000)

        #expect(calm.successProbability > 0.9)
        #expect(stormy.successProbability < calm.successProbability)
    }

    @Test func volatilityIsTheOnlyHopeForAPlanThatCannotWork() async throws {
        // The mirror image: when the deterministic plan fails outright, success
        // requires luck, so dispersion can only help. This is why a low success
        // probability must be read alongside the deterministic gap, not instead of it.
        let calm = monteCarlo(volatility: 2, income: 12_000)
        let stormy = monteCarlo(volatility: 25, income: 12_000)

        #expect(calm.successProbability == 0)
        #expect(stormy.successProbability >= calm.successProbability)
    }

    @Test func successProbabilityAndPercentilesStayWellFormed() async throws {
        let result = monteCarlo(volatility: 15)

        #expect(result.successProbability >= 0 && result.successProbability <= 1)
        #expect(result.p10EndingBalance <= result.medianEndingBalance)
        #expect(result.medianEndingBalance <= result.p90EndingBalance)
        #expect(result.sustainableIncomeAt90 >= 0)
        #expect(!result.percentileBands.isEmpty)

        // Bands must be ordered within every year and span the whole horizon
        for band in result.percentileBands {
            #expect(band.p10 <= band.p50)
            #expect(band.p50 <= band.p90)
        }
        #expect(abs((result.percentileBands.first?.age ?? 0) - 40) < 0.001)
        #expect((result.percentileBands.last?.age ?? 0) >= 89)
    }

    @Test func sustainableIncomeClearsNinetyPercentConfidence() async throws {
        let result = monteCarlo(volatility: 12, income: 12_000)

        // The asked-for income is unaffordable here, so the solver must land lower
        #expect(result.successProbability < 0.9)
        #expect(result.sustainableIncomeAt90 < 12_000)

        // Re-running at the solved income should actually clear the bar
        let verified = monteCarlo(volatility: 12, income: result.sustainableIncomeAt90)
        #expect(verified.successProbability >= 0.85)
    }

    @Test func percentileInterpolatesBetweenSamples() async throws {
        let sorted = [0.0, 10.0, 20.0, 30.0, 40.0]
        #expect(RetirementMonteCarlo.percentile(sorted, 0) == 0)
        #expect(RetirementMonteCarlo.percentile(sorted, 1) == 40)
        #expect(RetirementMonteCarlo.percentile(sorted, 0.5) == 20)
        #expect(abs(RetirementMonteCarlo.percentile(sorted, 0.25) - 10) < 1e-9)
        #expect(RetirementMonteCarlo.percentile([], 0.5) == 0)
        #expect(RetirementMonteCarlo.percentile([7], 0.9) == 7)
    }

    @Test func seededGeneratorProducesAStableNormalDistribution() async throws {
        var sampler = NormalSampler(seed: 42)
        var samples: [Double] = []
        for _ in 0..<20_000 {
            samples.append(sampler.nextNormal())
        }

        let mean = samples.reduce(0, +) / Double(samples.count)
        let variance = samples.map { pow($0 - mean, 2) }.reduce(0, +) / Double(samples.count - 1)

        #expect(abs(mean) < 0.05)
        #expect(abs(variance - 1) < 0.05)
    }

    // MARK: - Unit conversion

    @Test func temperatureConversionsMatchKnownPoints() async throws {
        #expect(abs((UnitConverterView.convertTemperature(100, from: "°C", to: "°F") ?? 0) - 212) < 1e-9)
        #expect(abs((UnitConverterView.convertTemperature(32, from: "°F", to: "°C") ?? 1) - 0) < 1e-9)
        #expect(abs((UnitConverterView.convertTemperature(0, from: "°C", to: "K") ?? 0) - 273.15) < 1e-9)
        #expect(abs((UnitConverterView.convertTemperature(0, from: "°C", to: "°R") ?? 0) - 491.67) < 1e-9)
        #expect(UnitConverterView.convertTemperature(1, from: "°X", to: "°C") == nil)
    }

    // MARK: - CSV export

    @Test @MainActor func csvGenerationEscapesAndOrdersColumns() async throws {
        let csv = CalculationExporter.csvString(
            headers: ["Item", "Value"],
            rows: [
                ["Item": "Total, gross", "Value": "1,798.65"],
                ["Item": "Say \"hi\"", "Value": "2"],
            ]
        )
        let lines = csv.split(separator: "\n")
        #expect(lines[0] == "Item,Value")
        #expect(lines[1] == "\"Total, gross\",\"1,798.65\"")
        #expect(lines[2] == "\"Say \"\"hi\"\"\",2")
    }

    // MARK: - SwiftData persistence

    @Test @MainActor func modelsRoundTripThroughSwiftDataStore() async throws {
        let schema = Schema([
            FinancialCalculation.self,
            TimeValueCalculation.self,
            LoanCalculation.self,
            BondCalculation.self,
            InvestmentCalculation.self,
            DepreciationCalculation.self,
            OptionsCalculation.self,
            MathExpressionCalculation.self,
            CurrencyConversionCalculation.self,
            RetirementPlanCalculation.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)

        let loan = LoanCalculation(
            name: "Persisted Loan", principalAmount: 250_000,
            annualInterestRate: 5.5, loanTermYears: 15
        )
        let plan = RetirementPlanCalculation(
            name: "Persisted Plan", currentAge: 40, retirementAge: 65, lifeExpectancy: 90,
            currentSavings: 10_000, monthlyContribution: 500,
            preRetirementReturn: 6, inRetirementReturn: 4, inflationRate: 2.5,
            desiredMonthlyIncome: 4_000
        )
        context.insert(loan)
        context.insert(plan)
        try context.save()

        // Favorite round-trip
        plan.toggleFavorite()
        try context.save()

        let plans = try context.fetch(FetchDescriptor<RetirementPlanCalculation>())
        #expect(plans.count == 1)
        #expect(plans.first?.isFavorite == true)
        #expect(plans.first?.calculationType == .retirement)

        // Delete round-trip
        context.delete(loan)
        try context.save()
        let loans = try context.fetch(FetchDescriptor<LoanCalculation>())
        #expect(loans.isEmpty)
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
