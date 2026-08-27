//
//  RetirementMonteCarlo.swift
//  FinancialCalculatorKit
//
//  Stochastic retirement analysis. A single deterministic projection hides the
//  biggest real risk in a retirement plan — the order in which returns arrive.
//  This simulates many market paths to estimate how often the plan actually
//  funds the desired income for life.
//

import Foundation

/// Seedable generator so a given plan always produces the same simulation.
/// Users comparing two plans should not see the numbers drift on their own,
/// and the math needs to be reproducible in tests.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // SplitMix64 degenerates at zero
        self.state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Draws standard-normal samples via Box-Muller, caching the spare value each
/// transform produces.
struct NormalSampler {
    private var generator: SeededGenerator
    private var spare: Double?

    init(seed: UInt64) {
        generator = SeededGenerator(seed: seed)
    }

    mutating func nextNormal() -> Double {
        if let cached = spare {
            spare = nil
            return cached
        }

        var u1 = 0.0
        var u2 = 0.0
        repeat {
            u1 = Double.random(in: 0..<1, using: &generator)
            u2 = Double.random(in: 0..<1, using: &generator)
        } while u1 <= .leastNormalMagnitude

        let magnitude = (-2 * Foundation.log(u1)).squareRoot()
        spare = magnitude * Foundation.cos(2 * .pi * u2)
        return magnitude * Foundation.sin(2 * .pi * u2)
    }
}

/// One year of the simulated balance distribution.
struct RetirementPercentilePoint: Identifiable {
    let id = UUID()
    let age: Double
    let p10: Double
    let p50: Double
    let p90: Double
}

struct RetirementSimulationResult {
    /// Share of paths that funded the full desired income through the plan horizon (0...1)
    let successProbability: Double
    let trials: Int
    let medianEndingBalance: Double
    let p10EndingBalance: Double
    let p90EndingBalance: Double
    /// Median age at which money ran out, across the paths that failed
    let medianDepletionAge: Double?
    /// Balance distribution per year, for the fan chart
    let percentileBands: [RetirementPercentilePoint]
    /// Monthly income (today's dollars) the plan sustains at ~90% success
    let sustainableIncomeAt90: Double
}

enum RetirementMonteCarlo {
    /// Number of paths a run simulates.
    enum TrialCount: Int, CaseIterable, Identifiable {
        case quick = 500
        case standard = 2_000
        case thorough = 10_000

        var id: Int { rawValue }

        var displayName: String {
            switch self {
            case .quick: return "Quick (500 paths)"
            case .standard: return "Standard (2,000 paths)"
            case .thorough: return "Thorough (10,000 paths)"
            }
        }
    }

    /// Run the full analysis: success probability, percentile bands, and the
    /// income level the plan sustains at roughly 90% confidence.
    ///
    /// Returns are drawn monthly from a normal distribution using the phase's
    /// expected return and the single entered volatility; inflation grows the
    /// withdrawal each month. A path succeeds when it funds every withdrawal
    /// through the plan horizon.
    static func analyze(
        currentAge: Double,
        retirementAge: Double,
        lifeExpectancy: Double,
        currentSavings: Double,
        monthlyContribution: Double,
        preRetirementReturn: Double,
        inRetirementReturn: Double,
        returnVolatility: Double,
        inflationRate: Double,
        desiredMonthlyIncome: Double,
        trials: TrialCount = .standard,
        seed: UInt64 = 0x5EED_5EED
    ) -> RetirementSimulationResult {
        let paths = runPaths(
            currentAge: currentAge,
            retirementAge: retirementAge,
            lifeExpectancy: lifeExpectancy,
            currentSavings: currentSavings,
            monthlyContribution: monthlyContribution,
            preRetirementReturn: preRetirementReturn,
            inRetirementReturn: inRetirementReturn,
            returnVolatility: returnVolatility,
            inflationRate: inflationRate,
            desiredMonthlyIncome: desiredMonthlyIncome,
            trials: trials.rawValue,
            seed: seed,
            collectBands: true
        )

        // Search for the income level that succeeds ~90% of the time. A cheaper
        // path count keeps this responsive; the headline number uses the full run.
        let searchTrials = min(trials.rawValue, 500)
        var low = 0.0
        var high = max(desiredMonthlyIncome * 3, 1_000)
        for _ in 0..<12 {
            let mid = (low + high) / 2
            let outcome = runPaths(
                currentAge: currentAge,
                retirementAge: retirementAge,
                lifeExpectancy: lifeExpectancy,
                currentSavings: currentSavings,
                monthlyContribution: monthlyContribution,
                preRetirementReturn: preRetirementReturn,
                inRetirementReturn: inRetirementReturn,
                returnVolatility: returnVolatility,
                inflationRate: inflationRate,
                desiredMonthlyIncome: mid,
                trials: searchTrials,
                seed: seed,
                collectBands: false
            )
            if outcome.successProbability >= 0.90 {
                low = mid
            } else {
                high = mid
            }
        }

        return RetirementSimulationResult(
            successProbability: paths.successProbability,
            trials: trials.rawValue,
            medianEndingBalance: paths.medianEnding,
            p10EndingBalance: paths.p10Ending,
            p90EndingBalance: paths.p90Ending,
            medianDepletionAge: paths.medianDepletionAge,
            percentileBands: paths.bands,
            sustainableIncomeAt90: low
        )
    }

