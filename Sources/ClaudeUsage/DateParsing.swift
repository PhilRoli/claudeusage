import Foundation

enum DateParsing {
    /// Parses ISO-8601 with any number of fractional digits (they are dropped).
    static func parse(_ s: String) -> Date? {
        let stripped = s.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: stripped)
    }
}
