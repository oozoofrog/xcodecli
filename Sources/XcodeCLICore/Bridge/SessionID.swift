import Foundation

/// Session source tracking — where the session ID came from.
public enum SessionSource: String, Sendable, Codable {
    case unset = "unset"
    case explicit = "explicit"       // from --session-id
    case env = "env"                 // from MCP_XCODE_SESSION_ID env var
    case persisted = "persisted"     // loaded from file
    case generated = "generated"     // newly created and saved
}

/// Resolved session options including source tracking.
public struct ResolvedOptions: Sendable {
    public var envOptions: EnvOptions
    public var sessionSource: SessionSource
    public var sessionPath: String

    public init(envOptions: EnvOptions = EnvOptions(), sessionSource: SessionSource = .unset, sessionPath: String = "") {
        self.envOptions = envOptions
        self.sessionSource = sessionSource
        self.sessionPath = sessionPath
    }
}

public enum SessionManager {
    /// Resolve the effective session options from environment and overrides.
    public static func resolve(
        baseEnv: [String: String],
        overrides: EnvOptions,
        sessionPath: String
    ) throws -> ResolvedOptions {
        let effective = EnvOptions.effective(baseEnv: baseEnv, overrides: overrides)
        var resolved = ResolvedOptions(envOptions: effective)

        if !overrides.sessionID.isEmpty {
            resolved.sessionSource = .explicit
        } else if let envSession = baseEnv[BridgeEnvKey.sessionID], !envSession.isEmpty {
            resolved.sessionSource = .env
        } else {
            guard !sessionPath.isEmpty else {
                throw XcodeCLIError.missingSessionPath
            }
            let (sessionID, source) = try loadOrCreateSessionID(path: sessionPath)
            resolved.envOptions.sessionID = sessionID
            resolved.sessionSource = source
            resolved.sessionPath = sessionPath
        }

        if resolved.sessionSource == .unset {
            resolved.sessionSource = .unset
        }

        return resolved
    }

    /// Generate a new UUID v4 string.
    public static func newUUID() -> String {
        UUID().uuidString.lowercased()
    }

    // MARK: - Private

    private static func loadOrCreateSessionID(path: String) throws -> (String, SessionSource) {
        let fileManager = FileManager.default

        if let data = fileManager.contents(atPath: path),
           let content = String(data: data, encoding: .utf8) {
            let sessionID = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if EnvOptions.isValidUUID(sessionID) {
                return (sessionID, .persisted)
            }
        }

        let sessionID = newUUID()
        let dir = (path as NSString).deletingLastPathComponent
        try fileManager.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try (sessionID + "\n").write(toFile: path, atomically: true, encoding: .utf8)
        return (sessionID, .generated)
    }
}