    // MARK: - Path simulation

    private struct PathOutcome {
        let successProbability: Double
        let medianEnding: Double
        let p10Ending: Double
        let p90Ending: Double
        let medianDepletionAge: Double?
        let bands: [RetirementPercentilePoint]
    }

    private static func runPaths(
        currentAge: Double,
        retirementAge: Double,
        lifeExpectancy: Double,
        currentSavings: Double,
        monthlyContribution: Double,
        preRetirementReturn: Double,
        inRetirementReturn: Double,
        returnVolatility: Double,
        inflationRate: Double,
        desiredMonthlyIncome: Double,
        trials: Int,
        seed: UInt64,
        collectBands: Bool
    ) -> PathOutcome {
        let accumulationMonths = max(Int(((retirementAge - currentAge) * 12).rounded()), 0)
        let drawdownMonths = max(Int(((lifeExpectancy - retirementAge) * 12).rounded()), 1)
        let totalMonths = accumulationMonths + drawdownMonths
        let years = max(Int((lifeExpectancy - currentAge).rounded()), 1)

        let accumulationDrift = preRetirementReturn / 100 / 12
        let drawdownDrift = inRetirementReturn / 100 / 12
        let monthlySigma = returnVolatility / 100 / 12.0.squareRoot()
        let monthlyInflation = inflationRate / 100 / 12

        var sampler = NormalSampler(seed: seed)
        var endingBalances: [Double] = []
        endingBalances.reserveCapacity(trials)
        var depletionAges: [Double] = []
        var successes = 0

        // yearlyBalances[year][trial] — only gathered when the caller needs bands
        var yearlyBalances: [[Double]] = collectBands
            ? Array(repeating: [], count: years + 1)
            : []
        if collectBands {
            for index in yearlyBalances.indices {
                yearlyBalances[index].reserveCapacity(trials)
            }
        }

        for _ in 0..<trials {
            var balance = currentSavings
            var withdrawal = desiredMonthlyIncome
            var depletedAtMonth: Int? = nil

            if collectBands {
                yearlyBalances[0].append(balance)
            }

            for month in 1...max(totalMonths, 1) {
                let isAccumulating = month <= accumulationMonths
                let drift = isAccumulating ? accumulationDrift : drawdownDrift
                let shock = sampler.nextNormal() * monthlySigma

                if depletedAtMonth == nil {
                    balance *= (1 + drift + shock)
                    if isAccumulating {
                        balance += monthlyContribution
                    } else {
                        balance -= withdrawal
                    }
                    if balance <= 0 {
                        balance = 0
                        depletedAtMonth = month
                    }
                }

                // The desired income keeps pace with inflation from day one
                withdrawal *= (1 + monthlyInflation)

                if collectBands, month % 12 == 0 {
                    let yearIndex = month / 12
                    if yearIndex < yearlyBalances.count {
                        yearlyBalances[yearIndex].append(balance)
                    }
                }
            }

            endingBalances.append(balance)
            if let depletedAtMonth {
                depletionAges.append(currentAge + Double(depletedAtMonth) / 12)
            } else {
                successes += 1
            }
        }

        let sortedEnding = endingBalances.sorted()
        let sortedDepletion = depletionAges.sorted()

        var bands: [RetirementPercentilePoint] = []
        if collectBands {
            for (yearIndex, balances) in yearlyBalances.enumerated() where !balances.isEmpty {
                let sorted = balances.sorted()
                bands.append(
                    RetirementPercentilePoint(
                        age: currentAge + Double(yearIndex),
                        p10: percentile(sorted, 0.10),
                        p50: percentile(sorted, 0.50),
                        p90: percentile(sorted, 0.90)
                    )
                )
            }
        }

        return PathOutcome(
            successProbability: trials > 0 ? Double(successes) / Double(trials) : 0,
            medianEnding: percentile(sortedEnding, 0.50),
            p10Ending: percentile(sortedEnding, 0.10),
            p90Ending: percentile(sortedEnding, 0.90),
            medianDepletionAge: sortedDepletion.isEmpty ? nil : percentile(sortedDepletion, 0.50),
            bands: bands
        )
    }

    /// Linear-interpolated percentile of an already-sorted array.
    static func percentile(_ sorted: [Double], _ p: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        guard sorted.count > 1 else { return sorted[0] }

        let rank = min(max(p, 0), 1) * Double(sorted.count - 1)
        let lower = Int(rank.rounded(.down))
        let upper = min(lower + 1, sorted.count - 1)
        let weight = rank - Double(lower)
        return sorted[lower] * (1 - weight) + sorted[upper] * weight
    }
}
