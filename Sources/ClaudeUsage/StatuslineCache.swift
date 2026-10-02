import Foundation

/// Shares the latest limits with the Claude Code statusline script (`~/.claude/statusline-command.sh`).
enum StatuslineCache {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/.statusline-usage-cache")

    static func render(_ limits: Limits, at now: Date) -> String {
        let live = limits.current(at: now)
        var lines: [String] = []
        if let w = live.fiveHour {
            lines.append("UTILIZATION=\(Int(w.utilization.rounded()))")
            lines.append("RESETS_AT=\(w.resetsAt.map(iso) ?? "")")
        }
        if let w = live.sevenDay {
            lines.append("WEEKLY_UTILIZATION=\(Int(w.utilization.rounded()))")
            lines.append("WEEKLY_RESETS_AT=\(w.resetsAt.map(iso) ?? "")")
        }
        lines.append("TIMESTAMP=\(Int(now.timeIntervalSince1970))")
        return lines.joined(separator: "\n") + "\n"
    }

    static func write(_ limits: Limits, at now: Date = Date()) {
        try? render(limits, at: now).write(to: url, atomically: true, encoding: .utf8)
    }

    private static func iso(_ d: Date) -> String {
        ISO8601DateFormatter().string(from: d)
    }
}
