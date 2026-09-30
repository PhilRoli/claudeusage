import XCTest
@testable import ClaudeUsage

final class PricingTableTests: XCTestCase {
    func testSonnetInputPlusOutput() {
        let t = TokenCounts(input: 1_000_000, output: 1_000_000)
        XCTAssertEqual(PricingTable.cost(t, model: "claude-sonnet-5")!, 18.0, accuracy: 0.0001)
    }

    func testCacheMultipliers() {
        let read = TokenCounts(cacheRead: 1_000_000)
        let w5 = TokenCounts(cacheWrite5m: 1_000_000)
        let w1 = TokenCounts(cacheWrite1h: 1_000_000)
        XCTAssertEqual(PricingTable.cost(read, model: "claude-sonnet-5")!, 0.30, accuracy: 0.0001)
        XCTAssertEqual(PricingTable.cost(w5, model: "claude-sonnet-5")!, 3.75, accuracy: 0.0001)
        XCTAssertEqual(PricingTable.cost(w1, model: "claude-sonnet-5")!, 6.0, accuracy: 0.0001)
    }

    func testUnknownModelIsNilNotZero() {
        XCTAssertNil(PricingTable.cost(TokenCounts(input: 10), model: "mystery-model-9"))
    }

    func testBucketFlagsUnpriced() {
        var b = UsageBucket()
        let r = UsageRecord(key: "a", timestamp: Date(), model: "mystery-model-9", project: "p",
                            tokens: TokenCounts(input: 10))
        b.add(r)
        XCTAssertTrue(b.hasUnpriced)
        XCTAssertEqual(b.tokens.total, 10)
        XCTAssertEqual(b.cost, 0)
    }
}
