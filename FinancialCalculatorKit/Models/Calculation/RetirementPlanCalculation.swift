//
//  RetirementPlanCalculation.swift
//  FinancialCalculatorKit
//
//  Retirement planning model: accumulation projection, required nest egg,
//  sustainable income, and gap analysis.
//

import Foundation
import SwiftData

/// Full projection produced by the retirement math, kept separate from the
/// SwiftData model so it can be unit-tested as a pure function.
struct RetirementProjection {
    /// Balance expected at retirement from current savings plus contributions
    let projectedNestEgg: Double
    /// Present value (at retirement) of the desired inflation-growing withdrawals
    let requiredNestEgg: Double
    /// projectedNestEgg − requiredNestEgg; negative means a shortfall
    let surplus: Double
    /// First-month withdrawal the projected nest egg can sustain through the plan
    let sustainableFirstMonthWithdrawal: Double
    /// The sustainable withdrawal deflated back to today's purchasing power
    let sustainableMonthlyIncomeToday: Double
    /// Extra monthly contribution needed from now to close a shortfall (0 when on track)
    let additionalMonthlySavingsNeeded: Double
    /// Age at which the balance runs out when drawing the desired income; nil when it lasts
    let depletionAge: Double?
    /// Desired monthly income expressed in dollars of the retirement year
    let incomeAtRetirement: Double
    /// Yearly balance trajectory across accumulation and drawdown (x = age)
    let timeline: [ChartDataPoint]
}

/// Retirement planning calculation model
@Model
final class RetirementPlanCalculation {
    // MARK: - Common Properties
    var id: UUID
    var name: String
    private var calculationTypeRawValue: String = CalculationType.retirement.rawValue
    var createdDate: Date
    var lastModified: Date
    var notes: String
    var isFavorite: Bool
    private var currencyRawValue: String

    /// Computed property for calculationType
    var calculationType: CalculationType {
        get {
            CalculationType(rawValue: calculationTypeRawValue) ?? .retirement
        }
        set {
            calculationTypeRawValue = newValue.rawValue
        }
    }

    /// Computed property for currency
    var currency: Currency {
        get {
            Currency(rawValue: currencyRawValue) ?? .usd
        }
        set {
            currencyRawValue = newValue.rawValue
        }
    }

    // MARK: - Plan Inputs
    /// Current age in years
    var currentAge: Double

    /// Planned retirement age in years
    var retirementAge: Double

    /// Age the plan must fund through
    var lifeExpectancy: Double

    /// Savings already accumulated
    var currentSavings: Double

    /// Contribution made at the end of each month until retirement
    var monthlyContribution: Double

    /// Expected annual return before retirement (percent)
    var preRetirementReturn: Double

    /// Expected annual return during retirement (percent)
    var inRetirementReturn: Double

    /// Expected annual inflation (percent)
    var inflationRate: Double

    /// Desired gross monthly income in today's purchasing power
    var desiredMonthlyIncome: Double

    init(
        name: String,
        currentAge: Double,
        retirementAge: Double,
        lifeExpectancy: Double,
        currentSavings: Double,
        monthlyContribution: Double,
        preRetirementReturn: Double,
        inRetirementReturn: Double,
        inflationRate: Double,
        desiredMonthlyIncome: Double,
        currency: Currency = .usd
    ) {
        self.id = UUID()
        self.name = name
        self.createdDate = Date()
        self.lastModified = Date()
        self.notes = ""
        self.isFavorite = false
        self.currencyRawValue = currency.rawValue

        self.currentAge = currentAge
        self.retirementAge = retirementAge
        self.lifeExpectancy = lifeExpectancy
        self.currentSavings = currentSavings
        self.monthlyContribution = monthlyContribution
        self.preRetirementReturn = preRetirementReturn
        self.inRetirementReturn = inRetirementReturn
        self.inflationRate = inflationRate
        self.desiredMonthlyIncome = desiredMonthlyIncome
    }

    // MARK: - Common Protocol Methods

    /// Update the last modified timestamp
    func updateTimestamp() {
        lastModified = Date()
    }

    /// Toggle favorite status
    func toggleFavorite() {
        isFavorite.toggle()
        updateTimestamp()
    }

