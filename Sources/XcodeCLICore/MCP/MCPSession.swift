import Foundation

/// Manages an MCP client session lifecycle.
/// Encapsulates connect → use → close pattern.
public enum MCPSession {
    /// Run a closure with a connected MCP client, handling lifecycle automatically.
    public static func withClient<T: Sendable>(
        config: MCPClient.Config,
        body: @Sendable (MCPClient) async throws -> T
    ) async throws -> T {
        let client = try await MCPClient.connect(config: config)
        do {
            let result = try await body(client)
            await client.close()
            return result
        } catch {
            await client.abort()
            throw error
        }
    }

    /// List tools using a temporary client session.
    public static func listTools(config: MCPClient.Config) async throws -> [JSONValue] {
        try await withClient(config: config) { client in
            try await client.listTools()
        }
    }

    /// Call a tool using a temporary client session.
    public static func callTool(
        config: MCPClient.Config,
        name: String,
        arguments: [String: JSONValue]
    ) async throws -> MCPCallResult {
        try await withClient(config: config) { client in
            try await client.callTool(name: name, arguments: arguments)
        }
    }
}
