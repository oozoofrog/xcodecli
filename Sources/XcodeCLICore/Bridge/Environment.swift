import Foundation

/// Environment variable keys for Xcode MCP bridge.
public enum BridgeEnvKey {
    public static let xcodePID = "MCP_XCODE_PID"
    public static let sessionID = "MCP_XCODE_SESSION_ID"
}

/// Resolved environment options for bridge communication.
public struct EnvOptions: Sendable {
    public var xcodePID: String
    public var sessionID: String

    public init(xcodePID: String = "", sessionID: String = "") {
        self.xcodePID = xcodePID
        self.sessionID = sessionID
    }

    /// Merge base environment with CLI flag overrides.
    public static func effective(baseEnv: [String: String], overrides: EnvOptions) -> EnvOptions {
        var result = EnvOptions(
            xcodePID: baseEnv[BridgeEnvKey.xcodePID] ?? "",
            sessionID: baseEnv[BridgeEnvKey.sessionID] ?? ""
        )
        if !overrides.xcodePID.isEmpty { result.xcodePID = overrides.xcodePID }
        if !overrides.sessionID.isEmpty { result.sessionID = overrides.sessionID }
        return result
    }

    /// Apply overrides to a base environment dictionary.
    public static func applyOverrides(
        baseEnv: [String: String],
        opts: EnvOptions
    ) -> [String: String] {
        var env = baseEnv
        if !opts.xcodePID.isEmpty { env[BridgeEnvKey.xcodePID] = opts.xcodePID }
        if !opts.sessionID.isEmpty { env[BridgeEnvKey.sessionID] = opts.sessionID }
        return env
    }

    /// Validate that PID is a positive integer and session ID is a UUID.
    public func validate() throws {
        if !xcodePID.isEmpty {
            _ = try Self.parsePID(xcodePID)
        }
        if !sessionID.isEmpty && !Self.isValidUUID(sessionID) {
            throw XcodeCLIError.invalidUUID(raw: sessionID)
        }
    }

    /// Parse and validate a PID string.
    public static func parsePID(_ raw: String) throws -> Int {
        guard let pid = Int(raw.trimmingCharacters(in: .whitespaces)), pid > 0 else {
            throw XcodeCLIError.invalidPID(raw: raw)
        }
        return pid
    }

    /// Check if a string is a valid UUID (RFC 4122).
    public static func isValidUUID(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let pattern = #"(?i)^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }
}
