//
//  CalculationEngine.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import Foundation
import Numerics
import RealModule
import ComplexModule
import MathParser

/// Core financial calculation engine implementing standard financial formulas with advanced mathematical capabilities
class CalculationEngine {
    struct OptionGreeks {
        let delta: Double
        let gamma: Double
        let theta: Double
        let vega: Double
        let rho: Double
    }

    struct BondRiskMeasures {
        let modifiedDuration: Double
        let macaulayDuration: Double
        let convexity: Double
    }
    
    // MARK: - Mathematical Expression Evaluation
    
    /// Evaluate mathematical expressions using the MathParser, resolving user-defined variables.
    static func evaluateExpression(_ expressionString: String, with variables: [String: Double] = [:]) -> Double? {
        let parser = MathParser(variables: { variables[$0] })
        guard let evaluator = parser.parse(expressionString) else { return nil }
        let result = evaluator.eval()
        return result.isNaN ? nil : result
    }

    /// Parse and evaluate complex mathematical expressions using MathParser
    static func evaluateMathExpression(_ expressionString: String) -> Double? {
        evaluateExpression(expressionString)
    }
    
    // MARK: - Advanced Numerical Methods
    
    /// Calculate accurate compound interest using high-precision arithmetic
    static func calculateCompoundInterestPrecise(
        principal: Double,
        rate: Double,
        compoundingFrequency: Double,
        years: Double
    ) -> Double {
        let r = rate / (100.0 * compoundingFrequency)
        let nt = compoundingFrequency * years
        return principal * pow(1 + r, nt)
    }
    
    /// Calculate logarithmic operations with enhanced precision
    static func calculateLogReturn(initialValue: Double, finalValue: Double) -> Double {
        guard initialValue > 0 && finalValue > 0 else { return 0 }
        return Double.log(finalValue / initialValue)
    }
    
    /// Calculate exponential growth with high precision
    static func calculateExponentialGrowth(
        initialValue: Double,
        growthRate: Double,
        periods: Double
    ) -> Double {
        return initialValue * Double.exp(growthRate * periods)
    }
    
    // MARK: - Statistical Financial Analysis
    
