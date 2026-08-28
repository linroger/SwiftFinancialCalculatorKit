//
//  RefinanceAnalyzer.swift
//  FinancialCalculatorKit
//
//  Compares an existing loan against a replacement. A lower monthly payment is
//  not the same as a cheaper loan — stretching the term can cut the payment
//  while raising lifetime interest — so this reports cash-flow savings and
//  lifetime cost separately, plus the break-even on closing costs.
//

import Foundation

struct RefinanceScenario {
    /// Balance still owed on the existing loan
    var currentBalance: Double
    /// Annual percentage rate on the existing loan
    var currentAnnualRate: Double
    /// Payments left on the existing loan
    var remainingMonths: Int

    /// Annual percentage rate being offered
    var newAnnualRate: Double
    /// Term of the replacement loan, in months
    var newTermMonths: Int
    /// Origination and closing costs
    var closingCosts: Double
    /// Roll the closing costs into the new principal instead of paying cash
    var financeClosingCosts: Bool
}

struct RefinanceAnalysis {
    let currentMonthlyPayment: Double
    let newMonthlyPayment: Double
    /// Positive when the new loan costs less each month
    let monthlySavings: Double

    /// Principal actually borrowed, including rolled-in costs
    let newPrincipal: Double
    /// Cash due at closing (zero when costs are financed)
    let upfrontCost: Double

    let currentRemainingInterest: Double
    let newTotalInterest: Double

    /// Total still to be paid on each path, closing costs included
    let currentTotalCost: Double
    let newTotalCost: Double
    /// Positive when the refinance costs less over the full life of the loans
    let lifetimeSavings: Double

    /// Months until accumulated monthly savings repay the cash paid at closing.
    /// `nil` when the payment does not fall, or when it never recoups.
    let breakEvenMonths: Int?

    /// True when the new loan runs past the end of the existing one
    let extendsTerm: Bool

    /// Keeping the old payment on the new loan: months to payoff, interest paid,
    /// and interest saved versus the new loan's scheduled term. `nil` when the
    /// old payment is not larger than the new one.
    let samePaymentPayoffMonths: Double?
    let samePaymentInterest: Double?
    let samePaymentInterestSaved: Double?
}

enum RefinanceAnalyzer {
    /// Monthly payment that fully amortizes `principal` at `annualRate` over `months`.
    static func monthlyPayment(principal: Double, annualRate: Double, months: Int) -> Double {
        guard principal > 0, months > 0 else { return 0 }
        let r = annualRate / 100 / 12
        if r == 0 {
            return principal / Double(months)
        }
        let growth = pow(1 + r, Double(months))
        return principal * (r * growth) / (growth - 1)
    }

    /// Months needed to retire `principal` at `annualRate` while paying `payment`
    /// each month. `nil` when the payment cannot cover the interest.
    static func payoffMonths(principal: Double, annualRate: Double, payment: Double) -> Double? {
        guard principal > 0, payment > 0 else { return nil }
        let r = annualRate / 100 / 12
        if r == 0 {
            return principal / payment
        }
        // The payment must exceed the first month's interest or the balance grows
        guard payment > principal * r else { return nil }
        return -Foundation.log(1 - principal * r / payment) / Foundation.log(1 + r)
    }

    static func analyze(_ scenario: RefinanceScenario) -> RefinanceAnalysis? {
        guard scenario.currentBalance > 0,
              scenario.remainingMonths > 0,
              scenario.newTermMonths > 0,
              scenario.currentAnnualRate >= 0,
              scenario.newAnnualRate >= 0,
              scenario.closingCosts >= 0 else {
            return nil
        }

        let currentPayment = monthlyPayment(
            principal: scenario.currentBalance,
            annualRate: scenario.currentAnnualRate,
            months: scenario.remainingMonths
        )

        let newPrincipal = scenario.currentBalance
            + (scenario.financeClosingCosts ? scenario.closingCosts : 0)
        let upfrontCost = scenario.financeClosingCosts ? 0 : scenario.closingCosts

        let newPayment = monthlyPayment(
            principal: newPrincipal,
            annualRate: scenario.newAnnualRate,
            months: scenario.newTermMonths
        )

        let currentTotalPayments = currentPayment * Double(scenario.remainingMonths)
        let newTotalPayments = newPayment * Double(scenario.newTermMonths)

        let currentRemainingInterest = currentTotalPayments - scenario.currentBalance
        let newTotalInterest = newTotalPayments - newPrincipal

        let currentTotalCost = currentTotalPayments
        let newTotalCost = newTotalPayments + upfrontCost

        let monthlySavings = currentPayment - newPayment

        // Break-even only applies to cash paid at closing; financed costs are
        // already carried inside the new payment.
        let breakEven: Int?
        if upfrontCost <= 0 {
            breakEven = monthlySavings > 0 ? 0 : nil
        } else if monthlySavings > 0 {
            let months = Int((upfrontCost / monthlySavings).rounded(.up))
            // Recouping only counts if it happens while the loan still exists
            breakEven = months <= scenario.newTermMonths ? months : nil
        } else {
            breakEven = nil
        }

        // Directing the old payment at the new loan retires it faster
        var samePaymentMonths: Double? = nil
        var samePaymentInterest: Double? = nil
        var samePaymentSaved: Double? = nil
        if currentPayment > newPayment,
           let months = payoffMonths(
               principal: newPrincipal,
               annualRate: scenario.newAnnualRate,
               payment: currentPayment
           ) {
            let interest = currentPayment * months - newPrincipal
            samePaymentMonths = months
            samePaymentInterest = interest
            samePaymentSaved = newTotalInterest - interest
        }

        return RefinanceAnalysis(
            currentMonthlyPayment: currentPayment,
            newMonthlyPayment: newPayment,
            monthlySavings: monthlySavings,
            newPrincipal: newPrincipal,
            upfrontCost: upfrontCost,
            currentRemainingInterest: currentRemainingInterest,
            newTotalInterest: newTotalInterest,
            currentTotalCost: currentTotalCost,
            newTotalCost: newTotalCost,
            lifetimeSavings: currentTotalCost - newTotalCost,
            breakEvenMonths: breakEven,
            extendsTerm: scenario.newTermMonths > scenario.remainingMonths,
            samePaymentPayoffMonths: samePaymentMonths,
            samePaymentInterest: samePaymentInterest,
            samePaymentInterestSaved: samePaymentSaved
        )
    }

    /// Remaining balance on a loan after `paymentsMade` payments.
    static func remainingBalance(
        principal: Double,
        annualRate: Double,
        termMonths: Int,
        paymentsMade: Int
    ) -> Double {
        guard principal > 0, termMonths > 0 else { return 0 }
        let made = min(max(paymentsMade, 0), termMonths)
        guard made > 0 else { return principal }

        let r = annualRate / 100 / 12
        let payment = monthlyPayment(principal: principal, annualRate: annualRate, months: termMonths)
        if r == 0 {
            return max(principal - payment * Double(made), 0)
        }

        let growth = pow(1 + r, Double(made))
        let balance = principal * growth - payment * (growth - 1) / r
        return max(balance, 0)
    }
}
