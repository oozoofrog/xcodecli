import Foundation

/// Client for communicating with the xcodecli LaunchAgent via Unix socket RPC.
public enum AgentClient {
    /// List tools through the agent.
    public static func listTools(request: AgentRequest) async throws -> [JSONValue] {
        // TODO: Phase 5 - implement Unix socket RPC client
        // For now, fall back to direct MCP client
        throw XcodeCLIError.agentUnavailable(stage: "listTools", underlying: "agent not yet implemented")
    }

    /// Call a tool through the agent.
    public static func callTool(
        request: AgentRequest,
        name: String,
        arguments: [String: JSONValue]
    ) async throws -> MCPCallResult {
        throw XcodeCLIError.agentUnavailable(stage: "callTool", underlying: "agent not yet implemented")
    }

    /// Get agent status.
    public static func status() async throws -> AgentStatus {
        let plistPath = AgentPaths.plistPath()
        let socketPath = AgentPaths.socketPath()

        return AgentStatus(
            label: AgentPaths.label,
            plistPath: plistPath,
            plistInstalled: FileManager.default.fileExists(atPath: plistPath),
            socketPath: socketPath,
            socketReachable: FileManager.default.fileExists(atPath: socketPath)
        )
    }

    /// Stop the agent.
    public static func stop() async throws {
        // TODO: Phase 5 - send stop command via Unix socket
        let runner = SystemProcessRunner()
        _ = try await runner.run("/bin/launchctl", arguments: ["bootout", "gui/\(getuid())/\(AgentPaths.label)"])
    }

    /// Uninstall the agent.
    public static func uninstall() async throws {
        try? await stop()
        let fm = FileManager.default
        let plistPath = AgentPaths.plistPath()
        if fm.fileExists(atPath: plistPath) {
            try fm.removeItem(atPath: plistPath)
        }
        let socketPath = AgentPaths.socketPath()
        if fm.fileExists(atPath: socketPath) {
            try fm.removeItem(atPath: socketPath)
        }
    }
}
