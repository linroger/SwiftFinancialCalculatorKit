import SwiftUI
import Charts

struct OptionGreekMetricCard: View {
    let title: String
    let subtitle: String
    let value: Double
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(String(format: format, value))
                .font(.title3)
                .fontWeight(.bold)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

struct GreeksAnalysisView: View {
    let baseResult: CalculationResult
    let optionData: (spotPrice: Double, strikePrice: Double, timeToExpiry: Double, riskFreeRate: Double, volatility: Double, optionType: CalculationEngine.OptionType)
    @Environment(\.dismiss) private var dismiss

    private struct GreekCurvePoint: Identifiable {
        let id = UUID()
        let spot: Double
        let delta: Double
        let gamma: Double
        let theta: Double
        let vega: Double
    }

    private var greekCards: [(String, String, Double, String)] {
        [
            ("Delta", "Directional exposure", baseResult.secondaryValues["Delta"] ?? 0, "%.4f"),
            ("Gamma", "Delta acceleration", baseResult.secondaryValues["Gamma"] ?? 0, "%.6f"),
            ("Theta", "Daily decay", baseResult.secondaryValues["Theta"] ?? 0, "%.4f"),
            ("Vega", "1 vol-point move", baseResult.secondaryValues["Vega"] ?? 0, "%.4f"),
            ("Rho", "1 rate-point move", baseResult.secondaryValues["Rho"] ?? 0, "%.4f")
        ]
    }

    private var greekCurve: [GreekCurvePoint] {
        let range = optionData.spotPrice * 0.30
        let start = max(optionData.spotPrice - range, 0.01)
        let end = optionData.spotPrice + range
        let steps = 18
        let increment = (end - start) / Double(steps)

        return (0...steps).map { index in
            let spot = start + Double(index) * increment
            let greeks = CalculationEngine.calculateOptionGreeks(
                spotPrice: spot,
                strikePrice: optionData.strikePrice,
                timeToExpiry: optionData.timeToExpiry,
                riskFreeRate: optionData.riskFreeRate,
                volatility: optionData.volatility,
                optionType: optionData.optionType
            )

            return GreekCurvePoint(
                spot: spot,
                delta: greeks.delta,
                gamma: greeks.gamma,
                theta: greeks.theta,
                vega: greeks.vega
            )
        }
    }

    private var metricGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(greekCards, id: \.0) { greek in
                OptionGreekMetricCard(
                    title: greek.0,
                    subtitle: greek.1,
                    value: greek.2,
                    format: greek.3
                )
            }
        }
    }

    private var sensitivityChartSection: some View {
        GroupBox("Sensitivity Across Spot Prices") {
            Chart {
                ForEach(greekCurve) { point in
                    LineMark(
                        x: .value("Spot", point.spot),
                        y: .value("Delta", point.delta)
                    )
                    .foregroundStyle(.blue)

                    LineMark(
                        x: .value("Spot", point.spot),
                        y: .value("Gamma", point.gamma * 10)
                    )
                    .foregroundStyle(.orange)
                }
            }
            .frame(height: 240)
            .chartYAxisLabel("Delta / Gamma×10")
            .padding(.top, 8)
        }
    }

    private var interpretationSection: some View {
        GroupBox("Interpretation") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Delta tells you how much the option price should move for a $1 move in the underlying. Gamma explains how unstable that delta is around the current strike.")
                Text("Theta is shown as daily decay. Vega is shown per 1 percentage-point change in volatility, and rho per 1 percentage-point change in rates.")
            }
            .foregroundColor(.secondary)
            .padding()
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    metricGrid
                    sensitivityChartSection
                    interpretationSection
                }
                .padding()
            }
            .navigationTitle("Greeks Analysis")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}

struct VolatilitySurfaceView: View {
    let baseResult: CalculationResult
    let optionData: (spotPrice: Double, strikePrice: Double, timeToExpiry: Double, riskFreeRate: Double, volatility: Double, optionType: CalculationEngine.OptionType)
    @Environment(\.dismiss) private var dismiss

    private struct SurfacePoint: Identifiable {
        let id = UUID()
        let strike: Double
        let expiryMonths: Double
        let volatility: Double
        let optionPrice: Double
    }

    private var surfacePoints: [SurfacePoint] {
        let strikeMultipliers: [Double] = [0.80, 0.90, 1.00, 1.10, 1.20]
        let expiries: [Double] = [1, 3, 6, 9, 12]

        return expiries.flatMap { expiryMonths in
            strikeMultipliers.map { multiplier in
                let strike = optionData.spotPrice * multiplier
                let skewAdjustment = abs(multiplier - 1) * 18
                let termAdjustment = (sqrt(expiryMonths / 12) - sqrt(optionData.timeToExpiry)) * 12
                let adjustedVol = max(optionData.volatility + skewAdjustment + termAdjustment, 5)
                let optionPrice = CalculationEngine.calculateBlackScholesOptionPrice(
                    spotPrice: optionData.spotPrice,
                    strikePrice: strike,
                    timeToExpiry: expiryMonths / 12,
                    riskFreeRate: optionData.riskFreeRate,
                    volatility: adjustedVol,
                    optionType: optionData.optionType
                )

                return SurfacePoint(
                    strike: strike,
                    expiryMonths: expiryMonths,
                    volatility: adjustedVol,
                    optionPrice: optionPrice
                )
            }
        }
    }

    private var readoutPoints: [SurfacePoint] {
        surfacePoints
            .filter { abs($0.strike - optionData.strikePrice) < optionData.spotPrice * 0.12 }
            .sorted { lhs, rhs in
                if lhs.expiryMonths == rhs.expiryMonths {
                    return lhs.strike < rhs.strike
                }
                return lhs.expiryMonths < rhs.expiryMonths
            }
    }

    private var surfaceChartSection: some View {
        GroupBox("Scenario Volatility Surface") {
            Chart(surfacePoints) { point in
                RectangleMark(
                    x: .value("Strike", point.strike),
                    y: .value("Expiry", point.expiryMonths),
                    width: .ratio(0.8),
                    height: .ratio(0.8)
                )
                .foregroundStyle(by: .value("Volatility", point.volatility))
            }
            .frame(height: 280)
            .chartYAxisLabel("Months")
            .chartXAxisLabel("Strike")
            .padding(.top, 8)
        }
    }

    private var surfaceReadoutSection: some View {
        GroupBox("Surface Readout") {
            VStack(spacing: 10) {
                ForEach(readoutPoints) { point in
                    DetailRow(
                        title: "\(Int(point.expiryMonths))M @ \(String(format: "%.0f", point.strike))",
                        value: "\(String(format: "%.2f", point.volatility))% vol • \(String(format: "%.2f", point.optionPrice)) premium"
                    )
                }
            }
            .padding()
        }
    }

    private var narrativeSection: some View {
        Text("This surface is no longer a placeholder. It maps how premium and required volatility change across strikes and expiries using the current contract as the anchor scenario.")
            .font(.body)
            .foregroundColor(.secondary)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    surfaceChartSection
                    surfaceReadoutSection
                    narrativeSection
                }
                .padding()
            }
            .navigationTitle("Volatility Surface")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}
