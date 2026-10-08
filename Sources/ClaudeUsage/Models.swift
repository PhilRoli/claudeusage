import Foundation

struct LimitWindow: Equatable {
    var utilization: Double
    var resetsAt: Date?
}

struct Limits: Equatable {
    var fiveHour: LimitWindow?
    var sevenDay: LimitWindow?
}

extension Limits {
    /// Drops windows whose reset time has passed: their utilization is out of date.
    func current(at now: Date) -> Limits {
        func live(_ w: LimitWindow?) -> LimitWindow? {
            guard let w else { return nil }
            if let r = w.resetsAt, r <= now { return nil }
            return w
        }
        return Limits(fiveHour: live(fiveHour), sevenDay: live(sevenDay))
    }
}

struct Prediction: Equatable {
    /// Utilization expected at reset if the current burn rate continues.
    let projected: Double
    /// Time until 100% is reached, when that happens before the window resets.
    let hitsLimitIn: TimeInterval?
}

extension LimitWindow {
    /// Share of the window that must have elapsed before extrapolating; earlier is too noisy.
    static let minElapsedFraction = 0.05

    /// Linear extrapolation of the burn rate so far in the window.
    func prediction(windowLength: TimeInterval, now: Date) -> Prediction? {
        guard let resetsAt, utilization > 0, utilization < 100 else { return nil }
        let elapsed = now.timeIntervalSince(resetsAt.addingTimeInterval(-windowLength))
        guard elapsed >= windowLength * Self.minElapsedFraction, elapsed <= windowLength else { return nil }
        let projected = utilization / elapsed * windowLength
        guard projected >= 100 else { return Prediction(projected: projected, hitsLimitIn: nil) }
        let secondsToLimit = (100 - utilization) / utilization * elapsed
        return Prediction(projected: projected, hitsLimitIn: secondsToLimit)
    }
}

extension Limits {
    static let fiveHourLength: TimeInterval = 5 * 3600
    static let sevenDayLength: TimeInterval = 7 * 86400

    func fiveHourPrediction(at now: Date) -> Prediction? {
        fiveHour?.prediction(windowLength: Self.fiveHourLength, now: now)
    }

    func sevenDayPrediction(at now: Date) -> Prediction? {
        sevenDay?.prediction(windowLength: Self.sevenDayLength, now: now)
    }

    /// True if either window is on track to reach 100% before it resets.
    func willHitLimit(at now: Date) -> Bool {
        fiveHourPrediction(at: now)?.hitsLimitIn != nil || sevenDayPrediction(at: now)?.hitsLimitIn != nil
    }
}

struct OAuthToken: Equatable {
    let accessToken: String
    let expiresAt: Date?
}

struct TokenCounts: Equatable {
    var input = 0
    var output = 0
    var cacheRead = 0
    var cacheWrite5m = 0
    var cacheWrite1h = 0

    var total: Int { input + output + cacheRead + cacheWrite5m + cacheWrite1h }

    mutating func add(_ o: TokenCounts) {
        input += o.input
        output += o.output
        cacheRead += o.cacheRead
        cacheWrite5m += o.cacheWrite5m
        cacheWrite1h += o.cacheWrite1h
    }
}

struct UsageRecord: Equatable {
    let key: String
    let timestamp: Date
    let model: String
    let project: String
    let tokens: TokenCounts
}

struct UsageBucket: Equatable {
    var tokens = TokenCounts()
    var cost = 0.0
    var hasUnpriced = false

    mutating func add(_ r: UsageRecord) {
        tokens.add(r.tokens)
        if let c = PricingTable.cost(r.tokens, model: r.model) {
            cost += c
        } else {
            hasUnpriced = true
        }
    }
}

struct NamedBucket: Equatable {
    let name: String
    let bucket: UsageBucket
}

struct LocalStats: Equatable {
    var today = UsageBucket()
    var last7d = UsageBucket()
    var last30d = UsageBucket()
    var byModel: [NamedBucket] = []
    var byProject: [NamedBucket] = []

    static let empty = LocalStats()
}

enum LimitsStatus: Equatable {
    case ok
    case stale(String)
    case unavailable(String)
}

struct UsageSnapshot: Equatable {
    var limits: Limits?
    var status: LimitsStatus
    var local: LocalStats
    var updatedAt: Date
}