    /// Calculate standard deviation of returns
    static func calculateStandardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count - 1)
        return Double.sqrt(variance)
    }
    
    /// Calculate Sharpe ratio
    static func calculateSharpeRatio(
        returns: [Double],
        riskFreeRate: Double
    ) -> Double {
        guard returns.count > 1 else { return 0 }
        
        let meanReturn = returns.reduce(0, +) / Double(returns.count)
        let excessReturn = meanReturn - riskFreeRate / 100
        let stdDev = calculateStandardDeviation(returns)
        
        return stdDev != 0 ? excessReturn / stdDev : 0
    }
    
    /// Calculate Value at Risk (VaR) using parametric method
    static func calculateVaR(
        portfolioValue: Double,
        expectedReturn: Double,
        volatility: Double,
        confidenceLevel: Double = 0.95,
        timeHorizon: Double = 1
    ) -> Double {
        // Using normal distribution approximation
        let zScore = inverseNormalCDF(min(max(confidenceLevel, 0.5), 0.9999))
        let portfolioReturn = expectedReturn / 100 * timeHorizon
        let portfolioVolatility = volatility / 100 * Double.sqrt(timeHorizon)
        
        return portfolioValue * (portfolioReturn - zScore * portfolioVolatility)
    }
    
    // MARK: - Advanced Bond Calculations
    
    /// Calculate bond duration using precise methods
    static func calculateModifiedDuration(
        faceValue: Double,
        couponRate: Double,
        marketRate: Double,
        yearsToMaturity: Double,
        paymentsPerYear: Double = 2
    ) -> Double {
        let macaulayDuration = calculateMacaulayDuration(
            faceValue: faceValue,
            couponRate: couponRate,
            marketRate: marketRate,
            yearsToMaturity: yearsToMaturity,
            paymentsPerYear: paymentsPerYear
        )
        
        let periodicRate = marketRate / 100 / paymentsPerYear
        return macaulayDuration / (1 + periodicRate)
    }
    
    /// Calculate Macaulay duration
    static func calculateMacaulayDuration(
        faceValue: Double,
        couponRate: Double,
        marketRate: Double,
        yearsToMaturity: Double,
        paymentsPerYear: Double = 2
    ) -> Double {
        let periodicCoupon = (faceValue * couponRate / 100) / paymentsPerYear
        let periodicRate = marketRate / 100 / paymentsPerYear
        let totalPeriods = yearsToMaturity * paymentsPerYear
        let wholePeriods = Int(totalPeriods)
        guard totalPeriods > 0, periodicRate > -1 else { return 0 }

        var weightedCashFlows = 0.0
        var totalPresentValue = 0.0

        // Calculate weighted present value of coupon payments
        if wholePeriods >= 1 {
            for period in 1...wholePeriods {
                let pv = periodicCoupon / pow(1 + periodicRate, Double(period))
                weightedCashFlows += pv * Double(period)
                totalPresentValue += pv
            }
        }
        
        // Add present value of face value
        let facePV = faceValue / pow(1 + periodicRate, totalPeriods)
        weightedCashFlows += facePV * totalPeriods
        totalPresentValue += facePV

        guard totalPresentValue > 0 else { return 0 }
        return (weightedCashFlows / totalPresentValue) / paymentsPerYear
    }
    
    /// Calculate bond convexity for risk management
    static func calculateConvexity(
        faceValue: Double,
        couponRate: Double,
        marketRate: Double,
        yearsToMaturity: Double,
        paymentsPerYear: Double = 2
    ) -> Double {
        let periodicCoupon = (faceValue * couponRate / 100) / paymentsPerYear
        let periodicRate = marketRate / 100 / paymentsPerYear
        let totalPeriods = yearsToMaturity * paymentsPerYear
        let wholePeriods = Int(totalPeriods)
        guard totalPeriods > 0, periodicRate > -1 else { return 0 }

        var convexitySum = 0.0
        let bondPrice = calculateBondPrice(
            faceValue: faceValue,
            couponRate: couponRate,
            marketRate: marketRate,
            yearsToMaturity: yearsToMaturity,
            paymentsPerYear: paymentsPerYear
        )
        guard bondPrice > 0 else { return 0 }

        // Calculate convexity for coupon payments
        if wholePeriods >= 1 {
            for period in 1...wholePeriods {
                let cashFlow = periodicCoupon
                let pv = cashFlow / pow(1 + periodicRate, Double(period))
                convexitySum += pv * Double(period) * (Double(period) + 1)
            }
        }

        // Add convexity for face value
        let facePV = faceValue / pow(1 + periodicRate, totalPeriods)
        convexitySum += facePV * totalPeriods * (totalPeriods + 1)

        return convexitySum / (bondPrice * pow(1 + periodicRate, 2) * pow(paymentsPerYear, 2))
    }

    static func calculateBondRiskMeasures(
        faceValue: Double,
        couponRate: Double,
        marketRate: Double,
        yearsToMaturity: Double,
        paymentsPerYear: Double = 2
    ) -> BondRiskMeasures {
        let macaulayDuration = calculateMacaulayDuration(
            faceValue: faceValue,
            couponRate: couponRate,
            marketRate: marketRate,
            yearsToMaturity: yearsToMaturity,
            paymentsPerYear: paymentsPerYear
        )
        let modifiedDuration = calculateModifiedDuration(
            faceValue: faceValue,
            couponRate: couponRate,
            marketRate: marketRate,
            yearsToMaturity: yearsToMaturity,
            paymentsPerYear: paymentsPerYear
        )
        let convexity = calculateConvexity(
            faceValue: faceValue,
            couponRate: couponRate,
            marketRate: marketRate,
            yearsToMaturity: yearsToMaturity,
            paymentsPerYear: paymentsPerYear
        )

        return BondRiskMeasures(
            modifiedDuration: modifiedDuration,
            macaulayDuration: macaulayDuration,
            convexity: convexity
        )
    }

    /// Approximates price impact using modified duration and convexity.
    /// `yieldChange` is expressed as a decimal, so 100 bps = 0.01.
    static func estimateBondPriceChange(
        currentPrice: Double,
        modifiedDuration: Double,
        convexity: Double,
        yieldChange: Double
    ) -> Double {
        let percentageChange = (-modifiedDuration * yieldChange) + (0.5 * convexity * pow(yieldChange, 2))
        return currentPrice * percentageChange
    }
    
    // MARK: - Options Pricing (Black-Scholes Model)
    
    /// Calculate Black-Scholes option price
    static func calculateBlackScholesOptionPrice(
        spotPrice: Double,
        strikePrice: Double,
        timeToExpiry: Double,
        riskFreeRate: Double,
        volatility: Double,
        optionType: OptionType = .call
    ) -> Double {
        guard let terms = normalizedOptionTerms(
            spotPrice: spotPrice,
            strikePrice: strikePrice,
            timeToExpiry: timeToExpiry,
            riskFreeRate: riskFreeRate,
            volatility: volatility
        ) else {
            return 0
        }
        
        let d1 = terms.d1
        let d2 = terms.d2
        
        let nd1 = cumulativeNormalDistribution(d1)
        let nd2 = cumulativeNormalDistribution(d2)
        let nNegD1 = cumulativeNormalDistribution(-d1)
        let nNegD2 = cumulativeNormalDistribution(-d2)
        
        let discountFactor = Double.exp(-terms.rate * timeToExpiry)
        
        switch optionType {
        case .call:
            return spotPrice * nd1 - strikePrice * discountFactor * nd2
        case .put:
            return strikePrice * discountFactor * nNegD2 - spotPrice * nNegD1
        }
    }
    
    /// Calculate option Greeks
    static func calculateOptionDelta(
        spotPrice: Double,
        strikePrice: Double,
        timeToExpiry: Double,
        riskFreeRate: Double,
        volatility: Double,
        optionType: OptionType = .call
    ) -> Double {
        guard let terms = normalizedOptionTerms(
            spotPrice: spotPrice,
            strikePrice: strikePrice,
            timeToExpiry: timeToExpiry,
            riskFreeRate: riskFreeRate,
            volatility: volatility
        ) else {
            return 0
        }
        
        switch optionType {
        case .call:
            return cumulativeNormalDistribution(terms.d1)
        case .put:
            return cumulativeNormalDistribution(terms.d1) - 1
        }
    }

    static func calculateOptionGamma(
        spotPrice: Double,
        strikePrice: Double,
        timeToExpiry: Double,
        riskFreeRate: Double,
        volatility: Double
    ) -> Double {
        guard let terms = normalizedOptionTerms(
            spotPrice: spotPrice,
            strikePrice: strikePrice,
            timeToExpiry: timeToExpiry,
            riskFreeRate: riskFreeRate,
            volatility: volatility
        ) else {
            return 0
        }

        return normalDensity(terms.d1) / (spotPrice * terms.sigma * Double.sqrt(timeToExpiry))
    }

    /// Returns theta per calendar day.
    static func calculateOptionTheta(
        spotPrice: Double,
        strikePrice: Double,
        timeToExpiry: Double,
        riskFreeRate: Double,
        volatility: Double,
        optionType: OptionType = .call
    ) -> Double {
        guard let terms = normalizedOptionTerms(
            spotPrice: spotPrice,
            strikePrice: strikePrice,
            timeToExpiry: timeToExpiry,
            riskFreeRate: riskFreeRate,
            volatility: volatility
        ) else {
            return 0
        }

        let firstTerm = -(spotPrice * normalDensity(terms.d1) * terms.sigma) / (2 * Double.sqrt(timeToExpiry))
        let discountFactor = Double.exp(-terms.rate * timeToExpiry)

        let annualTheta: Double
        switch optionType {
        case .call:
            annualTheta = firstTerm - terms.rate * strikePrice * discountFactor * cumulativeNormalDistribution(terms.d2)
        case .put:
            annualTheta = firstTerm + terms.rate * strikePrice * discountFactor * cumulativeNormalDistribution(-terms.d2)
        }

        return annualTheta / 365
    }

    /// Returns vega for a 1 percentage-point volatility move.
    static func calculateOptionVega(
        spotPrice: Double,
        strikePrice: Double,
        timeToExpiry: Double,
        riskFreeRate: Double,
        volatility: Double
    ) -> Double {
        guard let terms = normalizedOptionTerms(
            spotPrice: spotPrice,
            strikePrice: strikePrice,
            timeToExpiry: timeToExpiry,
            riskFreeRate: riskFreeRate,
            volatility: volatility
        ) else {
            return 0
        }

        return (spotPrice * normalDensity(terms.d1) * Double.sqrt(timeToExpiry)) / 100
    }

    /// Returns rho for a 1 percentage-point interest-rate move.
    static func calculateOptionRho(
        spotPrice: Double,
        strikePrice: Double,
        timeToExpiry: Double,
        riskFreeRate: Double,
        volatility: Double,
        optionType: OptionType = .call
    ) -> Double {
        guard let terms = normalizedOptionTerms(
            spotPrice: spotPrice,
            strikePrice: strikePrice,
            timeToExpiry: timeToExpiry,
            riskFreeRate: riskFreeRate,
            volatility: volatility
        ) else {
            return 0
        }

        let discountFactor = Double.exp(-terms.rate * timeToExpiry)
        switch optionType {
        case .call:
            return (strikePrice * timeToExpiry * discountFactor * cumulativeNormalDistribution(terms.d2)) / 100
        case .put:
            return (-strikePrice * timeToExpiry * discountFactor * cumulativeNormalDistribution(-terms.d2)) / 100
        }
    }

    static func calculateOptionGreeks(
        spotPrice: Double,
        strikePrice: Double,
        timeToExpiry: Double,
        riskFreeRate: Double,
        volatility: Double,
        optionType: OptionType = .call
    ) -> OptionGreeks {
        OptionGreeks(
            delta: calculateOptionDelta(
                spotPrice: spotPrice,
                strikePrice: strikePrice,
                timeToExpiry: timeToExpiry,
                riskFreeRate: riskFreeRate,
                volatility: volatility,
                optionType: optionType
            ),
            gamma: calculateOptionGamma(
                spotPrice: spotPrice,
                strikePrice: strikePrice,
                timeToExpiry: timeToExpiry,
                riskFreeRate: riskFreeRate,
                volatility: volatility
            ),
            theta: calculateOptionTheta(
                spotPrice: spotPrice,
                strikePrice: strikePrice,
                timeToExpiry: timeToExpiry,
                riskFreeRate: riskFreeRate,
                volatility: volatility,
                optionType: optionType
            ),
            vega: calculateOptionVega(
                spotPrice: spotPrice,
                strikePrice: strikePrice,
                timeToExpiry: timeToExpiry,
                riskFreeRate: riskFreeRate,
                volatility: volatility
            ),
            rho: calculateOptionRho(
                spotPrice: spotPrice,
                strikePrice: strikePrice,
                timeToExpiry: timeToExpiry,
                riskFreeRate: riskFreeRate,
                volatility: volatility,
                optionType: optionType
            )
        )
    }
    
    // MARK: - Utility Functions
    
    /// Cumulative standard normal distribution: N(x) = 0.5 * (1 + erf(x / sqrt(2)))
    private static func cumulativeNormalDistribution(_ x: Double) -> Double {
        0.5 * (1.0 + erf(x / Double.sqrt(2.0)))
    }

    /// Inverse cumulative standard normal distribution (Acklam's rational approximation,
    /// refined with one Halley step). Valid for p in (0, 1).
    static func inverseNormalCDF(_ p: Double) -> Double {
        guard p > 0, p < 1 else { return p <= 0 ? -Double.infinity : Double.infinity }

        let a: [Double] = [-3.969683028665376e+01,  2.209460984245205e+02, -2.759285104469687e+02,
                            1.383577518672690e+02, -3.066479806614716e+01,  2.506628277459239e+00]
        let b: [Double] = [-5.447609879822406e+01,  1.615858368580409e+02, -1.556989798598866e+02,
                            6.680131188771972e+01, -1.328068155288572e+01]
        let c: [Double] = [-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
                           -2.549732539343734e+00,  4.374664141464968e+00,  2.938163982698783e+00]
        let d: [Double] = [ 7.784695709041462e-03,  3.224671290700398e-01,  2.445134137142996e+00,
                            3.754408661907416e+00]

        let pLow = 0.02425
        var x: Double

        if p < pLow {
            let q = Double.sqrt(-2 * Double.log(p))
            x = (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
                ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        } else if p <= 1 - pLow {
            let q = p - 0.5
            let r = q * q
            x = (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q /
                (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1)
        } else {
            let q = Double.sqrt(-2 * Double.log(1 - p))
            x = -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
                 ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        }

        // One Halley refinement step for full double precision
        let e = cumulativeNormalDistribution(x) - p
        let u = e * Double.sqrt(2 * Double.pi) * Double.exp(x * x / 2)
        x = x - u / (1 + x * u / 2)
        return x
    }

    private static func normalDensity(_ x: Double) -> Double {
        (1 / Double.sqrt(2 * Double.pi)) * Double.exp(-0.5 * x * x)
    }

    private static func normalizedOptionTerms(
        spotPrice: Double,
        strikePrice: Double,
        timeToExpiry: Double,
        riskFreeRate: Double,
        volatility: Double
    ) -> (d1: Double, d2: Double, rate: Double, sigma: Double)? {
        guard spotPrice > 0,
              strikePrice > 0,
              timeToExpiry > 0,
              volatility > 0 else {
            return nil
        }

        let rate = riskFreeRate / 100
        let sigma = volatility / 100
        let denominator = sigma * Double.sqrt(timeToExpiry)
        guard denominator > 0 else { return nil }

        let d1 = (Double.log(spotPrice / strikePrice) + (rate + pow(sigma, 2) / 2) * timeToExpiry) / denominator
        let d2 = d1 - denominator

        return (d1, d2, rate, sigma)
    }
    
    enum OptionType {
        case call
        case put
    }
    
    // MARK: - Time Value of Money Calculations
    
    /// Calculate Present Value.
    ///
    /// Uses the savings/goal convention `FV = PV·(1+r)^n + PMT·s(r)`, so the amount needed
    /// today is the discounted target minus the discounted value of the payment stream:
    /// `PV = FV/(1+r)^n − PMT·a(r)`. With no payments this is the textbook lump-sum discount.
    static func calculatePresentValue(
        futureValue: Double? = nil,
        payment: Double? = nil,
        interestRate: Double,
        numberOfPeriods: Double,
        paymentAtBeginning: Bool = false
    ) -> Double {
        let r = interestRate / 100.0
        guard r > -1 else { return .nan }

        var pv = 0.0

        // Present value of the target lump sum
        if let fv = futureValue {
            pv += fv / pow(1 + r, numberOfPeriods)
        }

        // Payments contribute toward the target, reducing the amount needed today
        if let pmt = payment, r != 0 {
            let annuityPV = pmt * (1 - pow(1 + r, -numberOfPeriods)) / r
            pv -= paymentAtBeginning ? annuityPV * (1 + r) : annuityPV
        } else if let pmt = payment, r == 0 {
            pv -= pmt * numberOfPeriods
        }

        return pv
    }
    
    /// Calculate Future Value
    /// FV = PV * (1 + r)^n  OR  FV = PMT * [((1 + r)^n - 1) / r]
    static func calculateFutureValue(
        presentValue: Double? = nil,
        payment: Double? = nil,
        interestRate: Double,
        numberOfPeriods: Double,
        paymentAtBeginning: Bool = false
    ) -> Double {
        let r = interestRate / 100.0
        guard r > -1 else { return .nan }

        var fv = 0.0

        // Future value of lump sum
        if let pv = presentValue {
            fv += pv * pow(1 + r, numberOfPeriods)
        }
        
        // Future value of annuity
        if let pmt = payment, r != 0 {
            let annuityFV = pmt * (pow(1 + r, numberOfPeriods) - 1) / r
            fv += paymentAtBeginning ? annuityFV * (1 + r) : annuityFV
        } else if let pmt = payment, r == 0 {
            fv += pmt * numberOfPeriods
        }
        
        return fv
    }
    
    /// Calculate Payment.
    ///
    /// Savings/goal convention: solves `FV = PV·(1+r)^n + PMT·s(r)` for PMT, so
    /// `PMT = (FV − PV·(1+r)^n)·r / ((1+r)^n − 1)`. A positive result is a required
    /// contribution; a negative result means the starting balance already exceeds the
    /// target (a sustainable withdrawal, or a loan payment when FV is 0).
    static func calculatePayment(
        presentValue: Double? = nil,
        futureValue: Double? = nil,
        interestRate: Double,
        numberOfPeriods: Double,
        paymentAtBeginning: Bool = false
    ) -> Double {
        let r = interestRate / 100.0
        guard r > -1, numberOfPeriods > 0 else { return .nan }

        let pv = presentValue ?? 0
        let fv = futureValue ?? 0

        if r == 0 {
            return (fv - pv) / numberOfPeriods
        }

        let growth = pow(1 + r, numberOfPeriods)
        var pmt = (fv - pv * growth) * r / (growth - 1)

        if paymentAtBeginning {
            pmt /= (1 + r)
        }

        return pmt
    }

    /// Calculate the periodic interest rate (in percent per period) that satisfies
    /// `FV = PV·(1+r)^n + PMT·s(r)`. Uses a bracket scan followed by bisection.
    /// Returns `.nan` when no solution exists in (−99%, 1000%) per period.
    static func calculateInterestRate(
        presentValue: Double? = nil,
        futureValue: Double? = nil,
        payment: Double? = nil,
        numberOfPeriods: Double,
        paymentAtBeginning: Bool = false
    ) -> Double {
        guard numberOfPeriods > 0 else { return .nan }

        let pv = presentValue ?? 0
        let fv = futureValue ?? 0
        let pmt = payment ?? 0

        // Shortfall of the accumulated balance versus the target at rate r
        func goal(_ r: Double) -> Double {
            let growth = pow(1 + r, numberOfPeriods)
            let annuity: Double
            if abs(r) < 1e-12 {
                annuity = pmt * numberOfPeriods
            } else {
                let s = (growth - 1) / r
                annuity = pmt * (paymentAtBeginning ? s * (1 + r) : s)
            }
            return pv * growth + annuity - fv
        }

        // Scan for a sign change across a wide range of per-period rates
        var lower = -0.99
        var fLower = goal(lower)
        var upper: Double? = nil

        var probe = lower
        while probe < 10.0 {
            let next = probe < 0 ? probe + 0.01 : (probe < 1 ? probe + 0.005 : probe + 0.1)
            let fNext = goal(next)
            if fLower.isFinite, fNext.isFinite, fLower * fNext <= 0 {
                lower = probe
                upper = next
                break
            }
            probe = next
            fLower = fNext
        }

        guard var upperBound = upper else { return .nan }
        fLower = goal(lower)

        for _ in 0..<200 {
            let mid = (lower + upperBound) / 2
            let fMid = goal(mid)
            if abs(fMid) < 1e-10 || (upperBound - lower) < 1e-12 {
                return mid * 100
            }
            if fLower * fMid <= 0 {
                upperBound = mid
            } else {
                lower = mid
                fLower = fMid
            }
        }

        return (lower + upperBound) / 2 * 100
    }

    /// Calculate the number of periods needed to satisfy `FV = PV·(1+r)^n + PMT·s(r)`.
    /// Returns `.nan` when the target is unreachable with the given inputs.
    static func calculateNumberOfPeriods(
        presentValue: Double? = nil,
        futureValue: Double? = nil,
        payment: Double? = nil,
        interestRate: Double,
        paymentAtBeginning: Bool = false
    ) -> Double {
        let r = interestRate / 100.0
        guard r > -1 else { return .nan }

        let pv = presentValue ?? 0
        let fv = futureValue ?? 0
        let pmt = payment ?? 0

        if r == 0 {
            // FV = PV + PMT·n
            if pmt != 0 {
                let n = (fv - pv) / pmt
                return n >= 0 ? n : .nan
            }
            return fv == pv ? 0 : .nan
        }

        // Adjust payment for annuity-due timing
        let adjustedPmt = paymentAtBeginning ? pmt * (1 + r) : pmt
        // (1+r)^n = (FV + PMT/r) / (PV + PMT/r)
        let offset = adjustedPmt / r
        let numerator = fv + offset
        let denominator = pv + offset

        guard denominator != 0 else { return .nan }
        let ratio = numerator / denominator
        guard ratio > 0 else { return .nan }

        let n = Double.log(ratio) / Double.log(1 + r)
        return n >= 0 ? n : .nan
    }
    
    // MARK: - Loan Calculations
    
    /// Calculate loan payment
    static func calculateLoanPayment(
        principal: Double,
        interestRate: Double,
        numberOfPayments: Double
    ) -> Double {
        let r = interestRate / 100.0
        
        if r == 0 {
            return principal / numberOfPayments
        }
        
        return principal * (r * pow(1 + r, numberOfPayments)) / (pow(1 + r, numberOfPayments) - 1)
    }
    
    /// Calculate remaining loan balance
    static func calculateRemainingBalance(
        principal: Double,
        interestRate: Double,
        totalPayments: Double,
        paymentsMade: Double
    ) -> Double {
        let r = interestRate / 100.0
        let payment = calculateLoanPayment(principal: principal, interestRate: interestRate, numberOfPayments: totalPayments)

        if r == 0 {
            return principal - (payment * paymentsMade)
        }
        
        return principal * pow(1 + r, paymentsMade) - payment * (pow(1 + r, paymentsMade) - 1) / r
    }
    
    // MARK: - Investment Analysis
    
    /// Calculate Net Present Value
    static func calculateNPV(cashFlows: [Double], discountRate: Double) -> Double {
        let r = discountRate / 100.0
        var npv = 0.0
        
        for (index, cashFlow) in cashFlows.enumerated() {
            npv += cashFlow / pow(1 + r, Double(index))
        }
        
        return npv
    }
    
    /// Calculate Internal Rate of Return using bisection.
    /// Returns `.nan` when the cash flows do not admit an IRR in (−99%, 1000%)
    /// (e.g. all flows the same sign, or an empty series).
    static func calculateIRR(cashFlows: [Double]) -> Double {
        guard cashFlows.contains(where: { $0 > 0 }),
              cashFlows.contains(where: { $0 < 0 }) else {
            return .nan
        }

        var lowerRate = -0.99
        var upperRate = 10.0
        let tolerance = 1e-8
        let maxIterations = 200

        var npvLower = calculateNPV(cashFlows: cashFlows, discountRate: lowerRate * 100)
        let npvUpper = calculateNPV(cashFlows: cashFlows, discountRate: upperRate * 100)

        // Bisection requires a sign change across the bracket
        guard npvLower.isFinite, npvUpper.isFinite, npvLower * npvUpper <= 0 else {
            return .nan
        }

        for _ in 0..<maxIterations {
            let midRate = (lowerRate + upperRate) / 2
            let npvMid = calculateNPV(cashFlows: cashFlows, discountRate: midRate * 100)

            if abs(npvMid) < tolerance || abs(upperRate - lowerRate) < tolerance {
                return midRate * 100
            }

            if npvLower * npvMid <= 0 {
                upperRate = midRate
            } else {
                lowerRate = midRate
                npvLower = npvMid
            }
        }

        return (lowerRate + upperRate) / 2 * 100
    }

    /// Calculate Modified Internal Rate of Return.
    /// Negative flows are discounted to t=0 at `financeRate`; positive flows are
    /// compounded to the final period at `reinvestmentRate` (both in percent).
    /// Returns `.nan` when the series lacks both an outflow and an inflow.
    static func calculateMIRR(
        cashFlows: [Double],
        financeRate: Double,
        reinvestmentRate: Double
    ) -> Double {
        let n = cashFlows.count - 1
        guard n >= 1,
              cashFlows.contains(where: { $0 > 0 }),
              cashFlows.contains(where: { $0 < 0 }) else {
            return .nan
        }

        let fr = financeRate / 100.0
        let rr = reinvestmentRate / 100.0
        guard fr > -1, rr > -1 else { return .nan }

        var pvNegative = 0.0
        var fvPositive = 0.0

        for (index, flow) in cashFlows.enumerated() {
            if flow < 0 {
                pvNegative += flow / pow(1 + fr, Double(index))
            } else if flow > 0 {
                fvPositive += flow * pow(1 + rr, Double(n - index))
            }
        }

        guard pvNegative < 0, fvPositive > 0 else { return .nan }
        return (pow(fvPositive / -pvNegative, 1.0 / Double(n)) - 1) * 100
    }
    
    // MARK: - Bond Calculations
    
    /// Calculate bond price
    static func calculateBondPrice(
        faceValue: Double,
        couponRate: Double,
        marketRate: Double,
        yearsToMaturity: Double,
        paymentsPerYear: Double = 2
    ) -> Double {
        let periodicCoupon = (faceValue * couponRate / 100) / paymentsPerYear
        let periodicRate = marketRate / 100 / paymentsPerYear
        let totalPeriods = yearsToMaturity * paymentsPerYear
        guard totalPeriods > 0, periodicRate > -1 else { return .nan }

        // Present value of coupon payments (undiscounted sum when the rate is zero)
        let couponPV: Double
        if periodicRate == 0 {
            couponPV = periodicCoupon * totalPeriods
        } else {
            couponPV = periodicCoupon * (1 - pow(1 + periodicRate, -totalPeriods)) / periodicRate
        }

        // Present value of face value
        let facePV = faceValue / pow(1 + periodicRate, totalPeriods)

        return couponPV + facePV
    }
    
    /// Calculate bond yield to maturity via bisection on the price function.
    /// Handles negative yields down to −50% and premiums up to a 1000% yield.
    /// Returns `.nan` for invalid inputs or prices outside the attainable range.
    static func calculateBondYTM(
        faceValue: Double,
        currentPrice: Double,
        couponRate: Double,
        yearsToMaturity: Double,
        paymentsPerYear: Double = 2
    ) -> Double {
        guard faceValue > 0, currentPrice > 0, yearsToMaturity > 0, paymentsPerYear > 0 else {
            return .nan
        }

        func price(atYield yield: Double) -> Double {
            calculateBondPrice(
                faceValue: faceValue,
                couponRate: couponRate,
                marketRate: yield * 100,
                yearsToMaturity: yearsToMaturity,
                paymentsPerYear: paymentsPerYear
            )
        }

        // Price is monotonically decreasing in yield; establish a valid bracket.
        var lowerYield = -0.5
        var upperYield = 10.0
        guard price(atYield: lowerYield) >= currentPrice,
              price(atYield: upperYield) <= currentPrice else {
            return .nan
        }

        let tolerance = 1e-8
        for _ in 0..<200 {
            let midYield = (lowerYield + upperYield) / 2
            let calculatedPrice = price(atYield: midYield)

            if abs(calculatedPrice - currentPrice) < tolerance || abs(upperYield - lowerYield) < tolerance {
                return midYield * 100
            }

            if calculatedPrice > currentPrice {
                lowerYield = midYield
            } else {
                upperYield = midYield
            }
        }

        return (lowerYield + upperYield) / 2 * 100
    }
    
}