    var result: CalculationResult {
        guard isValid else {
            return CalculationResult(
                primaryValue: 0.0,
                formattedPrimaryValue: "Invalid inputs",
                explanation: "Please provide valid inputs for all required fields."
            )
        }

        let projection = RetirementPlanCalculation.project(
            currentAge: currentAge,
            retirementAge: retirementAge,
            lifeExpectancy: lifeExpectancy,
            currentSavings: currentSavings,
            monthlyContribution: monthlyContribution,
            preRetirementReturn: preRetirementReturn,
            inRetirementReturn: inRetirementReturn,
            inflationRate: inflationRate,
            desiredMonthlyIncome: desiredMonthlyIncome
        )

        var secondaryValues: [String: Double] = [:]
        secondaryValues["Required Nest Egg"] = projection.requiredNestEgg
        secondaryValues["Income at Retirement (Future Dollars)"] = projection.incomeAtRetirement
        secondaryValues["Sustainable Income (Today's Dollars)"] = projection.sustainableMonthlyIncomeToday
        secondaryValues["Years to Retirement"] = retirementAge - currentAge
        secondaryValues["Years in Retirement"] = lifeExpectancy - retirementAge

        let explanation: String
        if projection.surplus >= 0 {
            secondaryValues["Projected Surplus"] = projection.surplus
            explanation = "On track: the projected balance at retirement covers the desired income through age \(Int(lifeExpectancy))."
        } else {
            secondaryValues["Projected Shortfall"] = -projection.surplus
            secondaryValues["Additional Monthly Savings Needed"] = projection.additionalMonthlySavingsNeeded
            if let depletionAge = projection.depletionAge {
                explanation = "Shortfall: at the desired income the balance runs out around age \(Int(depletionAge)). Save more, retire later, or plan for less income."
            } else {
                explanation = "Shortfall: the projected balance does not fully cover the desired income through age \(Int(lifeExpectancy))."
            }
        }

        return CalculationResult(
            primaryValue: projection.projectedNestEgg,
            secondaryValues: secondaryValues,
            formattedPrimaryValue: currency.formatValue(projection.projectedNestEgg),
            explanation: explanation,
            chartData: projection.timeline
        )
    }

    var isValid: Bool {
        validationErrors.isEmpty
    }

    var validationErrors: [String] {
        var errors: [String] = []

        if name.isEmpty {
            errors.append("Name is required")
        }
        if currentAge <= 0 || currentAge >= 120 {
            errors.append("Current age must be between 1 and 119")
        }
        if retirementAge <= currentAge {
            errors.append("Retirement age must be after the current age")
        }
        if lifeExpectancy <= retirementAge {
            errors.append("Life expectancy must be after the retirement age")
        }
        if currentSavings < 0 {
            errors.append("Current savings cannot be negative")
        }
        if monthlyContribution < 0 {
            errors.append("Monthly contribution cannot be negative")
        }
        if preRetirementReturn < 0 || inRetirementReturn < 0 {
            errors.append("Return rates cannot be negative")
        }
        if inflationRate < 0 {
            errors.append("Inflation rate cannot be negative")
        }
        if desiredMonthlyIncome <= 0 {
            errors.append("Desired monthly income must be positive")
        }

        return errors
    }

    // MARK: - Projection Math (pure, unit-tested)

