//
//  UnitConverterView.swift
//  FinancialCalculatorKit
//
//  Created by Roger Lin on 6/8/25.
//

import SwiftUI

/// Comprehensive unit converter for international financial calculations
struct UnitConverterView: View {
    @Environment(MainViewModel.self) private var mainViewModel
    
    @State private var inputValue: Double = 1.0
    @State private var outputValue: Double = 0.0
    @State private var selectedCategory: UnitCategory = .length
    @State private var fromUnit: String = ""
    @State private var toUnit: String = ""
    @State private var conversionHistory: [ConversionRecord] = []
    @State private var showingHistory: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                
                HStack(alignment: .top, spacing: 24) {
                    converterSection
                    resultSection
                }
                
                if !conversionHistory.isEmpty {
                    historySection
                }
            }
            .padding(24)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            setupInitialUnits()
        }
        .onChange(of: selectedCategory) { _, _ in
            setupInitialUnits()
        }
        .sheet(isPresented: $showingHistory) {
            ConversionHistoryView(history: $conversionHistory)
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unit Converter")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Convert between units for international business and engineering calculations")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text("Global Standards")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private var converterSection: some View {
        VStack(spacing: 20) {
            // Unit category selection
            GroupBox("Unit Category") {
                VStack(spacing: 16) {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(UnitCategory.allCases) { category in
                            HStack {
                                Image(systemName: category.systemImage)
                                Text(category.displayName)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text(selectedCategory.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
            }
            .groupBoxStyle(FinancialGroupBoxStyle())
            
            // Input value and units
            GroupBox("Convert From") {
                VStack(spacing: 16) {
                    // Input value
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Value")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        TextField("Enter value", value: $inputValue, format: .number.precision(.fractionLength(6)))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.title3, design: .monospaced))
                            .onChange(of: inputValue) { _, _ in
                                performConversion()
                            }
                    }
                    
                    // From unit selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("From Unit")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Picker("From Unit", selection: $fromUnit) {
                            ForEach(selectedCategory.units, id: \.symbol) { unit in
                                HStack {
                                    Text(unit.symbol)
                                        .font(.system(.body, design: .monospaced))
                                        .frame(width: 40, alignment: .leading)
                                    Text(unit.name)
                                }
                                .tag(unit.symbol)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: fromUnit) { _, _ in
                            performConversion()
                        }
                    }
                }
                .padding(16)
            }
            .groupBoxStyle(FinancialGroupBoxStyle())
            
            // Swap button
            HStack {
                Spacer()
                Button(action: swapUnits) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.title2)
                }
                .buttonStyle(.bordered)
                .help("Swap units")
                Spacer()
            }
            
            // To unit selection
            GroupBox("Convert To") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("To Unit")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Picker("To Unit", selection: $toUnit) {
                        ForEach(selectedCategory.units, id: \.symbol) { unit in
                            HStack {
                                Text(unit.symbol)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(width: 40, alignment: .leading)
                                Text(unit.name)
                            }
                            .tag(unit.symbol)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: toUnit) { _, _ in
                        performConversion()
                    }
                }
                .padding(16)
            }
            .groupBoxStyle(FinancialGroupBoxStyle())
            
            // Quick conversion buttons
            GroupBox("Quick Conversions") {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(selectedCategory.commonConversions, id: \.self) { conversion in
                        Button(action: {
                            fromUnit = conversion.from
                            toUnit = conversion.to
                            performConversion()
                        }) {
                            Text("\(conversion.from) → \(conversion.to)")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(16)
            }
            .groupBoxStyle(FinancialGroupBoxStyle())
        }
        .frame(maxWidth: 500)
    }
    
    @ViewBuilder
    private var resultSection: some View {
        VStack(spacing: 20) {
            // Conversion result
            GroupBox {
                VStack(spacing: 16) {
                    Text("Converted Value")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: getNumberFormat(), outputValue))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(getToUnitName())
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("\(String(format: getNumberFormat(), inputValue)) \(getFromUnitName()) = \(String(format: getNumberFormat(), outputValue)) \(getToUnitName())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
            .groupBoxStyle(FinancialGroupBoxStyle())
            
            // Conversion formula and info
            if !fromUnit.isEmpty && !toUnit.isEmpty {
                GroupBox("Conversion Details") {
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(
                            title: "From",
                            value: "\(String(format: getNumberFormat(), inputValue)) \(getFromUnitName())"
                        )
                        
                        DetailRow(
                            title: "To",
                            value: "\(String(format: getNumberFormat(), outputValue)) \(getToUnitName())"
                        )
                        
                        Divider()
                        
                        let conversionFactor = getConversionFactor()
                        DetailRow(
                            title: "Conversion Factor",
                            value: "1 \(fromUnit) = \(String(format: "%.10g", conversionFactor)) \(toUnit)"
                        )
                        
                        if let precision = getPrecisionInfo() {
                            DetailRow(
                                title: "Precision",
                                value: precision
                            )
                        }
                    }
                    .padding(16)
                }
                .groupBoxStyle(FinancialGroupBoxStyle())
            }
            
            // Unit information
            GroupBox("Unit Information") {
                VStack(alignment: .leading, spacing: 12) {
                    if let fromUnitInfo = getUnitInfo(fromUnit) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("From: \(fromUnitInfo.name)")
                                .font(.headline)
                            if let description = fromUnitInfo.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if let toUnitInfo = getUnitInfo(toUnit) {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("To: \(toUnitInfo.name)")
                                .font(.headline)
                            if let description = toUnitInfo.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .groupBoxStyle(FinancialGroupBoxStyle())
            
            // Action buttons
            VStack(spacing: 12) {
                Button("Save Conversion") {
                    saveConversion()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .disabled(outputValue == 0)
                
                Button("View History") {
                    showingHistory = true
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .disabled(conversionHistory.isEmpty)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var historySection: some View {
        GroupBox("Recent Conversions") {
            VStack(spacing: 8) {
                ForEach(conversionHistory.suffix(5)) { record in
                    HStack {
                        Text("\(String(format: "%.3g", record.inputValue)) \(record.fromUnit)")
                            .font(.system(.body, design: .monospaced))
                        
                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                        
                        Text("\(String(format: "%.3g", record.outputValue)) \(record.toUnit)")
                            .font(.system(.body, design: .monospaced))
                        
                        Spacer()
                        
                        Text(record.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(16)
        }
        .groupBoxStyle(FinancialGroupBoxStyle())
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialUnits() {
        let units = selectedCategory.units
        if !units.isEmpty {
            fromUnit = units[0].symbol
            toUnit = units.count > 1 ? units[1].symbol : units[0].symbol
            performConversion()
        }
    }
    
    private func performConversion() {
        guard !fromUnit.isEmpty && !toUnit.isEmpty else {
            outputValue = 0
            return
        }
        
        let factor = getConversionFactor()
        outputValue = inputValue * factor
    }
    
    private func swapUnits() {
        let temp = fromUnit
        fromUnit = toUnit
        toUnit = temp
        performConversion()
    }
    
    private func saveConversion() {
        let record = ConversionRecord(
            inputValue: inputValue,
            outputValue: outputValue,
            fromUnit: fromUnit,
            toUnit: toUnit,
            category: selectedCategory,
            timestamp: Date()
        )
        conversionHistory.append(record)
    }
    
    private func getConversionFactor() -> Double {
        guard let fromUnitData = selectedCategory.units.first(where: { $0.symbol == fromUnit }),
              let toUnitData = selectedCategory.units.first(where: { $0.symbol == toUnit }) else {
            return 1.0
        }
        
        // Convert from source unit to base unit, then to target unit
        return fromUnitData.toBaseUnitFactor / toUnitData.toBaseUnitFactor
    }
    
    private func getFromUnitName() -> String {
        return selectedCategory.units.first(where: { $0.symbol == fromUnit })?.name ?? fromUnit
    }
    
    private func getToUnitName() -> String {
        return selectedCategory.units.first(where: { $0.symbol == toUnit })?.name ?? toUnit
    }
    
    private func getUnitInfo(_ symbol: String) -> UnitInfo? {
        return selectedCategory.units.first(where: { $0.symbol == symbol })
    }
    
    private func getNumberFormat() -> String {
        if outputValue == 0 { return "%.0f" }
        
        let magnitude = abs(outputValue)
        if magnitude >= 1000000 {
            return "%.3e"
        } else if magnitude >= 1000 {
            return "%.1f"
        } else if magnitude >= 1 {
            return "%.3f"
        } else if magnitude >= 0.001 {
            return "%.6f"
        } else {
            return "%.3e"
        }
    }
    
    private func getPrecisionInfo() -> String? {
        let magnitude = abs(outputValue)
        if magnitude >= 1000000 || magnitude < 0.001 {
            return "Scientific notation for very large/small values"
        } else if magnitude < 1 {
            return "High precision for decimal values"
        }
        return nil
    }
}

// MARK: - Supporting Views

struct ConversionHistoryView: View {
    @Binding var history: [ConversionRecord]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if history.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No conversion history")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(history.reversed()) { record in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("\(String(format: "%.6g", record.inputValue)) \(record.fromUnit)")
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.medium)
                                    
                                    Image(systemName: "arrow.right")
                                        .foregroundColor(.secondary)
                                    
                                    Text("\(String(format: "%.6g", record.outputValue)) \(record.toUnit)")
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                }
                                
                                HStack {
                                    Text(record.category.displayName)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.blue.opacity(0.2))
                                        )
                                    
                                    Spacer()
                                    
                                    Text(record.timestamp.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: deleteRecords)
                    }
                }
            }
            .navigationTitle("Conversion History")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if !history.isEmpty {
                        Button("Clear All") {
                            history.removeAll()
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
    
    private func deleteRecords(offsets: IndexSet) {
        // Convert reversed indices back to original indices
        let indicesToDelete = offsets.map { history.count - 1 - $0 }
        
        for index in indicesToDelete.sorted(by: >) {
            if index >= 0 && index < history.count {
                history.remove(at: index)
            }
        }
    }
}

// MARK: - Supporting Types

struct ConversionRecord: Identifiable {
    let id = UUID()
    let inputValue: Double
    let outputValue: Double
    let fromUnit: String
    let toUnit: String
    let category: UnitCategory
    let timestamp: Date
}

struct UnitInfo {
    let symbol: String
    let name: String
    let toBaseUnitFactor: Double
    let description: String?
    
    init(symbol: String, name: String, toBaseUnitFactor: Double, description: String? = nil) {
        self.symbol = symbol
        self.name = name
        self.toBaseUnitFactor = toBaseUnitFactor
        self.description = description
    }
}

struct QuickConversion: Hashable {
    let from: String
    let to: String
}

enum UnitCategory: String, CaseIterable, Identifiable {
    case length = "length"
    case area = "area"
    case volume = "volume"
    case mass = "mass"
    case temperature = "temperature"
    case energy = "energy"
    case pressure = "pressure"
    case speed = "speed"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .length: return "Length"
        case .area: return "Area"
        case .volume: return "Volume"
        case .mass: return "Mass/Weight"
        case .temperature: return "Temperature"
        case .energy: return "Energy"
        case .pressure: return "Pressure"
        case .speed: return "Speed"
        }
    }
    
    var description: String {
        switch self {
        case .length: return "Distance and dimensional measurements"
        case .area: return "Surface area calculations"
        case .volume: return "Capacity and volume measurements"
        case .mass: return "Weight and mass conversions"
        case .temperature: return "Temperature scale conversions"
        case .energy: return "Energy and work measurements"
        case .pressure: return "Pressure and stress measurements"
        case .speed: return "Velocity and speed conversions"
        }
    }
    
    var systemImage: String {
        switch self {
        case .length: return "ruler"
        case .area: return "square"
        case .volume: return "cube"
        case .mass: return "scalemass"
        case .temperature: return "thermometer"
        case .energy: return "bolt"
        case .pressure: return "gauge"
        case .speed: return "speedometer"
        }
    }
    
    var units: [UnitInfo] {
        switch self {
        case .length:
            return [
                UnitInfo(symbol: "mm", name: "Millimeter", toBaseUnitFactor: 0.001),
                UnitInfo(symbol: "cm", name: "Centimeter", toBaseUnitFactor: 0.01),
                UnitInfo(symbol: "m", name: "Meter", toBaseUnitFactor: 1.0),
                UnitInfo(symbol: "km", name: "Kilometer", toBaseUnitFactor: 1000.0),
                UnitInfo(symbol: "in", name: "Inch", toBaseUnitFactor: 0.0254),
                UnitInfo(symbol: "ft", name: "Foot", toBaseUnitFactor: 0.3048),
                UnitInfo(symbol: "yd", name: "Yard", toBaseUnitFactor: 0.9144),
                UnitInfo(symbol: "mi", name: "Mile", toBaseUnitFactor: 1609.344)
            ]
        case .area:
            return [
                UnitInfo(symbol: "mm²", name: "Square Millimeter", toBaseUnitFactor: 0.000001),
                UnitInfo(symbol: "cm²", name: "Square Centimeter", toBaseUnitFactor: 0.0001),
                UnitInfo(symbol: "m²", name: "Square Meter", toBaseUnitFactor: 1.0),
                UnitInfo(symbol: "km²", name: "Square Kilometer", toBaseUnitFactor: 1000000.0),
                UnitInfo(symbol: "in²", name: "Square Inch", toBaseUnitFactor: 0.00064516),
                UnitInfo(symbol: "ft²", name: "Square Foot", toBaseUnitFactor: 0.092903),
                UnitInfo(symbol: "ac", name: "Acre", toBaseUnitFactor: 4046.86),
                UnitInfo(symbol: "ha", name: "Hectare", toBaseUnitFactor: 10000.0)
            ]
        case .volume:
            return [
                UnitInfo(symbol: "ml", name: "Milliliter", toBaseUnitFactor: 0.001),
                UnitInfo(symbol: "l", name: "Liter", toBaseUnitFactor: 1.0),
                UnitInfo(symbol: "m³", name: "Cubic Meter", toBaseUnitFactor: 1000.0),
                UnitInfo(symbol: "fl oz", name: "Fluid Ounce (US)", toBaseUnitFactor: 0.0295735),
                UnitInfo(symbol: "cup", name: "Cup (US)", toBaseUnitFactor: 0.236588),
                UnitInfo(symbol: "pt", name: "Pint (US)", toBaseUnitFactor: 0.473176),
                UnitInfo(symbol: "qt", name: "Quart (US)", toBaseUnitFactor: 0.946353),
                UnitInfo(symbol: "gal", name: "Gallon (US)", toBaseUnitFactor: 3.78541)
            ]
        case .mass:
            return [
                UnitInfo(symbol: "mg", name: "Milligram", toBaseUnitFactor: 0.001),
                UnitInfo(symbol: "g", name: "Gram", toBaseUnitFactor: 1.0),
                UnitInfo(symbol: "kg", name: "Kilogram", toBaseUnitFactor: 1000.0),
                UnitInfo(symbol: "t", name: "Metric Ton", toBaseUnitFactor: 1000000.0),
                UnitInfo(symbol: "oz", name: "Ounce", toBaseUnitFactor: 28.3495),
                UnitInfo(symbol: "lb", name: "Pound", toBaseUnitFactor: 453.592),
                UnitInfo(symbol: "st", name: "Stone", toBaseUnitFactor: 6350.29),
                UnitInfo(symbol: "ton", name: "Ton (US)", toBaseUnitFactor: 907185.0)
            ]
        case .temperature:
            return [
                UnitInfo(symbol: "°C", name: "Celsius", toBaseUnitFactor: 1.0),
                UnitInfo(symbol: "°F", name: "Fahrenheit", toBaseUnitFactor: 1.0),
                UnitInfo(symbol: "K", name: "Kelvin", toBaseUnitFactor: 1.0),
                UnitInfo(symbol: "°R", name: "Rankine", toBaseUnitFactor: 1.0)
            ]
        case .energy:
            return [
                UnitInfo(symbol: "J", name: "Joule", toBaseUnitFactor: 1.0),
                UnitInfo(symbol: "kJ", name: "Kilojoule", toBaseUnitFactor: 1000.0),
                UnitInfo(symbol: "cal", name: "Calorie", toBaseUnitFactor: 4.184),
                UnitInfo(symbol: "kcal", name: "Kilocalorie", toBaseUnitFactor: 4184.0),
                UnitInfo(symbol: "Wh", name: "Watt-hour", toBaseUnitFactor: 3600.0),
                UnitInfo(symbol: "kWh", name: "Kilowatt-hour", toBaseUnitFactor: 3600000.0),
                UnitInfo(symbol: "BTU", name: "British Thermal Unit", toBaseUnitFactor: 1055.06),
                UnitInfo(symbol: "ft·lb", name: "Foot-pound", toBaseUnitFactor: 1.35582)
            ]
        case .pressure:
            return [
                UnitInfo(symbol: "Pa", name: "Pascal", toBaseUnitFactor: 1.0),
                UnitInfo(symbol: "kPa", name: "Kilopascal", toBaseUnitFactor: 1000.0),
                UnitInfo(symbol: "MPa", name: "Megapascal", toBaseUnitFactor: 1000000.0),
                UnitInfo(symbol: "bar", name: "Bar", toBaseUnitFactor: 100000.0),
                UnitInfo(symbol: "atm", name: "Atmosphere", toBaseUnitFactor: 101325.0),
                UnitInfo(symbol: "psi", name: "Pounds per Square Inch", toBaseUnitFactor: 6894.76),
                UnitInfo(symbol: "mmHg", name: "Millimeter of Mercury", toBaseUnitFactor: 133.322),
                UnitInfo(symbol: "inHg", name: "Inch of Mercury", toBaseUnitFactor: 3386.39)
            ]
        case .speed:
            return [
                UnitInfo(symbol: "m/s", name: "Meters per Second", toBaseUnitFactor: 1.0),
                UnitInfo(symbol: "km/h", name: "Kilometers per Hour", toBaseUnitFactor: 0.277778),
                UnitInfo(symbol: "mph", name: "Miles per Hour", toBaseUnitFactor: 0.44704),
                UnitInfo(symbol: "ft/s", name: "Feet per Second", toBaseUnitFactor: 0.3048),
                UnitInfo(symbol: "kn", name: "Knot", toBaseUnitFactor: 0.514444),
                UnitInfo(symbol: "c", name: "Speed of Light", toBaseUnitFactor: 299792458.0)
            ]
        }
    }
    
    var commonConversions: [QuickConversion] {
        switch self {
        case .length:
            return [
                QuickConversion(from: "ft", to: "m"),
                QuickConversion(from: "in", to: "cm"),
                QuickConversion(from: "mi", to: "km"),
                QuickConversion(from: "yd", to: "m")
            ]
        case .area:
            return [
                QuickConversion(from: "ft²", to: "m²"),
                QuickConversion(from: "ac", to: "ha"),
                QuickConversion(from: "in²", to: "cm²"),
                QuickConversion(from: "km²", to: "mi²")
            ]
        case .volume:
            return [
                QuickConversion(from: "gal", to: "l"),
                QuickConversion(from: "fl oz", to: "ml"),
                QuickConversion(from: "cup", to: "ml"),
                QuickConversion(from: "qt", to: "l")
            ]
        case .mass:
            return [
                QuickConversion(from: "lb", to: "kg"),
                QuickConversion(from: "oz", to: "g"),
                QuickConversion(from: "ton", to: "t"),
                QuickConversion(from: "st", to: "kg")
            ]
        case .temperature:
            return [
                QuickConversion(from: "°C", to: "°F"),
                QuickConversion(from: "°F", to: "°C"),
                QuickConversion(from: "K", to: "°C"),
                QuickConversion(from: "°C", to: "K")
            ]
        case .energy:
            return [
                QuickConversion(from: "kWh", to: "J"),
                QuickConversion(from: "cal", to: "J"),
                QuickConversion(from: "BTU", to: "J"),
                QuickConversion(from: "kcal", to: "kJ")
            ]
        case .pressure:
            return [
                QuickConversion(from: "psi", to: "kPa"),
                QuickConversion(from: "bar", to: "psi"),
                QuickConversion(from: "atm", to: "Pa"),
                QuickConversion(from: "mmHg", to: "kPa")
            ]
        case .speed:
            return [
                QuickConversion(from: "mph", to: "km/h"),
                QuickConversion(from: "km/h", to: "m/s"),
                QuickConversion(from: "kn", to: "mph"),
                QuickConversion(from: "ft/s", to: "m/s")
            ]
        }
    }
}

#Preview {
    UnitConverterView()
        .environment(MainViewModel())
        .frame(width: 1000, height: 700)
}