import Foundation

enum DateParsing {
    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Parses ISO-8601 with any number of fractional digits (they are dropped).
    static func parse(_ s: String) -> Date? {
        guard let dot = s.firstIndex(of: ".") else { return formatter.date(from: s) }
        var end = s.index(after: dot)
        while end < s.endIndex, s[end].isASCII, s[end].isNumber { end = s.index(after: end) }
        return formatter.date(from: String(s[..<dot]) + String(s[end...]))
    }
}
