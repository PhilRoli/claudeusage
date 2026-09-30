import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let config = AppConfig.shared
    private var fetcher: UsageFetcher!
    private var statusBar: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        fetcher = UsageFetcher(tokens: KeychainTokenReader(), client: UsageClient(), scanner: LocalUsageScanner())
        statusBar = StatusBarController(config: config)
        statusBar.onRefresh = { [weak self] in
            Task { await self?.fetcher.refresh() }
        }
        fetcher.onUpdate = { [weak self] snapshot in
            self?.statusBar.render(snapshot)
        }
        fetcher.start(interval: config.refreshInterval)
    }
}
