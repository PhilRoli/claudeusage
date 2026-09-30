import XCTest
@testable import ClaudeUsage

final class LocalUsageScannerTests: XCTestCase {
    var dir: URL!

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
    }

    private func line(id: String, req: String = "req1", out: Int, model: String = "claude-sonnet-5",
                      ts: String = "2026-09-30T10:00:00.000Z", cwd: String = "/Users/p/proj") -> String {
        """
        {"timestamp":"\(ts)","requestId":"\(req)","cwd":"\(cwd)","message":{"id":"\(id)","model":"\(model)","usage":{"input_tokens":2,"output_tokens":\(out),"cache_read_input_tokens":100,"cache_creation_input_tokens":50,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":50}}}}
        """
    }

    private func write(_ name: String, _ lines: [String], trailingNewline: Bool = true) {
        let s = lines.joined(separator: "\n") + (trailingNewline ? "\n" : "")
        try! s.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    func testParsesUsageFields() {
        let r = LocalUsageScanner.parse(line: Data(line(id: "m1", out: 7).utf8))!
        XCTAssertEqual(r.tokens, TokenCounts(input: 2, output: 7, cacheRead: 100, cacheWrite5m: 0, cacheWrite1h: 50))
        XCTAssertEqual(r.project, "proj")
        XCTAssertEqual(r.model, "claude-sonnet-5")
        XCTAssertEqual(r.key, "m1:req1")
    }

    func testSkipsNonUsageSyntheticAndGarbageLines() {
        XCTAssertNil(LocalUsageScanner.parse(line: Data(#"{"type":"user","message":{"content":"hi"}}"#.utf8)))
        XCTAssertNil(LocalUsageScanner.parse(line: Data(line(id: "m", out: 1, model: "<synthetic>").utf8)))
        XCTAssertNil(LocalUsageScanner.parse(line: Data("not json".utf8)))
    }

    func testSameMessageKeepsLargestNotSum() async {
        write("a.jsonl", [line(id: "m1", out: 10), line(id: "m1", out: 500), line(id: "m1", out: 40)])
        let scanner = LocalUsageScanner(root: dir)
        let records = await scanner.scan()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].tokens.output, 500)
    }

    func testIncrementalScanReadsOnlyNewLinesAndSkipsPartialLine() async throws {
        let url = dir.appendingPathComponent("a.jsonl")
        write("a.jsonl", [line(id: "m1", out: 1)])
        let scanner = LocalUsageScanner(root: dir)
        var records = await scanner.scan()
        XCTAssertEqual(records.count, 1)

        // append one complete line plus a half-written line
        let partial = String(line(id: "m3", out: 3).prefix(40))
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data((line(id: "m2", out: 2) + "\n" + partial).utf8))
        try handle.close()

        records = await scanner.scan()
        XCTAssertEqual(Set(records.map(\.key)), ["m1:req1", "m2:req1"])

        // finish the partial line
        let h2 = try FileHandle(forWritingTo: url)
        try h2.seekToEnd()
        try h2.write(contentsOf: Data((String(line(id: "m3", out: 3).dropFirst(40)) + "\n").utf8))
        try h2.close()

        records = await scanner.scan()
        XCTAssertEqual(Set(records.map(\.key)), ["m1:req1", "m2:req1", "m3:req1"])
    }

    func testIgnoresFilesOlderThanMaxAge() async {
        write("old.jsonl", [line(id: "old", out: 1)])
        let old = Date().addingTimeInterval(-40 * 86400)
        try! FileManager.default.setAttributes([.modificationDate: old],
                                               ofItemAtPath: dir.appendingPathComponent("old.jsonl").path)
        let records = await LocalUsageScanner(root: dir).scan()
        XCTAssertTrue(records.isEmpty)
    }

    func testComputeBucketsByWindowModelAndProject() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = DateParsing.parse("2026-09-30T12:00:00Z")!
        func rec(_ key: String, _ ts: String, model: String = "claude-sonnet-5", project: String = "a") -> UsageRecord {
            UsageRecord(key: key, timestamp: DateParsing.parse(ts)!, model: model, project: project,
                        tokens: TokenCounts(input: 10))
        }
        let records = [
            rec("1", "2026-09-30T08:00:00Z"),
            rec("2", "2026-09-27T08:00:00Z", project: "b"),
            rec("3", "2026-09-05T08:00:00Z", model: "mystery-1"),
            rec("4", "2026-08-01T08:00:00Z"),
        ]
        let s = LocalStats.compute(records: records, now: now, calendar: cal)
        XCTAssertEqual(s.today.tokens.total, 10)
        XCTAssertEqual(s.last7d.tokens.total, 20)
        XCTAssertEqual(s.last30d.tokens.total, 30)
        XCTAssertTrue(s.last30d.hasUnpriced)
        XCTAssertEqual(Set(s.byModel.map(\.name)), ["claude-sonnet-5", "mystery-1"])
        XCTAssertEqual(s.byProject.first?.name, "a")
    }
}
