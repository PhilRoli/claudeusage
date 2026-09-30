import Foundation

enum TokenError: Error, Equatable {
    case notFound
    case unreadable
    case expired
}

protocol TokenProviding {
    func token() throws -> OAuthToken
}

/// Reads Claude Code's credentials through /usr/bin/security rather than SecItemCopyMatching:
/// the ad-hoc signature of this app changes on every rebuild, which would invalidate a
/// Keychain "Always Allow"; the Apple-signed `security` binary is stable.
struct KeychainTokenReader: TokenProviding {
    func token() throws -> OAuthToken {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        p.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do { try p.run() } catch { throw TokenError.notFound }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw TokenError.notFound }
        return try Self.parse(data)
    }

    static func parse(_ data: Data, now: Date = Date()) throws -> OAuthToken {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any],
              let access = oauth["accessToken"] as? String, !access.isEmpty
        else { throw TokenError.unreadable }
        let expires = (oauth["expiresAt"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
        if let expires, expires <= now { throw TokenError.expired }
        return OAuthToken(accessToken: access, expiresAt: expires)
    }
}
