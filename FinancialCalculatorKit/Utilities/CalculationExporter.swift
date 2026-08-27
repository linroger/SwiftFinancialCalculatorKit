//
//  CalculationExporter.swift
//  FinancialCalculatorKit
//
//  Shared CSV export for calculator results.
//

import Foundation
import AppKit
import UniformTypeIdentifiers

/// Exports calculation results to CSV via a save panel.
@MainActor
enum CalculationExporter {
    /// Present a save panel and write the given rows as CSV.
    /// - Parameters:
    ///   - suggestedName: default file name without extension
    ///   - headers: column headers, defining column order
    ///   - rows: row values keyed by header
    /// - Returns: `true` when a file was written, `false` when the user cancelled.
    /// - Throws: file-system errors from writing the file.
    @discardableResult
    static func exportCSV(
        suggestedName: String,
        headers: [String],
        rows: [[String: String]]
    ) throws -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedName.isEmpty ? "Calculation" : suggestedName

        guard panel.runModal() == .OK, let url = panel.url else {
            return false
        }

        var lines: [String] = [headers.map(escape).joined(separator: ",")]
        for row in rows {
            let line = headers.map { escape(row[$0] ?? "") }.joined(separator: ",")
            lines.append(line)
        }

        let csv = lines.joined(separator: "\n") + "\n"
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return true
    }

    /// Export a calculation summary (primary value plus secondary values),
    /// optionally followed by a detail table.
    @discardableResult
    static func exportResult(
        suggestedName: String,
        primaryLabel: String,
        result: CalculationResult
    ) throws -> Bool {
        var rows: [[String: String]] = [
            ["Item": primaryLabel, "Value": result.formattedPrimaryValue]
        ]
        for key in result.secondaryValues.keys.sorted() {
            if let value = result.secondaryValues[key] {
                rows.append(["Item": key, "Value": String(format: "%.6g", value)])
            }
        }

        if let tableData = result.tableData, !tableData.isEmpty {
            // Merge the schedule below the summary using its own column set
            let tableHeaders = orderedHeaders(for: tableData)
            rows.append(["Item": "", "Value": ""])
            rows.append(["Item": tableHeaders.joined(separator: " | "), "Value": ""])
            for tableRow in tableData {
                let joined = tableHeaders.map { tableRow.values[$0] ?? "" }.joined(separator: " | ")
                rows.append(["Item": joined, "Value": ""])
            }
        }

        return try exportCSV(
            suggestedName: suggestedName,
            headers: ["Item", "Value"],
            rows: rows
        )
    }

    /// Export only a detail table (e.g. an amortization or depreciation schedule).
    @discardableResult
    static func exportTable(
        suggestedName: String,
        tableData: [TableRow]
    ) throws -> Bool {
        guard !tableData.isEmpty else { return false }
        let headers = orderedHeaders(for: tableData)
        return try exportCSV(
            suggestedName: suggestedName,
            headers: headers,
            rows: tableData.map(\.values)
        )
    }

    private static func orderedHeaders(for tableData: [TableRow]) -> [String] {
        // Preserve a stable, readable order: union of keys, sorted with common
        // schedule columns first when present.
        let preferred = ["Payment #", "Year", "Period", "Payment", "Principal", "Interest", "Balance",
                         "Depreciation", "Cumulative Depreciation", "Book Value"]
        var keys = Set<String>()
        for row in tableData {
            keys.formUnion(row.values.keys)
        }
        let front = preferred.filter { keys.contains($0) }
        let rest = keys.subtracting(front).sorted()
        return front + rest
    }

    private static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }
}
