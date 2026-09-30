import XCTest
@testable import ClaudeUsage

final class UsageClientTests: XCTestCase {
    struct FakeTransport: HTTPTransport {
        var status = 200
        var body = Data()
        var capture: ((URLRequest) -> Void)?
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            capture?(request)
            return (body, status)
        }
    }

    private let full = """
    {"five_hour":{"utilization":42.0,"resets_at":"2026-09-30T14:00:00.123456+00:00"},
     "seven_day":{"utilization":18.5,"resets_at":"2026-10-03T09:00:00+00:00"},
     "seven_day_opus":null}
    """

    func testDecodesBothWindows() throws {
        let l = try UsageClient.decode(Data(full.utf8))
        XCTAssertEqual(l.fiveHour?.utilization, 42.0)
        XCTAssertEqual(l.sevenDay?.utilization, 18.5)
        XCTAssertEqual(l.fiveHour?.resetsAt, DateParsing.parse("2026-09-30T14:00:00Z"))
    }

    func testNullWindowBecomesNilNotError() throws {
        let l = try UsageClient.decode(Data(#"{"five_hour":{"utilization":5,"resets_at":null},"seven_day":null}"#.utf8))
        XCTAssertEqual(l.fiveHour?.utilization, 5)
        XCTAssertNil(l.fiveHour?.resetsAt)
        XCTAssertNil(l.sevenDay)
    }

    func testNoKnownWindowsIsDecodingError() {
        XCTAssertThrowsError(try UsageClient.decode(Data(#"{"something":"else"}"#.utf8))) {
            XCTAssertEqual($0 as? UsageError, .decoding)
        }
        XCTAssertThrowsError(try UsageClient.decode(Data("[]".utf8))) {
            XCTAssertEqual($0 as? UsageError, .decoding)
        }
    }

    func testRequestShapeAndSuccess() async throws {
        var seen: URLRequest?
        let t = FakeTransport(body: Data(full.utf8), capture: { seen = $0 })
        let l = try await UsageClient(transport: t).fetchLimits(accessToken: "abc")
        XCTAssertEqual(l.fiveHour?.utilization, 42.0)
        XCTAssertEqual(seen?.url?.absoluteString, "https://api.anthropic.com/api/oauth/usage")
        XCTAssertEqual(seen?.value(forHTTPHeaderField: "Authorization"), "Bearer abc")
        XCTAssertEqual(seen?.value(forHTTPHeaderField: "anthropic-beta"), "oauth-2025-04-20")
    }

    func test401MapsToUnauthorizedAnd500ToHTTP() async {
        do {
            _ = try await UsageClient(transport: FakeTransport(status: 401)).fetchLimits(accessToken: "x")
            XCTFail("expected throw")
        } catch { XCTAssertEqual(error as? UsageError, .unauthorized) }
        do {
            _ = try await UsageClient(transport: FakeTransport(status: 500)).fetchLimits(accessToken: "x")
            XCTFail("expected throw")
        } catch { XCTAssertEqual(error as? UsageError, .http(500)) }
    }
}
