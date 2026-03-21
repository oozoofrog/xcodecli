import Foundation

/// Manages a pool of MCP sessions keyed by session ID.
/// Each session wraps an xcrun mcpbridge process with initialized MCP handshake.
public actor SessionPool {
    private var sessions: [String: MCPClient] = [:]
    private let config: MCPClient.Config
    private let idleTimeout: TimeInterval

    public init(config: MCPClient.Config, idleTimeout: TimeInterval = defaultAgentIdleTimeout) {
        self.config = config
        self.idleTimeout = idleTimeout
    }

    /// Get or create a session for the given key.
    public func session(for key: String) async throws -> MCPClient {
        if let existing = sessions[key] {
            return existing
        }
        let client = try await MCPClient.connect(config: config)
        sessions[key] = client
        return client
    }

    /// Remove and close a session.
    public func remove(key: String) async {
        if let client = sessions.removeValue(forKey: key) {
            await client.close()
        }
    }

    /// Close all sessions.
    public func closeAll() async {
        for (_, client) in sessions {
            await client.close()
        }
        sessions.removeAll()
    }

    /// Number of active sessions.
    public var count: Int { sessions.count }
}
