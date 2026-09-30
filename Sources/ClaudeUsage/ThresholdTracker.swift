import Foundation

struct ThresholdTracker {
    private var fired: [String: Set<Double>] = [:]

    /// Returns thresholds newly crossed for this window (ascending), each reported once per `windowKey`.
    mutating func newCrossings(windowKey: String, utilization: Double, thresholds: [Double]) -> [Double] {
        var set = fired[windowKey, default: []]
        let new = thresholds.sorted().filter { utilization >= $0 && !set.contains($0) }
        set.formUnion(new)
        fired[windowKey] = set
        return new
    }
}
