import Foundation

enum UsageError: Error, Equatable {
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case http(Int)
    case decoding
}

protocol HTTPTransport {
    func send(_ request: URLRequest) async throws -> HTTPResult
}

struct HTTPResult {
    var data: Data
    var status: Int
    var retryAfter: TimeInterval?
}

struct URLSessionTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> HTTPResult {
        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as? HTTPURLResponse
        let retryAfter = http?.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
        return HTTPResult(data: data, status: http?.statusCode ?? 0, retryAfter: retryAfter)
    }
}

protocol LimitsFetching {
    func fetchLimits(accessToken: String) async throws -> Limits
}

struct UsageClient: LimitsFetching {
    static let url = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    var transport: HTTPTransport = URLSessionTransport()

    func fetchLimits(accessToken: String) async throws -> Limits {
        var req = URLRequest(url: Self.url)
        req.timeoutInterval = 15
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        let result = try await transport.send(req)
        switch result.status {
        case 200..<300: return try Self.decode(result.data)
        case 401, 403: throw UsageError.unauthorized
        case 429: throw UsageError.rateLimited(retryAfter: result.retryAfter)
        default: throw UsageError.http(result.status)
        }
    }

    static func decode(_ data: Data) throws -> Limits {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw UsageError.decoding
        }
        func window(_ key: String) -> LimitWindow? {
            guard let d = root[key] as? [String: Any], let u = (d["utilization"] as? NSNumber)?.doubleValue else {
                return nil
            }
            return LimitWindow(utilization: u, resetsAt: (d["resets_at"] as? String).flatMap(DateParsing.parse))
        }
        let limits = Limits(fiveHour: window("five_hour"), sevenDay: window("seven_day"))
        if limits.fiveHour == nil && limits.sevenDay == nil { throw UsageError.decoding }
        return limits
    }
}
