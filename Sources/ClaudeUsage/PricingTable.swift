import Foundation

/// $ per million tokens. Matched by model family substring; verify against the
/// current Anthropic pricing page when new models ship.
struct ModelPrice {
    let input: Double
    let output: Double
    var cacheRead: Double { input * 0.1 }
    var cacheWrite5m: Double { input * 1.25 }
    var cacheWrite1h: Double { input * 2.0 }
}

enum PricingTable {
    static func price(for model: String) -> ModelPrice? {
        let m = model.lowercased()
        if m.contains("opus") { return ModelPrice(input: 5, output: 25) }
        if m.contains("sonnet") { return ModelPrice(input: 3, output: 15) }
        if m.contains("haiku") { return ModelPrice(input: 1, output: 5) }
        return nil
    }

    static func cost(_ t: TokenCounts, model: String) -> Double? {
        guard let p = price(for: model) else { return nil }
        let perToken = 1.0 / 1_000_000
        return (Double(t.input) * p.input
            + Double(t.output) * p.output
            + Double(t.cacheRead) * p.cacheRead
            + Double(t.cacheWrite5m) * p.cacheWrite5m
            + Double(t.cacheWrite1h) * p.cacheWrite1h) * perToken
    }
}
