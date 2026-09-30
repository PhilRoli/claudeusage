import Foundation

enum Format {
    static func percent(_ v: Double) -> String { "\(Int(v.rounded()))%" }

    static func title(_ limits: Limits?) -> String {
        guard let limits else { return "–" }
        return [limits.fiveHour, limits.sevenDay]
            .map { $0.map { percent($0.utilization) } ?? "–" }
            .joined(separator: " · ")
    }

    static func countdown(to date: Date, now: Date) -> String {
        let secs = date.timeIntervalSince(now)
        if secs <= 0 { return "now" }
        let minutes = Int(secs / 60)
        if minutes < 1 { return "<1m" }
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h \(minutes % 60)m" }
        return "\(hours / 24)d \(hours % 24)h"
    }

    static func tokens(_ n: Int) -> String {
        if n < 1000 { return "\(n)" }
        if n < 1_000_000 { return String(format: "%.1fK", Double(n) / 1000) }
        return String(format: "%.1fM", Double(n) / 1_000_000)
    }

    static func cost(_ b: UsageBucket) -> String {
        String(format: "$%.2f", b.cost) + (b.hasUnpriced ? "+" : "")
    }

    static func bar(_ pct: Double, width: Int = 10) -> String {
        let filled = max(0, min(width, Int((pct / 100 * Double(width)).rounded())))
        return String(repeating: "▓", count: filled) + String(repeating: "░", count: width - filled)
    }

    static func limitLine(_ name: String, _ w: LimitWindow?, now: Date) -> String {
        guard let w else { return "\(name)  –" }
        var s = "\(name)  \(bar(w.utilization)) \(percent(w.utilization))"
        if let r = w.resetsAt { s += " · resets in \(countdown(to: r, now: now))" }
        return s
    }

    static func bucketLine(_ label: String, _ b: UsageBucket) -> String {
        "\(label)  \(tokens(b.tokens.total)) tokens · \(cost(b))"
    }
}
