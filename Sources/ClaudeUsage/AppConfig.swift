import Foundation

final class AppConfig {
    static let shared = AppConfig()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var refreshInterval: TimeInterval {
        get { let v = defaults.double(forKey: "refreshInterval"); return v > 0 ? v : 120 }
        set { defaults.set(newValue, forKey: "refreshInterval") }
    }

    var warnThreshold: Double {
        get { let v = defaults.double(forKey: "warnThreshold"); return v > 0 ? v : 80 }
        set { defaults.set(newValue, forKey: "warnThreshold") }
    }

    var criticalThreshold: Double {
        get { let v = defaults.double(forKey: "criticalThreshold"); return v > 0 ? v : 95 }
        set { defaults.set(newValue, forKey: "criticalThreshold") }
    }

    var notificationsEnabled: Bool {
        get { defaults.object(forKey: "notificationsEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "notificationsEnabled") }
    }
}
