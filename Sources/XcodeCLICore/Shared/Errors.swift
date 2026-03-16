import Foundation

public enum XcodeCLIError: LocalizedError, Sendable {
    case bridgeNotFound(path: String)
    case bridgeSpawnFailed(underlying: String)
    case mcpInitializationFailed(reason: String)
    case mcpUnsupportedProtocol(version: String)
    case mcpRPCError(code: Int, message: String)
    case agentUnavailable(stage: String, underlying: String)
    case agentTimeout(action: String, budgetMS: Int64)
    case agentServerResponse(message: String)
    case homebrewNotFound
    case invalidPID(raw: String)
    case invalidUUID(raw: String)
    case missingSessionPath

    public var errorDescription: String? {
        switch self {
        case .bridgeNotFound(let path):
            return "xcrun mcpbridge not found at \(path)"
        case .bridgeSpawnFailed(let underlying):
            return "failed to spawn xcrun mcpbridge: \(underlying)"
        case .mcpInitializationFailed(let reason):
            return "MCP initialization failed: \(reason)"
        case .mcpUnsupportedProtocol(let version):
            return "unsupported MCP protocol version: \(version)"
        case .mcpRPCError(let code, let message):
            return "MCP RPC error \(code): \(message)"
        case .agentUnavailable(let stage, let underlying):
            return "agent unavailable during \(stage): \(underlying)"
        case .agentTimeout(let action, let budgetMS):
            return "agent timeout on \(action) after \(budgetMS)ms"
        case .agentServerResponse(let message):
            return "agent server error: \(message)"
        case .homebrewNotFound:
            return "Homebrew (brew) not found on PATH"
        case .invalidPID(let raw):
            return "MCP_XCODE_PID must be a positive integer, got: \(raw)"
        case .invalidUUID(let raw):
            return "MCP_XCODE_SESSION_ID must be a UUID, got: \(raw)"
        case .missingSessionPath:
            return "missing persistent session path"
        }
    }
}
