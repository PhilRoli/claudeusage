import XCTest
@testable import ClaudeUsage

final class ThresholdTrackerTests: XCTestCase {
    func testFiresOncePerThresholdPerWindow() {
        var t = ThresholdTracker()
        XCTAssertEqual(t.newCrossings(windowKey: "w1", utilization: 50, thresholds: [80, 95]), [])
        XCTAssertEqual(t.newCrossings(windowKey: "w1", utilization: 82, thresholds: [80, 95]), [80])
        XCTAssertEqual(t.newCrossings(windowKey: "w1", utilization: 83, thresholds: [80, 95]), [])
        XCTAssertEqual(t.newCrossings(windowKey: "w1", utilization: 96, thresholds: [80, 95]), [95])
    }

    func testPersistsAcrossInstances() {
        let d = UserDefaults(suiteName: "TT-\(UUID().uuidString)")!
        var a = ThresholdTracker(defaults: d)
        XCTAssertEqual(a.newCrossings(windowKey: "w", utilization: 85, thresholds: [80, 95]), [80])
        var b = ThresholdTracker(defaults: d)
        XCTAssertEqual(b.newCrossings(windowKey: "w", utilization: 86, thresholds: [80, 95]), [])
        XCTAssertEqual(b.newCrossings(windowKey: "w", utilization: 96, thresholds: [80, 95]), [95])
    }

    func testWindowKeyIgnoresSubMinuteJitterButSeparatesWindows() {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let k1 = ThresholdTracker.windowKey(id: "5h", resetsAt: base.addingTimeInterval(0.268))
        let k2 = ThresholdTracker.windowKey(id: "5h", resetsAt: base.addingTimeInterval(0.9))
        let next = ThresholdTracker.windowKey(id: "5h", resetsAt: base.addingTimeInterval(5 * 3600))
        XCTAssertEqual(k1, k2)
        XCTAssertNotEqual(k1, next)
        XCTAssertNotEqual(k1, ThresholdTracker.windowKey(id: "7d", resetsAt: base))
        XCTAssertEqual(ThresholdTracker.windowKey(id: "5h", resetsAt: nil), "5h:none")
    }

    func testOldKeysArePrunedSoStorageStaysBounded() {
        let d = UserDefaults(suiteName: "TT-\(UUID().uuidString)")!
        var t = ThresholdTracker(defaults: d)
        for i in 0..<40 { _ = t.newCrossings(windowKey: "k\(i)", utilization: 99, thresholds: [80]) }
        let stored = (d.data(forKey: "firedThresholds")).flatMap { try? JSONDecoder().decode([String: [Double]].self, from: $0) }
        XCTAssertLessThanOrEqual(stored?.count ?? 999, 16)
        // the newest key is still remembered
        var again = ThresholdTracker(defaults: d)
        XCTAssertEqual(again.newCrossings(windowKey: "k39", utilization: 99, thresholds: [80]), [])
    }

    func testJumpFiresBothAndNewWindowResets() {
        var t = ThresholdTracker()
        XCTAssertEqual(t.newCrossings(windowKey: "w1", utilization: 99, thresholds: [95, 80]), [80, 95])
        XCTAssertEqual(t.newCrossings(windowKey: "w2", utilization: 81, thresholds: [80, 95]), [80])
    }
}
