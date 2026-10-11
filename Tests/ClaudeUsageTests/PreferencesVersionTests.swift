import AppKit
import XCTest
@testable import ClaudeUsage

@MainActor
final class PreferencesVersionTests: XCTestCase {
    private func textFields(in view: NSView) -> [NSTextField] {
        view.subviews.flatMap { sub -> [NSTextField] in
            let nested = textFields(in: sub)
            if let field = sub as? NSTextField { return [field] + nested }
            return nested
        }
    }

    func testShowsVersionLineAndWindowFitsAllRows() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "PreferencesVersionTests-\(UUID().uuidString)"))
        let controller = PreferencesWindowController(config: AppConfig(defaults: defaults), onChange: {})
        let window = try XCTUnwrap(controller.window)
        let content = try XCTUnwrap(window.contentView)
        let version = try XCTUnwrap(textFields(in: content).first {
            $0.stringValue.hasPrefix("Version") || $0.stringValue == "Development build"
        })
        content.layoutSubtreeIfNeeded()
        XCTAssertTrue(content.bounds.insetBy(dx: -1, dy: -1).contains(version.convert(version.bounds, to: content)))
        let windowHeight = window.contentRect(forFrameRect: window.frame).height
        XCTAssertGreaterThanOrEqual(windowHeight, content.fittingSize.height - 1)
    }
}
