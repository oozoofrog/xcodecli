import Foundation

/// Configuration for the MCP stdio server.
public struct MCPServerConfig: Sendable {
    public let serverName: String
    public let serverVersion: String
    public let debug: Bool

    public init(
        serverName: String = "xcodecli",
        serverVersion: String = Version.current,
        debug: Bool = false
    ) {
        self.serverName = serverName
        self.serverVersion = serverVersion
        self.debug = debug
    }
}

/// Handler callbacks for the MCP server.
public struct MCPServerHandler: Sendable {
    public let listTools: @Sendable () async throws -> [JSONValue]
    public let callTool: @Sendable (String, [String: JSONValue]) async throws -> MCPCallResult

    public init(
        listTools: @escaping @Sendable () async throws -> [JSONValue],
        callTool: @escaping @Sendable (String, [String: JSONValue]) async throws -> MCPCallResult
    ) {
        self.listTools = listTools
        self.callTool = callTool
    }
}

/// Run an MCP stdio server reading from stdin and writing to stdout.
public func serveMCPStdio(
    config: MCPServerConfig,
    handler: MCPServerHandler,
    stdin: FileHandle = .standardInput,
    stdout: FileHandle = .standardOutput,
    stderr: FileHandle = .standardError
) async throws {
    let writer = MCPResponseWriter(handle: stdout, debug: config.debug, errOut: stderr)

    // Read lines from stdin
    var lineData = Data()
    while true {
        let byte = stdin.readData(ofLength: 1)
        if byte.isEmpty {
            // stdin closed - exit gracefully
            return
        }
        if byte[0] == UInt8(ascii: "\n") {
            if let line = String(data: lineData, encoding: .utf8) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    if config.debug {
                        stderr.write(Data("[debug] mcp serve recv <- \(trimmed)\n".utf8))
                    }
                    do {
                        let envelope = try JSONLineCodec.decode(trimmed)
                        try await handleServerEnvelope(
                            envelope: envelope,
                            config: config,
                            handler: handler,
                            writer: writer
                        )
                    } catch {
                        if config.debug {
                            stderr.write(Data("[debug] mcp serve error: \(error)\n".utf8))
                        }
                        return
                    }
                }
            }
            lineData = Data()
        } else {
            lineData.append(byte)
        }
    }
}

/// Handle a single MCP envelope.
private func handleServerEnvelope(
    envelope: RPCEnvelope,
    config: MCPServerConfig,
    handler: MCPServerHandler,
    writer: MCPResponseWriter
) async throws {
    // If no method, it's a response (we don't expect those as server)
    guard let method = envelope.method, !method.isEmpty else {
        return
    }

    // Notification (no id)
    guard envelope.hasID else {
        // Silently ignore notifications
        return
    }

    switch method {
    case "initialize":
        let response = buildInitializeResponse(envelope: envelope, config: config)
        try writer.write(response)

    case "ping":
        try writer.write(rpcSuccessResponse(id: envelope.id, result: .object([:])))

    case "tools/list":
        do {
            let tools = try await handler.listTools()
            try writer.write(rpcSuccessResponse(
                id: envelope.id,
                result: .object(["tools": .array(tools)])
            ))
        } catch {
            try writer.write(rpcErrorResponse(id: envelope.id, code: -32603, message: error.localizedDescription))
        }

    case "tools/call":
        do {
            let (name, arguments) = try decodeToolCallParams(envelope.params)
            let result = try await handler.callTool(name, arguments)
            var payload = result.result
            if result.isError {
                payload["isError"] = .bool(true)
            }
            try writer.write(rpcSuccessResponse(id: envelope.id, result: .object(payload)))
        } catch {
            try writer.write(rpcErrorResponse(id: envelope.id, code: -32602, message: error.localizedDescription))
        }

    default:
        try writer.write(rpcErrorResponse(id: envelope.id, code: -32601, message: "Method not found"))
    }
}

private func buildInitializeResponse(envelope: RPCEnvelope, config: MCPServerConfig) -> RPCEnvelope {
    // Extract protocol version from params
    var requestedVersion = MCPConstants.requestProtocolVersion
    if case .object(let params) = envelope.params,
       case .string(let version) = params["protocolVersion"] {
        requestedVersion = version
    }

    guard MCPConstants.isSupportedVersion(requestedVersion) else {
        return rpcErrorResponse(
            id: envelope.id, code: -32602,
            message: "Unsupported protocol version",
            data: .object([
                "requested": .string(requestedVersion),
                "supported": .array(MCPConstants.supportedProtocolVersions.map { .string($0) }),
            ])
        )
    }

    return rpcSuccessResponse(id: envelope.id, result: .object([
        "protocolVersion": .string(requestedVersion),
        "capabilities": .object(["tools": .object([:])]),
        "serverInfo": .object([
            "name": .string(config.serverName),
            "version": .string(config.serverVersion),
        ]),
    ]))
}

private func decodeToolCallParams(_ params: JSONValue?) throws -> (String, [String: JSONValue]) {
    guard case .object(let obj) = params else {
        throw XcodeCLIError.mcpRPCError(code: -32602, message: "tools/call params must be a JSON object")
    }
    guard case .string(let name) = obj["name"], !name.trimmingCharacters(in: .whitespaces).isEmpty else {
        throw XcodeCLIError.mcpRPCError(code: -32602, message: "tools/call params require a non-empty name")
    }
    var arguments: [String: JSONValue] = [:]
    if case .object(let args) = obj["arguments"] {
        arguments = args
    }
    return (name, arguments)
}

/// Thread-safe response writer for MCP stdout.
final class MCPResponseWriter: Sendable {
    private let handle: FileHandle
    private let debug: Bool
    private let errOut: FileHandle
    private let lock = NSLock()

    init(handle: FileHandle, debug: Bool, errOut: FileHandle) {
        self.handle = handle
        self.debug = debug
        self.errOut = errOut
    }

    func write(_ envelope: RPCEnvelope) throws {
        let line = try JSONLineCodec.encode(envelope)
        if debug {
            errOut.write(Data("[debug] mcp serve send -> \(line.trimmingCharacters(in: .whitespacesAndNewlines))\n".utf8))
        }
        lock.withLock {
            handle.write(Data(line.utf8))
        }
    }
}
