import Foundation

@MainActor
final class UsageFetcher {
    private let tokens: TokenProviding
    private let client: LimitsFetching
    private let scanner: LocalUsageScanner
    private let now: () -> Date
    private var lastLimits: Limits?
    private var failures = 0
    private var task: Task<Void, Never>?

    var onUpdate: ((UsageSnapshot) -> Void)?
    private(set) var snapshot: UsageSnapshot

    init(tokens: TokenProviding, client: LimitsFetching, scanner: LocalUsageScanner,
         now: @escaping () -> Date = { Date() }) {
        self.tokens = tokens
        self.client = client
        self.scanner = scanner
        self.now = now
        self.snapshot = UsageSnapshot(limits: nil, status: .unavailable("Loading…"), local: .empty, updatedAt: now())
    }

    func refresh() async {
        let at = now()
        let records = await scanner.scan(now: at)
        let local = LocalStats.compute(records: records, now: at)

        var status: LimitsStatus
        do {
            lastLimits = try await loadLimits()
            failures = 0
            status = .ok
        } catch {
            failures += 1
            if lastLimits != nil {
                status = failures >= 2 ? .stale : .ok
            } else {
                status = .unavailable(Self.message(for: error))
            }
        }
        snapshot = UsageSnapshot(limits: lastLimits, status: status, local: local, updatedAt: at)
        onUpdate?(snapshot)
    }

    func start(interval: TimeInterval) {
        task?.cancel()
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func loadLimits() async throws -> Limits {
        var token = try await readToken()
        do {
            return try await client.fetchLimits(accessToken: token.accessToken)
        } catch UsageError.unauthorized {
            token = try await readToken() // Claude Code may have refreshed it meanwhile
            return try await client.fetchLimits(accessToken: token.accessToken)
        }
    }

    /// The Keychain read blocks (and can sit behind a system prompt), so keep it off the main actor.
    private func readToken() async throws -> OAuthToken {
        let provider = tokens
        return try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                cont.resume(with: Result { try provider.token() })
            }
        }
    }

    private static func message(for error: Error) -> String {
        switch error {
        case TokenError.notFound: return "Sign in to Claude Code"
        case TokenError.denied: return "Allow Keychain access"
        case TokenError.expired: return "Open Claude Code to refresh login"
        case TokenError.unreadable: return "Can't read Claude Code credentials"
        case UsageError.unauthorized: return "Claude login was rejected"
        default: return "Usage endpoint unavailable"
        }
    }
}
