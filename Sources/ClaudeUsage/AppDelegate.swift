import AppKit

private struct WatchedWindow {
    let id: String
    let name: String
    let window: LimitWindow?
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let config = AppConfig.shared
    private let notifier = NotificationManager()
    private var thresholds = ThresholdTracker(defaults: .standard)
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
                self.fetcher.start(interval: self.config.refreshInterval, immediate: false)
                self.statusBar.render(self.fetcher.snapshot)
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        prefs?.showWindow(nil)
    }

    private func notifyIfNeeded(_ snapshot: UsageSnapshot) {
        guard config.notificationsEnabled, snapshot.status == .ok else { return }
        let windows = [
            WatchedWindow(id: "5h", name: "Session (5h)", window: snapshot.limits?.fiveHour),
            WatchedWindow(id: "7d", name: "Weekly", window: snapshot.limits?.sevenDay)
        ]
        for watched in windows {
            guard let window = watched.window else { continue }
            let key = ThresholdTracker.windowKey(id: watched.id, resetsAt: window.resetsAt)
            let crossed = thresholds.newCrossings(
                windowKey: key, utilization: window.utilization,
                thresholds: [config.warnThreshold, config.criticalThreshold])
            if let top = crossed.max() {
                var body = "\(Format.percent(window.utilization)) used"
                if let r = window.resetsAt { body += " · resets in \(Format.countdown(to: r, now: Date()))" }
                notifier.post(title: "\(watched.name) passed \(Int(top))%", body: body)
            }
        }
    }
}
