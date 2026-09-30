import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let config = AppConfig.shared
    private let notifier = NotificationManager()
    private var thresholds = ThresholdTracker()
    private var fetcher: UsageFetcher!
    private var statusBar: StatusBarController!
    private var prefs: PreferencesWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        fetcher = UsageFetcher(tokens: KeychainTokenReader(), client: UsageClient(), scanner: LocalUsageScanner())
        statusBar = StatusBarController(config: config)
        statusBar.onRefresh = { [weak self] in
            Task { await self?.fetcher.refresh() }
        }
        statusBar.onPreferences = { [weak self] in self?.showPreferences() }
        fetcher.onUpdate = { [weak self] snapshot in
            self?.statusBar.render(snapshot)
            self?.notifyIfNeeded(snapshot)
        }
        notifier.requestAuthorization()
        fetcher.start(interval: config.refreshInterval)
    }

    private func showPreferences() {
        if prefs == nil {
            prefs = PreferencesWindowController(config: config) { [weak self] in
                guard let self else { return }
                self.fetcher.start(interval: self.config.refreshInterval)
                self.statusBar.render(self.fetcher.snapshot)
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        prefs?.showWindow(nil)
    }

    private func notifyIfNeeded(_ snapshot: UsageSnapshot) {
        guard config.notificationsEnabled, snapshot.status == .ok else { return }
        let windows: [(String, String, LimitWindow?)] = [
            ("5h", "Session (5h)", snapshot.limits?.fiveHour),
            ("7d", "Weekly", snapshot.limits?.sevenDay),
        ]
        for (id, name, window) in windows {
            guard let window else { continue }
            let key = "\(id):\(window.resetsAt?.timeIntervalSince1970 ?? 0)"
            let crossed = thresholds.newCrossings(
                windowKey: key, utilization: window.utilization,
                thresholds: [config.warnThreshold, config.criticalThreshold])
            if let top = crossed.max() {
                var body = "\(Format.percent(window.utilization)) used"
                if let r = window.resetsAt { body += " · resets in \(Format.countdown(to: r, now: Date()))" }
                notifier.post(title: "\(name) passed \(Int(top))%", body: body)
            }
        }
    }
}
