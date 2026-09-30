import XCTest
@testable import ClaudeUsage

@MainActor
final class UsageFetcherTests: XCTestCase {
    final class FakeTokens: TokenProviding {
        var results: [Result<OAuthToken, TokenError>]
        var calls = 0
        init(_ r: [Result<OAuthToken, TokenError>]) { results = r }
        func token() throws -> OAuthToken {
            defer { calls += 1 }
            return try results[min(calls, results.count - 1)].get()
        }
    }

    final class FakeClient: LimitsFetching {
        var results: [Result<Limits, UsageError>]
        var calls = 0
        init(_ r: [Result<Limits, UsageError>]) { results = r }
        func fetchLimits(accessToken: String) async throws -> Limits {
            defer { calls += 1 }
            return try results[min(calls, results.count - 1)].get()
        }
    }

    private let tok = OAuthToken(accessToken: "t", expiresAt: nil)
    private let limits = Limits(fiveHour: LimitWindow(utilization: 40, resetsAt: nil),
                                sevenDay: LimitWindow(utilization: 10, resetsAt: nil))
    private var emptyDir: URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    private func make(tokens: FakeTokens, client: FakeClient) -> UsageFetcher {
        UsageFetcher(tokens: tokens, client: client, scanner: LocalUsageScanner(root: emptyDir), now: { Date() })
    }

    func testSuccessPublishesLimits() async {
        let f = make(tokens: FakeTokens([.success(tok)]), client: FakeClient([.success(limits)]))
        await f.refresh()
        XCTAssertEqual(f.snapshot.limits, limits)
        XCTAssertEqual(f.snapshot.status, .ok)
    }

    func test401RetriesOnceWithFreshToken() async {
        let tokens = FakeTokens([.success(tok)])
        let client = FakeClient([.failure(.unauthorized), .success(limits)])
        let f = make(tokens: tokens, client: client)
        await f.refresh()
        XCTAssertEqual(tokens.calls, 2)
        XCTAssertEqual(client.calls, 2)
        XCTAssertEqual(f.snapshot.limits, limits)
    }

    func testMissingKeychainItemIsUnavailableButLocalStatsStillPublished() async {
        let f = make(tokens: FakeTokens([.failure(.notFound)]), client: FakeClient([.success(limits)]))
        var updates = 0
        f.onUpdate = { _ in updates += 1 }
        await f.refresh()
        XCTAssertNil(f.snapshot.limits)
        XCTAssertEqual(f.snapshot.status, .unavailable("Sign in to Claude Code"))
        XCTAssertEqual(f.snapshot.local, .empty)
        XCTAssertEqual(updates, 1)
    }

    func testExpiredTokenMessage() async {
        let f = make(tokens: FakeTokens([.failure(.expired)]), client: FakeClient([.success(limits)]))
        await f.refresh()
        XCTAssertEqual(f.snapshot.status, .unavailable("Open Claude Code to refresh login"))
    }

    func testKeepsLastLimitsThenGoesStaleAfterTwoFailures() async {
        let client = FakeClient([.success(limits), .failure(.http(500)), .failure(.http(500))])
        let f = make(tokens: FakeTokens([.success(tok)]), client: client)
        await f.refresh()
        await f.refresh()
        XCTAssertEqual(f.snapshot.limits, limits)
        XCTAssertEqual(f.snapshot.status, .ok)
        await f.refresh()
        XCTAssertEqual(f.snapshot.limits, limits)
        XCTAssertEqual(f.snapshot.status, .stale)
    }

    func testFailureWithNoPriorLimitsIsUnavailable() async {
        let f = make(tokens: FakeTokens([.success(tok)]), client: FakeClient([.failure(.decoding)]))
        await f.refresh()
        XCTAssertNil(f.snapshot.limits)
        XCTAssertEqual(f.snapshot.status, .unavailable("Usage endpoint unavailable"))
    }
}
