//
//  DashboardView.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/9/25.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(MainViewModel.self) private var mainViewModel

    // Recent calculations queries
    @Query(sort: \TimeValueCalculation.lastModified, order: .reverse) private var recentTVM: [TimeValueCalculation]
    @Query(sort: \LoanCalculation.lastModified, order: .reverse) private var recentLoans: [LoanCalculation]
    @Query(sort: \InvestmentCalculation.lastModified, order: .reverse) private var recentInvestments: [InvestmentCalculation]
    @Query(sort: \OptionsCalculation.lastModified, order: .reverse) private var recentOptions: [OptionsCalculation]
    @Query(sort: \MathExpressionCalculation.lastModified, order: .reverse) private var recentMath: [MathExpressionCalculation]
    
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Welcome Header with time-based greeting
                welcomeHeader
                
                // Statistics Overview
                statisticsSection
                
                // Quick Actions Grid
                quickActionsSection

                // Market Overview (Mock Data)
                MarketOverviewView()
                    .padding(.horizontal)
                
                // All Calculators Section
                allCalculatorsSection

                // Recent Activity
                recentActivitySection
            }
            .padding(.vertical, 24)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    // MARK: - Welcome Header
    
    private var welcomeHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(greeting)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(currentTime.formatted(date: .complete, time: .omitted))
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Text("What would you like to calculate today?")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // App Logo / Icon
            VStack {
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.linearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                
                Text("FinancialKit")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: currentTime)
        switch hour {
        case 5..<12:
            return "Good Morning"
        case 12..<17:
            return "Good Afternoon"
        case 17..<21:
            return "Good Evening"
        default:
            return "Good Night"
        }
    }
    
    // MARK: - Statistics Section
    
    private var statisticsSection: some View {
        HStack(spacing: 16) {
            StatisticCard(
                title: "Total Calculations",
                value: "\(totalCalculations)",
                icon: "number.circle.fill",
                color: .blue
            )
            
            StatisticCard(
                title: "This Week",
                value: "\(calculationsThisWeek)",
                icon: "calendar.circle.fill",
                color: .green
            )
            
            StatisticCard(
                title: "Favorites",
                value: "\(favoriteCount)",
                icon: "heart.circle.fill",
                color: .red
            )
            
            StatisticCard(
                title: "Categories Used",
                value: "\(categoriesUsed)",
                icon: "folder.circle.fill",
                color: .orange
            )
        }
        .padding(.horizontal, 24)
    }
    
    private var totalCalculations: Int {
        recentTVM.count + recentLoans.count + recentInvestments.count + recentOptions.count + recentMath.count
    }
    
    private var calculationsThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        var count = 0
        count += recentTVM.filter { $0.lastModified > weekAgo }.count
        count += recentLoans.filter { $0.lastModified > weekAgo }.count
        count += recentInvestments.filter { $0.lastModified > weekAgo }.count
        count += recentOptions.filter { $0.lastModified > weekAgo }.count
        count += recentMath.filter { $0.lastModified > weekAgo }.count
        return count
    }
    
    private var favoriteCount: Int {
        var count = 0
        count += recentTVM.filter { $0.isFavorite }.count
        count += recentLoans.filter { $0.isFavorite }.count
        count += recentInvestments.filter { $0.isFavorite }.count
        count += recentOptions.filter { $0.isFavorite }.count
        count += recentMath.filter { $0.isFavorite }.count
        return count
    }
    
    private var categoriesUsed: Int {
        var categories = Set<String>()
        if !recentTVM.isEmpty { categories.insert("TVM") }
        if !recentLoans.isEmpty { categories.insert("Loans") }
        if !recentInvestments.isEmpty { categories.insert("Investment") }
        if !recentOptions.isEmpty { categories.insert("Options") }
        if !recentMath.isEmpty { categories.insert("Math") }
        return categories.count
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Quick Actions")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { mainViewModel.createNewCalculation(type: mainViewModel.selectedCalculationType) }) {
                    Label("New", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    QuickActionCard(type: .timeValue, color: .blue)
                    QuickActionCard(type: .loan, color: .green)
                    QuickActionCard(type: .investment, color: .purple)
                    QuickActionCard(type: .options, color: .orange)
                    QuickActionCard(type: .bond, color: .cyan)
                    QuickActionCard(type: .depreciation, color: .brown)
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    // MARK: - All Calculators Section
    
    private var allCalculatorsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Calculators")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 24)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(CalculationType.allCases) { type in
                    CalculatorGridItem(type: type)
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Recent Activity Section
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !recentActivity.isEmpty {
                    Text("\(recentActivity.count) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)

            if recentActivity.isEmpty {
                EmptyRecentActivityView()
                    .padding(.horizontal, 24)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(recentActivity) { activity in
                        Button(action: {
                            mainViewModel.openCalculator(activity.calculationType)
                        }) {
                            RecentActivityRow(
                                icon: activity.icon,
                                title: activity.title,
                                subtitle: activity.subtitle,
                                date: activity.date,
                                result: activity.result
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // Aggregate and sort recent activity
    private var recentActivity: [ActivityItem] {
        var items: [ActivityItem] = []

        for item in recentTVM.prefix(5) {
            items.append(ActivityItem(
                id: item.id,
                title: item.name,
                subtitle: "TVM Calculator",
                date: item.lastModified,
                result: item.result.formattedPrimaryValue,
                icon: "clock.arrow.circlepath",
                calculationType: .timeValue,
                calculationId: item.id
            ))
        }

        for item in recentLoans.prefix(5) {
            items.append(ActivityItem(
                id: item.id,
                title: item.name,
                subtitle: item.loanType.displayName,
                date: item.lastModified,
                result: item.result.formattedPrimaryValue,
                icon: "creditcard",
                calculationType: .loan,
                calculationId: item.id
            ))
        }

        for item in recentInvestments.prefix(5) {
            items.append(ActivityItem(
                id: item.id,
                title: item.name,
                subtitle: "Investment Analysis",
                date: item.lastModified,
                result: item.result.formattedPrimaryValue,
                icon: "chart.bar.fill",
                calculationType: .investment,
                calculationId: item.id
            ))
        }

        for item in recentOptions.prefix(5) {
            items.append(ActivityItem(
                id: item.id,
                title: item.name,
                subtitle: "Options Calculator",
                date: item.lastModified,
                result: item.result.formattedPrimaryValue,
                icon: "function",
                calculationType: .options,
                calculationId: item.id
            ))
        }

        for item in recentMath.prefix(5) {
            items.append(ActivityItem(
                id: item.id,
                title: item.name,
                subtitle: "Math Expression",
                date: item.lastModified,
                result: item.result.formattedPrimaryValue,
                icon: "x.squareroot",
                calculationType: .mathExpression,
                calculationId: item.id
            ))
        }

        return items.sorted(by: { $0.date > $1.date }).prefix(10).map { $0 }
    }
}

struct ActivityItem: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let date: Date
    let result: String
    let icon: String
    let calculationType: CalculationType
    let calculationId: UUID
}

// MARK: - Supporting Views

struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

struct QuickActionCard: View {
    let type: CalculationType
    let color: Color
    @Environment(MainViewModel.self) private var mainViewModel
    @State private var isHovered = false

    var body: some View {
        Button(action: {
            mainViewModel.openCalculator(type)
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: type.systemImage)
                        .font(.title)
                        .foregroundColor(color)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .opacity(isHovered ? 1 : 0)
                }

                Spacer()
                
                Text(type.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(type.category.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 150, height: 110)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovered ? color.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovered ? color : color.opacity(0.3), lineWidth: isHovered ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct CalculatorGridItem: View {
    let type: CalculationType
    @Environment(MainViewModel.self) private var mainViewModel
    @State private var isHovered = false
    
    private var typeColor: Color {
        switch type.category {
        case .basics: return .blue
        case .investment: return .purple
        case .tools: return .orange
        }
    }
    
    var body: some View {
        Button(action: {
            mainViewModel.openCalculator(type)
        }) {
            VStack(spacing: 8) {
                Image(systemName: type.systemImage)
                    .font(.title2)
                    .foregroundColor(typeColor)
                
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? typeColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isHovered ? typeColor.opacity(0.5) : Color(NSColor.separatorColor).opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct EmptyRecentActivityView: View {
    @Environment(MainViewModel.self) private var mainViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No Recent Calculations")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Start by selecting a calculator from the sidebar or quick actions above.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: { mainViewModel.createNewCalculation(type: nil) }) {
                Label("Create Your First Calculation", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
        )
    }
}

struct MarketOverviewView: View {
    @State private var isExpanded = true
    
    var body: some View {
        GroupBox {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.blue)
                    Text("Market Overview")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("Live Data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.15))
                        )
                    
                    Button(action: { withAnimation { isExpanded.toggle() }}) {
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(isExpanded ? 0 : -90))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                if isExpanded {
                    HStack(spacing: 20) {
                        MarketMetric(name: "S&P 500", value: "5,234.18", change: "+1.26%", isPositive: true, icon: "chart.line.uptrend.xyaxis")
                        Divider()
                        MarketMetric(name: "NASDAQ", value: "16,428.82", change: "+1.59%", isPositive: true, icon: "chart.bar.fill")
                        Divider()
                        MarketMetric(name: "10Y Treasury", value: "4.42%", change: "-0.08%", isPositive: true, icon: "building.columns")
                        Divider()
                        MarketMetric(name: "EUR/USD", value: "1.0856", change: "+0.24%", isPositive: true, icon: "dollarsign.circle")
                        Divider()
                        MarketMetric(name: "Gold", value: "$2,342.50", change: "+0.87%", isPositive: true, icon: "bitcoinsign.circle")
                    }
                    .padding(.top, 8)
                }
            }
            .padding()
        }
        .groupBoxStyle(FinancialGroupBoxStyle())
    }
}

struct MarketMetric: View {
    let name: String
    let value: String
    let change: String
    let isPositive: Bool
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(.headline, design: .rounded))
                .fontWeight(.semibold)
            
            HStack(spacing: 2) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2)
                Text(change)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isPositive ? .green : .red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RecentActivityRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let date: Date
    let result: String
    
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.accentColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(date.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Result
            VStack(alignment: .trailing, spacing: 4) {
                Text(result)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .opacity(isHovered ? 1 : 0)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color.accentColor.opacity(0.05) : Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? Color.accentColor.opacity(0.3) : Color(NSColor.separatorColor).opacity(0.5), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
