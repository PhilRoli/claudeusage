import XCTest
@testable import ClaudeUsage

final class PredictionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let five = Limits.fiveHourLength

    /// Window that is `elapsedFraction` through its length at `now`.
    private func window(_ util: Double, elapsedFraction: Double) -> LimitWindow {
        LimitWindow(utilization: util, resetsAt: now.addingTimeInterval(five * (1 - elapsedFraction)))
    }

    func testOnPaceProjectsLinearly() {
        let p = window(40, elapsedFraction: 0.5).prediction(windowLength: five, now: now)
        XCTAssertEqual(p?.projected ?? 0, 80, accuracy: 0.001)
        XCTAssertNil(p?.hitsLimitIn)
    }

    func testOverPaceReportsTimeToLimit() {
        // 60% after 2.5h burns 40 more points in 2.5h * 40/60 = 100 minutes.
        let p = window(60, elapsedFraction: 0.5).prediction(windowLength: five, now: now)
        XCTAssertEqual(p?.projected ?? 0, 120, accuracy: 0.001)
        XCTAssertEqual(p?.hitsLimitIn ?? 0, five * 0.5 * 40 / 60, accuracy: 0.001)
    }

    func testNoPredictionWhenTooEarlyOrIdleOrAtLimitOrNoReset() {
        XCTAssertNil(window(10, elapsedFraction: 0.02).prediction(windowLength: five, now: now))
        XCTAssertNil(window(0, elapsedFraction: 0.5).prediction(windowLength: five, now: now))
        XCTAssertNil(window(100, elapsedFraction: 0.5).prediction(windowLength: five, now: now))
        XCTAssertNil(LimitWindow(utilization: 50, resetsAt: nil).prediction(windowLength: five, now: now))
    }

    func testWillHitLimitAndTitleWarning() {
        let hot = Limits(fiveHour: window(60, elapsedFraction: 0.5), sevenDay: nil)
        XCTAssertTrue(hot.willHitLimit(at: now))
        XCTAssertEqual(Format.title(hot, now: now), "⚠ 60% · –")
        let calm = Limits(fiveHour: window(20, elapsedFraction: 0.5), sevenDay: nil)
        XCTAssertFalse(calm.willHitLimit(at: now))
        XCTAssertEqual(Format.title(calm, now: now), "20% · –")
    }

    func testDetailLineWording() {
        let w = window(40, elapsedFraction: 0.5)
        let ok = Prediction(projected: 80, hitsLimitIn: nil)
        XCTAssertEqual(Format.detailLine(w, ok, now: now), "resets in 2h 30m · on pace for 80%")
        let hit = Prediction(projected: 120, hitsLimitIn: 3600)
        XCTAssertEqual(Format.detailLine(w, hit, now: now), "resets in 2h 30m · ⚠ hits limit in 1h 0m")
    }
}
