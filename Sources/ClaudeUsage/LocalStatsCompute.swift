import Foundation

extension LocalStats {
    static func compute(records: [UsageRecord], now: Date, calendar: Calendar = .current) -> LocalStats {
        var stats = LocalStats()
        let startOfToday = calendar.startOfDay(for: now)
        let sevenDays = now.addingTimeInterval(-7 * 86400)
        let thirtyDays = now.addingTimeInterval(-30 * 86400)
        var models: [String: UsageBucket] = [:]
        var projects: [String: UsageBucket] = [:]

        for r in records where r.timestamp >= thirtyDays && r.timestamp <= now {
            stats.last30d.add(r)
            if r.timestamp >= sevenDays { stats.last7d.add(r) }
            if r.timestamp >= startOfToday { stats.today.add(r) }
            models[r.model, default: UsageBucket()].add(r)
            projects[r.project, default: UsageBucket()].add(r)
        }

        func top(_ d: [String: UsageBucket]) -> [NamedBucket] {
            d.map { NamedBucket(name: $0.key, bucket: $0.value) }
                .sorted { $0.bucket.tokens.total > $1.bucket.tokens.total }
                .prefix(5).map { $0 }
        }
        stats.byModel = top(models)
        stats.byProject = top(projects)
        return stats
    }
}