    /// Run the full retirement projection. All rates are annual percentages;
    /// contributions and withdrawals happen at the end of each month.
    static func project(
        currentAge: Double,
        retirementAge: Double,
        lifeExpectancy: Double,
        currentSavings: Double,
        monthlyContribution: Double,
        preRetirementReturn: Double,
        inRetirementReturn: Double,
        inflationRate: Double,
        desiredMonthlyIncome: Double
    ) -> RetirementProjection {
        let monthsToRetirement = max(Int(((retirementAge - currentAge) * 12).rounded()), 1)
        let monthsInRetirement = max(Int(((lifeExpectancy - retirementAge) * 12).rounded()), 1)
        let accumulationRate = preRetirementReturn / 100 / 12
        let drawdownRate = inRetirementReturn / 100 / 12
        let monthlyInflation = inflationRate / 100 / 12

        // Accumulation: FV of current savings plus an ordinary annuity of contributions
        let growth = pow(1 + accumulationRate, Double(monthsToRetirement))
        let annuityFactor: Double
        if accumulationRate == 0 {
            annuityFactor = Double(monthsToRetirement)
        } else {
            annuityFactor = (growth - 1) / accumulationRate
        }
        let projectedNestEgg = currentSavings * growth + monthlyContribution * annuityFactor

        // Desired income expressed in retirement-year dollars
        let incomeAtRetirement = desiredMonthlyIncome * pow(1 + monthlyInflation, Double(monthsToRetirement))

        // Required nest egg: PV at retirement of a withdrawal stream that starts at
        // incomeAtRetirement and grows with inflation each month (growing annuity)
        let requiredNestEgg = growingAnnuityPresentValue(
            firstPayment: incomeAtRetirement,
            ratePerPeriod: drawdownRate,
            growthPerPeriod: monthlyInflation,
            periods: monthsInRetirement
        )

        let surplus = projectedNestEgg - requiredNestEgg

        // Sustainable withdrawal: scale the desired stream to what the projection funds
        let sustainableFirstWithdrawal: Double
        if requiredNestEgg > 0 {
            sustainableFirstWithdrawal = incomeAtRetirement * (projectedNestEgg / requiredNestEgg)
        } else {
            sustainableFirstWithdrawal = 0
        }
        let sustainableToday = sustainableFirstWithdrawal / pow(1 + monthlyInflation, Double(monthsToRetirement))

        // Extra monthly contribution needed from now to close a shortfall
        let additionalMonthlySavings: Double
        if surplus >= 0 {
            additionalMonthlySavings = 0
        } else {
            additionalMonthlySavings = -surplus / annuityFactor
        }

        // Simulate the drawdown to find the depletion age and build the timeline
        var timeline: [ChartDataPoint] = []
        var balance = currentSavings
        timeline.append(ChartDataPoint(x: currentAge, y: balance, label: "Age \(Int(currentAge))"))
        for month in 1...monthsToRetirement {
            balance = balance * (1 + accumulationRate) + monthlyContribution
            if month % 12 == 0 || month == monthsToRetirement {
                let age = currentAge + Double(month) / 12
                timeline.append(ChartDataPoint(x: age, y: balance, label: "Age \(Int(age))"))
            }
        }

        var depletionAge: Double? = nil
        var withdrawal = incomeAtRetirement
        for month in 1...monthsInRetirement {
            balance = balance * (1 + drawdownRate) - withdrawal
            withdrawal *= (1 + monthlyInflation)
            let age = retirementAge + Double(month) / 12
            if balance <= 0 {
                depletionAge = age
                timeline.append(ChartDataPoint(x: age, y: 0, label: "Depleted"))
                break
            }
            if month % 12 == 0 || month == monthsInRetirement {
                timeline.append(ChartDataPoint(x: age, y: balance, label: "Age \(Int(age))"))
            }
        }

        return RetirementProjection(
            projectedNestEgg: projectedNestEgg,
            requiredNestEgg: requiredNestEgg,
            surplus: surplus,
            sustainableFirstMonthWithdrawal: sustainableFirstWithdrawal,
            sustainableMonthlyIncomeToday: sustainableToday,
            additionalMonthlySavingsNeeded: additionalMonthlySavings,
            depletionAge: depletionAge,
            incomeAtRetirement: incomeAtRetirement,
            timeline: timeline
        )
    }

    /// PV of an ordinary annuity whose payment grows at `growthPerPeriod` each period.
    static func growingAnnuityPresentValue(
        firstPayment: Double,
        ratePerPeriod: Double,
        growthPerPeriod: Double,
        periods: Int
    ) -> Double {
        guard periods > 0, firstPayment > 0 else { return 0 }

        if abs(ratePerPeriod - growthPerPeriod) < 1e-12 {
            // r == g degenerate case: each term discounts to firstPayment / (1+r)
            return firstPayment * Double(periods) / (1 + ratePerPeriod)
        }

        let ratio = (1 + growthPerPeriod) / (1 + ratePerPeriod)
        return firstPayment * (1 - pow(ratio, Double(periods))) / (ratePerPeriod - growthPerPeriod)
    }
}

// MARK: - Protocol Conformance

extension RetirementPlanCalculation: FinancialCalculationProtocol {}
