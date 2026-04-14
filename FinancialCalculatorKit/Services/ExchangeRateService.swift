//
//  ExchangeRateService.swift
//  FinancialCalculatorKit
//
//  Created by Codex on 4/14/26.
//

import Foundation

struct ExchangeRateSnapshot: Sendable {
    let base: Currency
    let rates: [Currency: Double]
    let fetchedAt: Date
    let nextUpdateAt: Date?
    let providerName: String
}

struct LiveExchangeQuote: Sendable {
    let base: Currency
    let quote: Currency
    let rate: Double
    let fetchedAt: Date
    let nextUpdateAt: Date?
    let providerName: String
}

enum ExchangeRateServiceError: LocalizedError {
    case invalidBaseCurrency
    case invalidQuoteCurrency
    case invalidResponse
    case rateUnavailable(Currency, Currency)

    var errorDescription: String? {
        switch self {
        case .invalidBaseCurrency:
            return "The exchange-rate provider did not return a valid base currency."
        case .invalidQuoteCurrency:
            return "The exchange-rate provider returned an unsupported currency code."
        case .invalidResponse:
            return "The exchange-rate provider returned malformed data."
        case .rateUnavailable(let base, let quote):
            return "A live rate for \(base.rawValue)/\(quote.rawValue) is not available right now."
        }
    }
}

actor ExchangeRateService {
    static let shared = ExchangeRateService()

    private let session: URLSession
    private var latestCache: [Currency: ExchangeRateSnapshot] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchQuote(base: Currency, quote: Currency) async throws -> LiveExchangeQuote {
        if base == quote {
            let now = Date()
            return LiveExchangeQuote(
                base: base,
                quote: quote,
                rate: 1,
                fetchedAt: now,
                nextUpdateAt: now,
                providerName: "ExchangeRate-API"
            )
        }

        let snapshot = try await fetchLatest(base: base)
        guard let rate = snapshot.rates[quote] else {
            throw ExchangeRateServiceError.rateUnavailable(base, quote)
        }

        return LiveExchangeQuote(
            base: base,
            quote: quote,
            rate: rate,
            fetchedAt: snapshot.fetchedAt,
            nextUpdateAt: snapshot.nextUpdateAt,
            providerName: snapshot.providerName
        )
    }

    func fetchLatest(base: Currency, forceRefresh: Bool = false) async throws -> ExchangeRateSnapshot {
        if !forceRefresh,
           let cached = latestCache[base],
           !isSnapshotExpired(cached) {
            return cached
        }

        let url = URL(string: "https://open.er-api.com/v6/latest/\(base.rawValue)")!
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(LatestRatesResponse.self, from: data)

        guard let resolvedBase = Currency(rawValue: response.baseCode) else {
            throw ExchangeRateServiceError.invalidBaseCurrency
        }

        var resolvedRates: [Currency: Double] = [:]
        for (code, value) in response.rates {
            guard let currency = Currency(rawValue: code) else { continue }
            resolvedRates[currency] = value
        }

        let fetchedAt = Date(timeIntervalSince1970: TimeInterval(response.lastUpdateUnix))
        let nextUpdate = Date(timeIntervalSince1970: TimeInterval(response.nextUpdateUnix))
        let snapshot = ExchangeRateSnapshot(
            base: resolvedBase,
            rates: resolvedRates,
            fetchedAt: fetchedAt,
            nextUpdateAt: nextUpdate,
            providerName: "ExchangeRate-API"
        )

        latestCache[base] = snapshot
        return snapshot
    }

    private func isSnapshotExpired(_ snapshot: ExchangeRateSnapshot) -> Bool {
        guard let nextUpdateAt = snapshot.nextUpdateAt else {
            return Date().timeIntervalSince(snapshot.fetchedAt) > 60 * 60
        }
        return Date() >= nextUpdateAt
    }
}

private struct LatestRatesResponse: Decodable {
    let result: String
    let provider: String?
    let baseCode: String
    let lastUpdateUnix: Int
    let nextUpdateUnix: Int
    let rates: [String: Double]

    enum CodingKeys: String, CodingKey {
        case result
        case provider
        case baseCode = "base_code"
        case lastUpdateUnix = "time_last_update_unix"
        case nextUpdateUnix = "time_next_update_unix"
        case rates
    }
}
