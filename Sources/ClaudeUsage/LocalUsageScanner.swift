import Foundation

actor LocalUsageScanner {
    private struct FileState { var offset: UInt64 }

    private let root: URL
    private let maxAge: TimeInterval
    private var states: [URL: FileState] = [:]
    private var records: [String: UsageRecord] = [:]

    init(root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects"),
         maxAge: TimeInterval = 30 * 86400) {
        self.root = root
        self.maxAge = maxAge
    }

    func scan(now: Date = Date()) -> [UsageRecord] {
        guard let en = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]
        ) else { return [] }
        for case let url as URL in en where url.pathExtension == "jsonl" {
            let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if now.timeIntervalSince(mtime) > maxAge { continue }
            ingest(url)
        }
        let cutoff = now.addingTimeInterval(-maxAge)
        records = records.filter { $0.value.timestamp >= cutoff }
        return Array(records.values)
    }

    private func ingest(_ url: URL) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        var offset = states[url]?.offset ?? 0
        if size < offset { offset = 0 }
        guard size > offset else { return }
        try? handle.seek(toOffset: offset)
        guard let data = try? handle.readToEnd(), let lastNewline = data.lastIndex(of: 0x0A) else { return }
        let complete = data[data.startIndex...lastNewline]
        for line in complete.split(separator: 0x0A) {
            if let r = Self.parse(line: Data(line)) { merge(r) }
        }
        states[url] = FileState(offset: offset + UInt64(complete.count))
    }

    private func merge(_ r: UsageRecord) {
        if let existing = records[r.key], existing.tokens.total > r.tokens.total { return }
        records[r.key] = r
    }

    static func parse(line: Data) -> UsageRecord? {
        guard let obj = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
              let msg = obj["message"] as? [String: Any],
              let usage = msg["usage"] as? [String: Any],
              let model = msg["model"] as? String, model != "<synthetic>",
              let id = msg["id"] as? String,
              let ts = (obj["timestamp"] as? String).flatMap(DateParsing.parse)
        else { return nil }

        func int(_ d: [String: Any], _ k: String) -> Int { (d[k] as? NSNumber)?.intValue ?? 0 }
        var write5m = 0
        var write1h = 0
        if let cc = usage["cache_creation"] as? [String: Any] {
            write5m = int(cc, "ephemeral_5m_input_tokens")
            write1h = int(cc, "ephemeral_1h_input_tokens")
        } else {
            write5m = int(usage, "cache_creation_input_tokens")
        }
        let tokens = TokenCounts(
            input: int(usage, "input_tokens"),
            output: int(usage, "output_tokens"),
            cacheRead: int(usage, "cache_read_input_tokens"),
            cacheWrite5m: write5m,
            cacheWrite1h: write1h
        )
        let project = (obj["cwd"] as? String).map { ($0 as NSString).lastPathComponent } ?? "unknown"
        let request = obj["requestId"] as? String ?? ""
        return UsageRecord(key: "\(id):\(request)", timestamp: ts, model: model, project: project, tokens: tokens)
    }
}
