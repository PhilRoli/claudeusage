import Foundation

struct ThresholdTracker {
    private static let firedKey = "firedThresholds"
    private static let orderKey = "firedThresholdsOrder"
    private static let maxKeys = 16

    private var fired: [String: Set<Double>] = [:]
    private var order: [String] = []
    private let defaults: UserDefaults?

    /// With `defaults`, fired thresholds survive relaunches so a restart doesn't re-notify.
    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
        guard let defaults else { return }
        if let data = defaults.data(forKey: Self.firedKey),
           let stored = try? JSONDecoder().decode([String: [Double]].self, from: data) {
            fired = stored.mapValues(Set.init)
        }
        order = (defaults.array(forKey: Self.orderKey) as? [String]) ?? []
    }

    /// Stable per-window key: `resetsAt` is rounded to the nearest minute to absorb sub-second jitter.
    static func windowKey(id: String, resetsAt: Date?) -> String {
        guard let resetsAt else { return "\(id):none" }
        let minute = Int((resetsAt.timeIntervalSince1970 / 60).rounded())
        return "\(id):\(minute)"
    }

    /// Returns thresholds newly crossed for this window (ascending), each reported once per `windowKey`.
    mutating func newCrossings(windowKey: String, utilization: Double, thresholds: [Double]) -> [Double] {
        var set = fired[windowKey, default: []]
        let new = thresholds.sorted().filter { utilization >= $0 && !set.contains($0) }
        guard !new.isEmpty else { return [] }
        set.formUnion(new)
        fired[windowKey] = set
        order.removeAll { $0 == windowKey }
        order.append(windowKey)
        while order.count > Self.maxKeys {
            fired[order.removeFirst()] = nil
        }
        persist()
        return new
    }

    private func persist() {
        guard let defaults else { return }
        if let data = try? JSONEncoder().encode(fired.mapValues { $0.sorted() }) {
            defaults.set(data, forKey: Self.firedKey)
        }
        defaults.set(order, forKey: Self.orderKey)
    }
}
