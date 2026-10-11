import AppKit
import XCTest
@testable import ClaudeUsage

@MainActor
final class InstallMainMenuTests: XCTestCase {
    func test_installMainMenu_addsEditShortcutsAndQuitNamedAfterApp() {
        let app = NSApplication.shared
        let previous = app.mainMenu
        addTeardownBlock { @MainActor in app.mainMenu = previous }

        installMainMenu()

        let main = app.mainMenu
        XCTAssertEqual(main?.items[0].submenu?.items.last?.title, "Quit ClaudeUsage")
        XCTAssertEqual(main?.items[1].submenu?.items.map(\.title), ["Cut", "Copy", "Paste", "Select All"])
    }
}
