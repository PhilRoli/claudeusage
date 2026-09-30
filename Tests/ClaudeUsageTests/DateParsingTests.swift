import XCTest
@testable import ClaudeUsage

final class DateParsingTests: XCTestCase {
    func testMicrosecondsWithOffset() {
        let d = DateParsing.parse("2026-09-30T14:00:00.123456+00:00")
        XCTAssertEqual(d, DateParsing.parse("2026-09-30T14:00:00Z"))
        XCTAssertNotNil(d)
    }

    func testMillisecondsZulu() {
        XCTAssertNotNil(DateParsing.parse("2026-09-21T15:07:45.960Z"))
    }

    func testGarbageIsNil() {
        XCTAssertNil(DateParsing.parse("not a date"))
    }
}
