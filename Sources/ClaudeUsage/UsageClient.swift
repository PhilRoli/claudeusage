import Foundation

enum UsageError: Error, Equatable {
    case unauthorized
    case http(Int)
    case decoding
}

protocol HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, Int)
}

struct URLSessionTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
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
        let (data, status) = try await transport.send(req)
        switch status {
        case 200..<300: return try Self.decode(data)
        case 401, 403: throw UsageError.unauthorized
        default: throw UsageError.http(status)
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
