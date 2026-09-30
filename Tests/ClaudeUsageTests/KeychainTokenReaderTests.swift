import XCTest
@testable import ClaudeUsage

final class KeychainTokenReaderTests: XCTestCase {
    private let now = DateParsing.parse("2026-09-30T12:00:00Z")!

    private func blob(expiresAtMs: Double?, token: String? = "tok-123") -> Data {
        var oauth: [String: Any] = [:]
        if let token { oauth["accessToken"] = token }
        if let expiresAtMs { oauth["expiresAt"] = expiresAtMs }
        // swiftlint:disable:next force_try
        return try! JSONSerialization.data(withJSONObject: ["claudeAiOauth": oauth])
    }

    func testParsesTokenAndExpiry() throws {
        let future = (now.timeIntervalSince1970 + 3600) * 1000
        let t = try KeychainTokenReader.parse(blob(expiresAtMs: future), now: now)
        XCTAssertEqual(t.accessToken, "tok-123")
        XCTAssertEqual(t.expiresAt, Date(timeIntervalSince1970: future / 1000))
    }

    func testExpiredTokenThrowsExpired() {
        let past = (now.timeIntervalSince1970 - 10) * 1000
        XCTAssertThrowsError(try KeychainTokenReader.parse(blob(expiresAtMs: past), now: now)) {
            XCTAssertEqual($0 as? TokenError, .expired)
        }
    }

    func testExitStatusMapsNotFoundVersusDenied() {
        XCTAssertEqual(KeychainTokenReader.error(forExitStatus: 44), .notFound)
        XCTAssertEqual(KeychainTokenReader.error(forExitStatus: 51), .denied)
        XCTAssertEqual(KeychainTokenReader.error(forExitStatus: 128), .denied)
    }

    func testMissingTokenOrBadJSONThrowsUnreadable() {
        XCTAssertThrowsError(try KeychainTokenReader.parse(blob(expiresAtMs: nil, token: nil), now: now)) {
            XCTAssertEqual($0 as? TokenError, .unreadable)
        }
        XCTAssertThrowsError(try KeychainTokenReader.parse(Data("junk".utf8), now: now)) {
            XCTAssertEqual($0 as? TokenError, .unreadable)
        }
    }
}
