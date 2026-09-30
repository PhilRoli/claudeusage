import XCTest
@testable import ClaudeUsage

final class FormatTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testTitleShowsBothAndDashForMissing() {
        let both = Limits(fiveHour: LimitWindow(utilization: 42.4, resetsAt: nil),
                          sevenDay: LimitWindow(utilization: 18.5, resetsAt: nil))
        XCTAssertEqual(Format.title(both), "42% · 19%")
        XCTAssertEqual(Format.title(Limits(fiveHour: LimitWindow(utilization: 5, resetsAt: nil), sevenDay: nil)), "5% · –")
        XCTAssertEqual(Format.title(nil), "–")
    }

    func testCountdown() {
        XCTAssertEqual(Format.countdown(to: now.addingTimeInterval(2 * 3600 + 14 * 60 + 5), now: now), "2h 14m")
        XCTAssertEqual(Format.countdown(to: now.addingTimeInterval(3 * 86400 + 4 * 3600), now: now), "3d 4h")
        XCTAssertEqual(Format.countdown(to: now.addingTimeInterval(25 * 60), now: now), "25m")
        XCTAssertEqual(Format.countdown(to: now.addingTimeInterval(30), now: now), "<1m")
        XCTAssertEqual(Format.countdown(to: now.addingTimeInterval(-5), now: now), "now")
    }

    func testCurrentDropsWindowsThatAlreadyReset() {
        let l = Limits(fiveHour: LimitWindow(utilization: 95, resetsAt: now.addingTimeInterval(-1)),
                       sevenDay: LimitWindow(utilization: 10, resetsAt: now.addingTimeInterval(60)))
        XCTAssertNil(l.current(at: now).fiveHour)
        XCTAssertEqual(l.current(at: now).sevenDay?.utilization, 10)
        let open = Limits(fiveHour: LimitWindow(utilization: 5, resetsAt: nil), sevenDay: nil)
        XCTAssertEqual(open.current(at: now).fiveHour?.utilization, 5)
    }

    func testTokens() {
        XCTAssertEqual(Format.tokens(512), "512")
        XCTAssertEqual(Format.tokens(34_500), "34.5K")
        XCTAssertEqual(Format.tokens(1_234_567), "1.2M")
    }

    func testCostMarksUnpricedWithPlus() {
        var b = UsageBucket()
        b.cost = 12.345
        XCTAssertEqual(Format.cost(b), "$12.35")
        b.hasUnpriced = true
        XCTAssertEqual(Format.cost(b), "$12.35+")
    }

    func testBarAndLimitLine() {
        XCTAssertEqual(Format.bar(42), "▓▓▓▓░░░░░░")
        XCTAssertEqual(Format.bar(150), "▓▓▓▓▓▓▓▓▓▓")
        XCTAssertEqual(Format.bar(-3), "░░░░░░░░░░")
        let w = LimitWindow(utilization: 42, resetsAt: now.addingTimeInterval(3600))
        XCTAssertEqual(Format.limitLine("Session (5h)", w, now: now), "Session (5h)  ▓▓▓▓░░░░░░ 42% · resets in 1h 0m")
        XCTAssertEqual(Format.limitLine("Weekly", nil, now: now), "Weekly  –")
    }

    func testBucketLine() {
        var b = UsageBucket()
        b.tokens = TokenCounts(input: 1_000_000)
        b.cost = 3
        XCTAssertEqual(Format.bucketLine("Today", b), "Today  1.0M tokens · $3.00")
    }
}
