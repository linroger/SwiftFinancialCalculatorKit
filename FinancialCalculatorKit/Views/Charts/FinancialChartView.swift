//
//  FinancialChartView.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import SwiftUI
import Charts

/// Reusable financial chart component using Swift Charts
struct FinancialChartView: View {
    let data: [ChartDataPoint]
    let chartType: ChartType
    let title: String
    let currency: Currency
    let showLegend: Bool
    let height: CGFloat
    
    @State private var selectedDataPoint: ChartDataPoint?
    @State private var hoveredX: Double?
    
    init(
        data: [ChartDataPoint],
        chartType: ChartType = .line,
        title: String = "",
        currency: Currency = .usd,
        showLegend: Bool = true,
        height: CGFloat = 300
    ) {
        self.data = data
        self.chartType = chartType
        self.title = title
        self.currency = currency
        self.showLegend = showLegend
        self.height = height
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleSection
            chartContentView
            selectedPointInfo
        }
        .padding()
        .background(chartBackground)
    }
    
    @ViewBuilder
    private var titleSection: some View {
        if !title.isEmpty {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
    
    @ViewBuilder
    private var chartContentView: some View {
        Chart(data) { dataPoint in
            chartMarks(for: dataPoint)
        }
        .frame(height: height)
        .chartLegend(showLegend ? .visible : .hidden)
        .chartXAxis { xAxisMarks }
        .chartYAxis { yAxisMarks }
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                .border(Color(NSColor.separatorColor), width: 1)
        }
        .chartOverlay { proxy in
            chartOverlay(proxy)
        }
    }
    
    @ChartContentBuilder
    private func chartMarks(for dataPoint: ChartDataPoint) -> some ChartContent {
        switch chartType {
        case .line:
            LineMark(
                x: .value("Period", dataPoint.x),
                y: .value("Value", dataPoint.y)
            )
            .foregroundStyle(dataPoint.y >= 0 ? Color.green : Color.red)
            .interpolationMethod(.monotone)

            // Highlight exactly the hovered point, not everything within a fixed distance
            if selectedDataPoint?.id == dataPoint.id {
                PointMark(
                    x: .value("Period", dataPoint.x),
                    y: .value("Value", dataPoint.y)
                )
                .foregroundStyle(dataPoint.y >= 0 ? Color.green : Color.red)
                .symbolSize(100)

                RuleMark(x: .value("Period", dataPoint.x))
                    .foregroundStyle(Color.gray.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }

        case .bar:
            BarMark(
                x: .value("Period", dataPoint.x),
                y: .value("Value", dataPoint.y)
            )
            .foregroundStyle(dataPoint.y >= 0 ? Color.green.gradient : Color.red.gradient)
            .cornerRadius(4)

        case .area:
            AreaMark(
                x: .value("Period", dataPoint.x),
                y: .value("Value", dataPoint.y)
            )
            .foregroundStyle(areaGradient(for: dataPoint.y))
            .interpolationMethod(.monotone)

            LineMark(
                x: .value("Period", dataPoint.x),
                y: .value("Value", dataPoint.y)
            )
            .foregroundStyle(dataPoint.y >= 0 ? Color.green : Color.red)
            .interpolationMethod(.monotone)
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
    }
    
    @AxisContentBuilder
    private var xAxisMarks: some AxisContent {
        AxisMarks { value in
            AxisGridLine()
                .foregroundStyle(Color.gray.opacity(0.2))
            AxisTick()
            AxisValueLabel {
                if let doubleValue = value.as(Double.self) {
                    Text(formatXAxisLabel(doubleValue))
                        .font(.caption)
                }
            }
        }
    }
    
    @AxisContentBuilder
    private var yAxisMarks: some AxisContent {
        AxisMarks { value in
            AxisGridLine()
                .foregroundStyle(Color.gray.opacity(0.2))
            AxisTick()
            AxisValueLabel {
                if let doubleValue = value.as(Double.self) {
                    Text(formatYAxisLabel(doubleValue))
                        .font(.caption)
                }
            }
        }
    }
    
    private func chartOverlay(_ proxy: ChartProxy) -> some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        guard let plotFrame = proxy.plotFrame else { return }
                        let origin = geometry[plotFrame].origin
                        let relativeX = location.x - origin.x
                        if let x = proxy.value(atX: relativeX, as: Double.self) {
                            hoveredX = x
                            selectedDataPoint = data.min(by: { abs($0.x - x) < abs($1.x - x) })
                        }
                    case .ended:
                        hoveredX = nil
                        selectedDataPoint = nil
                    }
                }
        }
    }
    
    @ViewBuilder
    private var selectedPointInfo: some View {
        if let selectedPoint = selectedDataPoint {
            HStack {
                if let label = selectedPoint.label {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(formatXAxisLabel(selectedPoint.x)): \(currency.formatValue(selectedPoint.y))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(selectedPointBackground)
        }
    }
    
    private var chartBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(NSColor.windowBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var selectedPointBackground: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(NSColor.controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
    }
    
    private func areaGradient(for value: Double) -> LinearGradient {
        .linearGradient(
            colors: value >= 0 ? 
                [Color.green.opacity(0.8), Color.green.opacity(0.1)] : 
                [Color.red.opacity(0.8), Color.red.opacity(0.1)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private func formatXAxisLabel(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
    
    private func formatYAxisLabel(_ value: Double) -> String {
        return Formatters.formatAbbreviated(value)
    }
}

/// Cash flow timeline chart
struct CashFlowTimelineChart: View {
    let cashFlows: [ChartDataPoint]
    let currency: Currency
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cash Flow Timeline")
                .font(.headline)
                .fontWeight(.semibold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(cashFlows) { flow in
                        VStack(spacing: 8) {
                            // Arrow indicator
                            Image(systemName: flow.y >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .font(.title2)
                                .foregroundColor(flow.y >= 0 ? .green : .red)
                            
                            // Amount
                            Text(currency.formatValue(abs(flow.y)))
                                .font(.system(.callout, design: .monospaced))
                                .fontWeight(.medium)
                                .foregroundColor(flow.y >= 0 ? .green : .red)
                            
                            // Period label
                            if let label = flow.label {
                                Text(label)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Period \(Int(flow.x.isFinite ? flow.x : 0))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(flow.y >= 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(flow.y >= 0 ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
        )
    }
}

/// Pie chart for portfolio or payment breakdown
struct BreakdownPieChart: View {
    let segments: [(label: String, value: Double, color: Color)]
    let title: String
    let currency: Currency
    
    @State private var selectedSegment: String?
    
    var total: Double {
        segments.reduce(0) { $0 + $1.value }
    }

    /// Percentage of the total for one segment, safe against a zero/NaN total.
    private func percentageText(for value: Double) -> String {
        guard total != 0, (value / total).isFinite else { return "—" }
        return "\(Int((value / total) * 100))%"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 24) {
                // Pie chart
                Chart(segments, id: \.label) { segment in
                    SectorMark(
                        angle: .value("Value", segment.value),
                        innerRadius: .ratio(0.6),
                        angularInset: 2
                    )
                    .foregroundStyle(segment.color)
                    .opacity(selectedSegment == nil || selectedSegment == segment.label ? 1.0 : 0.5)
                }
                .frame(width: 200, height: 200)
                .chartBackground { _ in
                    if let selected = selectedSegment,
                       let segment = segments.first(where: { $0.label == selected }) {
                        VStack {
                            Text(segment.label)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(currency.formatValue(segment.value))
                                .font(.headline)
                                .fontWeight(.bold)
                            Text(percentageText(for: segment.value))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        VStack {
                            Text("Total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(currency.formatValue(total))
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                    }
                }
                
                // Legend
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(segments, id: \.label) { segment in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedSegment == segment.label {
                                    selectedSegment = nil
                                } else {
                                    selectedSegment = segment.label
                                }
                            }
                        }) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(segment.color)
                                    .frame(width: 12, height: 12)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(segment.label)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    HStack(spacing: 4) {
                                        Text(currency.formatValue(segment.value))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        
                                        Text("(\(percentageText(for: segment.value)))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .opacity(selectedSegment == nil || selectedSegment == segment.label ? 1.0 : 0.5)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        FinancialChartView(
            data: [
                ChartDataPoint(x: 0, y: -100000, label: "Initial Investment"),
                ChartDataPoint(x: 1, y: 20000, label: "Year 1"),
                ChartDataPoint(x: 2, y: 25000, label: "Year 2"),
                ChartDataPoint(x: 3, y: 30000, label: "Year 3"),
                ChartDataPoint(x: 4, y: 35000, label: "Year 4"),
                ChartDataPoint(x: 5, y: 150000, label: "Year 5 + Sale")
            ],
            chartType: .bar,
            title: "Investment Cash Flows",
            currency: .usd
        )
        
        CashFlowTimelineChart(
            cashFlows: [
                ChartDataPoint(x: 0, y: -50000, label: "Initial"),
                ChartDataPoint(x: 1, y: 15000, label: "Q1"),
                ChartDataPoint(x: 2, y: 18000, label: "Q2"),
                ChartDataPoint(x: 3, y: 22000, label: "Q3"),
                ChartDataPoint(x: 4, y: 25000, label: "Q4")
            ],
            currency: .usd
        )
        
        BreakdownPieChart(
            segments: [
                ("Principal", 100000, .blue),
                ("Interest", 45000, .orange),
                ("Fees", 5000, .red)
            ],
            title: "Total Payment Breakdown",
            currency: .usd
        )
    }
    .padding()
    .frame(width: 600)
}
