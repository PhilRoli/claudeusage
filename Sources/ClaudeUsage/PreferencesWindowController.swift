import AppKit

@MainActor
final class PreferencesWindowController: NSWindowController {
    private let config: AppConfig
    private let onChange: () -> Void

    private let intervals: [(String, TimeInterval)] = [("1 minute", 60), ("2 minutes", 120), ("5 minutes", 300), ("10 minutes", 600)]
    private let warns: [Double] = [70, 80, 90]
    private let criticals: [Double] = [90, 95, 99]

    private let intervalPopup = NSPopUpButton()
    private let warnPopup = NSPopUpButton()
    private let criticalPopup = NSPopUpButton()
    private let notifyCheck = NSButton(checkboxWithTitle: "Notify at thresholds", target: nil, action: nil)
    private let loginCheck = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)

    init(config: AppConfig, onChange: @escaping () -> Void) {
        self.config = config
        self.onChange = onChange
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "ClaudeUsage Preferences"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        build()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private func build() {
        intervalPopup.addItems(withTitles: intervals.map(\.0))
        intervalPopup.selectItem(at: intervals.firstIndex { $0.1 == config.refreshInterval } ?? 1)
        warnPopup.addItems(withTitles: warns.map { "\(Int($0))%" })
        warnPopup.selectItem(at: warns.firstIndex(of: config.warnThreshold) ?? 1)
        criticalPopup.addItems(withTitles: criticals.map { "\(Int($0))%" })
        criticalPopup.selectItem(at: criticals.firstIndex(of: config.criticalThreshold) ?? 1)
        notifyCheck.state = config.notificationsEnabled ? .on : .off
        loginCheck.state = LoginItem.isEnabled ? .on : .off

        for control in [intervalPopup, warnPopup, criticalPopup] {
            control.target = self
            control.action = #selector(changed)
        }
        notifyCheck.target = self
        notifyCheck.action = #selector(changed)
        loginCheck.target = self
        loginCheck.action = #selector(loginChanged)

        let stack = NSStackView(views: [
            row("Refresh every", intervalPopup),
            row("Warn at", warnPopup),
            row("Critical at", criticalPopup),
            notifyCheck,
            loginCheck,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        window?.contentView = stack
    }

    private func row(_ label: String, _ control: NSView) -> NSStackView {
        let l = NSTextField(labelWithString: label)
        l.widthAnchor.constraint(equalToConstant: 110).isActive = true
        let r = NSStackView(views: [l, control])
        r.spacing = 8
        return r
    }

    @objc private func changed() {
        config.refreshInterval = intervals[intervalPopup.indexOfSelectedItem].1
        config.warnThreshold = warns[warnPopup.indexOfSelectedItem]
        config.criticalThreshold = criticals[criticalPopup.indexOfSelectedItem]
        config.notificationsEnabled = notifyCheck.state == .on
        onChange()
    }

    @objc private func loginChanged() {
        do { try LoginItem.set(loginCheck.state == .on) } catch { NSSound.beep() }
        loginCheck.state = LoginItem.isEnabled ? .on : .off // reflect what the system actually accepted
    }
}
