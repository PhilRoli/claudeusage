import Foundation

@MainActor
final class UsageFetcher {
    private let tokens: TokenProviding
    private let client: LimitsFetching
    private let scanner: LocalUsageScanner
    private let now: () -> Date
    private var lastLimits: Limits?
    private var failures = 0
    private var isRefreshing = false
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
        guard !isRefreshing else { return } // timer and "Refresh now" must not overlap
        isRefreshing = true
        defer { isRefreshing = false }

        let at = now()
        async let localStats = Self.loadLocal(scanner: scanner, at: at)
        var failure: Error?
        do {
            lastLimits = try await loadLimits()
            failures = 0
        } catch {
            failure = error
        }
        let local = await localStats

        var status = LimitsStatus.ok
        if let failure {
            if Self.isCancellation(failure) { return }
            failures += 1
            let message = Self.message(for: failure)
            if lastLimits != nil {
                status = failures >= 2 ? .stale(message) : .ok
            } else {
                status = .unavailable(message)
            }
        }
        snapshot = UsageSnapshot(limits: lastLimits, status: status, local: local, updatedAt: at)
        onUpdate?(snapshot)
    }

    /// `immediate: false` keeps an in-flight refresh and just changes the cadence (used by Preferences).
    func start(interval: TimeInterval, immediate: Bool = true) {
        task?.cancel()
        task = Task { [weak self] in
            var skipSleep = immediate
            while !Task.isCancelled {
                if !skipSleep {
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    if Task.isCancelled { break }
                }
                skipSleep = false
                // Unstructured so cancelling the loop doesn't cancel a request already in flight.
                await Task { await self?.refresh() }.value
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

    nonisolated private static func loadLocal(scanner: LocalUsageScanner, at: Date) async -> LocalStats {
        let records = await scanner.scan(now: at)
        return await Task.detached { LocalStats.compute(records: records, now: at) }.value
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
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
