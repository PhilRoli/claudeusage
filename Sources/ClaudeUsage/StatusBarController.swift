import AppKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let config: AppConfig
    private var snapshot = UsageSnapshot(limits: nil, status: .unavailable("Loading…"), local: .empty, updatedAt: Date())
    private let mono = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

    var onRefresh: () -> Void = {}
    var onPreferences: () -> Void = {}

    init(config: AppConfig) {
        self.config = config
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        render(snapshot)
    }

    func render(_ snapshot: UsageSnapshot) {
        self.snapshot = snapshot
        let limits = snapshot.limits?.current(at: Date())
        let peak = [limits?.fiveHour, limits?.sevenDay].compactMap { $0?.utilization }.max() ?? 0
        let color: NSColor = peak >= config.criticalThreshold ? .systemRed
            : peak >= config.warnThreshold ? .systemOrange : .labelColor
        var title = Format.title(limits)
        if case .stale = snapshot.status { title += "*" }
        item.button?.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: color,
        ])
    }

    // Rebuild on open so countdowns are current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let now = Date()

        switch snapshot.status {
        case .unavailable(let msg): menu.addItem(text("⚠︎ \(msg)"))
        case .stale(let msg): menu.addItem(text("⚠︎ Last known values — \(msg)"))
        case .ok: break
        }
        let limits = snapshot.limits?.current(at: now)
        menu.addItem(text(Format.limitLine("Session (5h)", limits?.fiveHour, now: now)))
        menu.addItem(text(Format.limitLine("Weekly      ", limits?.sevenDay, now: now)))
        menu.addItem(.separator())

        menu.addItem(text(Format.bucketLine("Today", snapshot.local.today)))
        menu.addItem(text(Format.bucketLine("7 days", snapshot.local.last7d)))
        menu.addItem(text(Format.bucketLine("30 days", snapshot.local.last30d)))
        menu.addItem(submenu("By model (30d)", snapshot.local.byModel))
        menu.addItem(submenu("By project (30d)", snapshot.local.byProject))
        menu.addItem(.separator())

        let f = DateFormatter()
        f.timeStyle = .short
        menu.addItem(text("Updated \(f.string(from: snapshot.updatedAt))"))
        menu.addItem(action("Refresh now", #selector(refreshClicked), key: "r"))
        menu.addItem(action("Preferences…", #selector(preferencesClicked), key: ","))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func text(_ s: String) -> NSMenuItem {
        let i = NSMenuItem()
        i.attributedTitle = NSAttributedString(string: s, attributes: [.font: mono])
        i.isEnabled = false
        return i
    }

    private func action(_ title: String, _ sel: Selector, key: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        i.target = self
        return i
    }

    private func submenu(_ title: String, _ rows: [NamedBucket]) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let sub = NSMenu()
        if rows.isEmpty { sub.addItem(text("No data")) }
        for r in rows { sub.addItem(text(Format.bucketLine(r.name, r.bucket))) }
        parent.submenu = sub
        return parent
    }

    @objc private func refreshClicked() { onRefresh() }
    @objc private func preferencesClicked() { onPreferences() }
}
