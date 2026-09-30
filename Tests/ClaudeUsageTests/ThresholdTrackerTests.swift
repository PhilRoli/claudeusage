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

    func testJumpFiresBothAndNewWindowResets() {
        var t = ThresholdTracker()
        XCTAssertEqual(t.newCrossings(windowKey: "w1", utilization: 99, thresholds: [95, 80]), [80, 95])
        XCTAssertEqual(t.newCrossings(windowKey: "w2", utilization: 81, thresholds: [80, 95]), [80])
    }
}
