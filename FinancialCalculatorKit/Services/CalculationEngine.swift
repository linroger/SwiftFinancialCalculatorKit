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
    
    // MARK: - Mathematical Expression Evaluation
    
    /// Evaluate mathematical expressions using the MathParser
    static func evaluateExpression(_ expressionString: String, with variables: [String: Double] = [:]) -> Double? {
        // For now, use the MathParser as the primary expression evaluator
        return evaluateMathExpression(expressionString)
    }
    
    /// Parse and evaluate complex mathematical expressions using MathParser
    static func evaluateMathExpression(_ expressionString: String) -> Double? {
        let parser = MathParser()
        let evaluator = parser.parse(expressionString)
        if let result = evaluator {
            return result.eval()
        }
        return nil
    }
    
    // MARK: - Advanced Numerical Methods
    
    /// Calculate accurate compound interest using high-precision arithmetic
    static func calculateCompoundInterestPrecise(
        principal: Double,
        rate: Double,
        compoundingFrequency: Double,
        years: Double
    ) -> Double {
        let r = Double.pi * rate / (100.0 * compoundingFrequency)
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
        let zScore = confidenceLevel == 0.95 ? 1.645 : (confidenceLevel == 0.99 ? 2.326 : 1.96)
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
        
        var weightedCashFlows = 0.0
        var totalPresentValue = 0.0
        
        // Calculate weighted present value of coupon payments
        for period in 1...Int(totalPeriods) {
            let pv = periodicCoupon / pow(1 + periodicRate, Double(period))
            weightedCashFlows += pv * Double(period)
            totalPresentValue += pv
        }
        
        // Add present value of face value
        let facePV = faceValue / pow(1 + periodicRate, totalPeriods)
        weightedCashFlows += facePV * totalPeriods
        totalPresentValue += facePV
        
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
        
        var convexitySum = 0.0
        let bondPrice = calculateBondPrice(
            faceValue: faceValue,
            couponRate: couponRate,
            marketRate: marketRate,
            yearsToMaturity: yearsToMaturity,
            paymentsPerYear: paymentsPerYear
        )
        
        // Calculate convexity for coupon payments
        for period in 1...Int(totalPeriods) {
            let cashFlow = periodicCoupon
            let pv = cashFlow / pow(1 + periodicRate, Double(period))
            convexitySum += pv * Double(period) * (Double(period) + 1)
        }
        
        // Add convexity for face value
        let facePV = faceValue / pow(1 + periodicRate, totalPeriods)
        convexitySum += facePV * totalPeriods * (totalPeriods + 1)
        
        return convexitySum / (bondPrice * pow(1 + periodicRate, 2) * pow(paymentsPerYear, 2))
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
        let d1 = (Double.log(spotPrice / strikePrice) + (riskFreeRate / 100 + pow(volatility / 100, 2) / 2) * timeToExpiry) / 
                 (volatility / 100 * Double.sqrt(timeToExpiry))
        let d2 = d1 - volatility / 100 * Double.sqrt(timeToExpiry)
        
        let nd1 = cumulativeNormalDistribution(d1)
        let nd2 = cumulativeNormalDistribution(d2)
        let nNegD1 = cumulativeNormalDistribution(-d1)
        let nNegD2 = cumulativeNormalDistribution(-d2)
        
        let discountFactor = Double.exp(-riskFreeRate / 100 * timeToExpiry)
        
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
        let d1 = (Double.log(spotPrice / strikePrice) + (riskFreeRate / 100 + pow(volatility / 100, 2) / 2) * timeToExpiry) / 
                 (volatility / 100 * Double.sqrt(timeToExpiry))
        
        switch optionType {
        case .call:
            return cumulativeNormalDistribution(d1)
        case .put:
            return cumulativeNormalDistribution(d1) - 1
        }
    }
    
    // MARK: - Utility Functions
    
    /// Cumulative normal distribution approximation
    private static func cumulativeNormalDistribution(_ x: Double) -> Double {
        // Abramowitz and Stegun approximation
        let a1 =  0.254829592
        let a2 = -0.284496736
        let a3 =  1.421413741
        let a4 = -1.453152027
        let a5 =  1.061405429
        let p  =  0.3275911
        
        let sign = x < 0 ? -1.0 : 1.0
        let absX = abs(x)
        
        let t = 1.0 / (1.0 + p * absX)
        let y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * Double.exp(-absX * absX)
        
        return 0.5 * (1.0 + sign * y)
    }
    
    enum OptionType {
        case call
        case put
    }
    
    // MARK: - Time Value of Money Calculations
    
    /// Calculate Present Value
    /// PV = FV / (1 + r)^n  OR  PV = PMT * [(1 - (1 + r)^-n) / r]
    static func calculatePresentValue(
        futureValue: Double? = nil,
        payment: Double? = nil,
        interestRate: Double,
        numberOfPeriods: Double,
        paymentAtBeginning: Bool = false
    ) -> Double {
        let r = interestRate / 100.0
        
        var pv = 0.0
        
        // Present value of lump sum
        if let fv = futureValue {
            pv += fv / pow(1 + r, numberOfPeriods)
        }
        
        // Present value of annuity
        if let pmt = payment, r != 0 {
            let annuityPV = pmt * (1 - pow(1 + r, -numberOfPeriods)) / r
            pv += paymentAtBeginning ? annuityPV * (1 + r) : annuityPV
        } else if let pmt = payment, r == 0 {
            pv += pmt * numberOfPeriods
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
    
    /// Calculate Payment
    /// PMT = (PV * r) / (1 - (1 + r)^-n)  for PV
    /// PMT = (FV * r) / ((1 + r)^n - 1)   for FV
    static func calculatePayment(
        presentValue: Double? = nil,
        futureValue: Double? = nil,
        interestRate: Double,
        numberOfPeriods: Double,
        paymentAtBeginning: Bool = false
    ) -> Double {
        let r = interestRate / 100.0
        
        if r == 0 {
            if let pv = presentValue {
                return -pv / numberOfPeriods
            } else if let fv = futureValue {
                return fv / numberOfPeriods
            }
            return 0
        }
        
        var pmt = 0.0
        
        if let pv = presentValue {
            pmt += (pv * r) / (1 - pow(1 + r, -numberOfPeriods))
        }
        
        if let fv = futureValue {
            pmt += (fv * r) / (pow(1 + r, numberOfPeriods) - 1)
        }
        
        if paymentAtBeginning {
            pmt = pmt / (1 + r)
        }
        
        return -pmt
    }
    
    /// Calculate Interest Rate using Newton-Raphson method
    static func calculateInterestRate(
        presentValue: Double? = nil,
        futureValue: Double? = nil,
        payment: Double? = nil,
        numberOfPeriods: Double,
        paymentAtBeginning: Bool = false
    ) -> Double {
        
        // Initial guess
        var rate = 0.1
        let maxIterations = 100
        let tolerance = 1e-8
        
        for _ in 0..<maxIterations {
            let f = calculateNetPresentValue(
                presentValue: presentValue,
                futureValue: futureValue,
                payment: payment,
                interestRate: rate * 100,
                numberOfPeriods: numberOfPeriods,
                paymentAtBeginning: paymentAtBeginning
            )
            
            let fPrime = calculateNPVDerivative(
                presentValue: presentValue,
                futureValue: futureValue,
                payment: payment,
                interestRate: rate,
                numberOfPeriods: numberOfPeriods,
                paymentAtBeginning: paymentAtBeginning
            )
            
            if abs(f) < tolerance {
                break
            }
            
            if fPrime == 0 {
                break
            }
            
            rate = rate - f / fPrime
            
            // Ensure rate stays positive
            if rate < 0 {
                rate = 0.001
            }
        }
        
        return rate * 100
    }
    
    /// Calculate number of periods
    static func calculateNumberOfPeriods(
        presentValue: Double? = nil,
        futureValue: Double? = nil,
        payment: Double? = nil,
        interestRate: Double,
        paymentAtBeginning: Bool = false
    ) -> Double {
        let r = interestRate / 100.0
        
        if let pv = presentValue, let fv = futureValue, payment == nil {
            // Simple compound interest: n = ln(FV/PV) / ln(1 + r)
            return log(fv / pv) / log(1 + r)
        }
        
        if let pv = presentValue, let pmt = payment, r != 0 {
            // Annuity: n = -ln(1 - (PV * r) / PMT) / ln(1 + r)
            let adjustedPmt = paymentAtBeginning ? pmt * (1 + r) : pmt
            let ratio = (pv * r) / adjustedPmt
            if ratio < 1 {
                return -log(1 - ratio) / log(1 + r)
            }
        }
        
        if let fv = futureValue, let pmt = payment, r != 0 {
            // Future value annuity: n = ln(1 + (FV * r) / PMT) / ln(1 + r)
            let adjustedPmt = paymentAtBeginning ? pmt * (1 + r) : pmt
            let ratio = (fv * r) / adjustedPmt
            return log(1 + ratio) / log(1 + r)
        }
        
        return 0
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
        let payment = calculateLoanPayment(principal: principal, interestRate: interestRate * 100, numberOfPayments: totalPayments)
        
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
    
    /// Calculate Internal Rate of Return using bisection method
    static func calculateIRR(cashFlows: [Double]) -> Double {
        var lowerRate = -0.99
        var upperRate = 10.0
        let tolerance = 1e-8
        let maxIterations = 100
        
        for _ in 0..<maxIterations {
            let midRate = (lowerRate + upperRate) / 2
            let npv = calculateNPV(cashFlows: cashFlows, discountRate: midRate * 100)
            
            if abs(npv) < tolerance {
                return midRate * 100
            }
            
            if npv > 0 {
                lowerRate = midRate
            } else {
                upperRate = midRate
            }
            
            if abs(upperRate - lowerRate) < tolerance {
                break
            }
        }
        
        return (lowerRate + upperRate) / 2 * 100
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
        
        // Present value of coupon payments
        let couponPV = periodicCoupon * (1 - pow(1 + periodicRate, -totalPeriods)) / periodicRate
        
        // Present value of face value
        let facePV = faceValue / pow(1 + periodicRate, totalPeriods)
        
        return couponPV + facePV
    }
    
    /// Calculate bond yield to maturity
    static func calculateBondYTM(
        faceValue: Double,
        currentPrice: Double,
        couponRate: Double,
        yearsToMaturity: Double,
        paymentsPerYear: Double = 2
    ) -> Double {
        
        var lowerYield = 0.001
        var upperYield = 1.0
        let tolerance = 1e-8
        let maxIterations = 100
        
        for _ in 0..<maxIterations {
            let midYield = (lowerYield + upperYield) / 2
            let calculatedPrice = calculateBondPrice(
                faceValue: faceValue,
                couponRate: couponRate,
                marketRate: midYield * 100,
                yearsToMaturity: yearsToMaturity,
                paymentsPerYear: paymentsPerYear
            )
            
            if abs(calculatedPrice - currentPrice) < tolerance {
                return midYield * 100
            }
            
            if calculatedPrice > currentPrice {
                lowerYield = midYield
            } else {
                upperYield = midYield
            }
            
            if abs(upperYield - lowerYield) < tolerance {
                break
            }
        }
        
        return (lowerYield + upperYield) / 2 * 100
    }
    
    // MARK: - Helper Functions
    
    private static func calculateNetPresentValue(
        presentValue: Double?,
        futureValue: Double?,
        payment: Double?,
        interestRate: Double,
        numberOfPeriods: Double,
        paymentAtBeginning: Bool
    ) -> Double {
        var npv = 0.0
        
        if let pv = presentValue {
            npv += pv
        }
        
        if let fv = futureValue {
            npv -= fv / pow(1 + interestRate / 100, numberOfPeriods)
        }
        
        if let pmt = payment {
            let r = interestRate / 100
            if r != 0 {
                let annuityPV = pmt * (1 - pow(1 + r, -numberOfPeriods)) / r
                npv -= paymentAtBeginning ? annuityPV * (1 + r) : annuityPV
            } else {
                npv -= pmt * numberOfPeriods
            }
        }
        
        return npv
    }
    
    private static func calculateNPVDerivative(
        presentValue: Double?,
        futureValue: Double?,
        payment: Double?,
        interestRate: Double,
        numberOfPeriods: Double,
        paymentAtBeginning: Bool
    ) -> Double {
        // Numerical derivative
        let h = 1e-8
        let f1 = calculateNetPresentValue(
            presentValue: presentValue,
            futureValue: futureValue,
            payment: payment,
            interestRate: (interestRate + h) * 100,
            numberOfPeriods: numberOfPeriods,
            paymentAtBeginning: paymentAtBeginning
        )
        let f2 = calculateNetPresentValue(
            presentValue: presentValue,
            futureValue: futureValue,
            payment: payment,
            interestRate: (interestRate - h) * 100,
            numberOfPeriods: numberOfPeriods,
            paymentAtBeginning: paymentAtBeginning
        )
        
        return (f1 - f2) / (2 * h)
    }
}