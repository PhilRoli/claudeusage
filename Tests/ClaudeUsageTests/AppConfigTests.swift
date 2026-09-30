import XCTest
@testable import ClaudeUsage

final class AppConfigTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "ClaudeUsageTests-\(UUID().uuidString)")!
    }

    func testDefaults() {
        let c = AppConfig(defaults: makeDefaults())
        XCTAssertEqual(c.refreshInterval, 120)
        XCTAssertEqual(c.warnThreshold, 80)
        XCTAssertEqual(c.criticalThreshold, 95)
        XCTAssertTrue(c.notificationsEnabled)
    }

    func testPersistsValues() {
        let d = makeDefaults()
        let c = AppConfig(defaults: d)
        c.refreshInterval = 300
        c.notificationsEnabled = false
        let c2 = AppConfig(defaults: d)
        XCTAssertEqual(c2.refreshInterval, 300)
        XCTAssertFalse(c2.notificationsEnabled)
    }
}
