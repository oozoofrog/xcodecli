import Foundation

// MARK: - Protocol Constants

public enum MCPConstants {
    public static let requestProtocolVersion = "2025-11-25"
    public static let supportedProtocolVersions = [
        "2025-11-25",
        "2025-06-18",
        "2025-03-26",
        "2024-11-05",
    ]

    public static func isSupportedVersion(_ version: String) -> Bool {
        supportedProtocolVersions.contains(version)
    }
}

// MARK: - JSON-RPC 2.0 Types

/// A raw JSON value that preserves its encoding for dynamic schemas.
public enum JSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode JSONValue")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        }
    }

    /// Convert to a Swift `Any` for interop with untyped APIs.
    public var anyValue: Any {
        switch self {
        case .null: return NSNull()
        case .bool(let v): return v
        case .int(let v): return v
        case .double(let v): return v
        case .string(let v): return v
        case .array(let v): return v.map(\.anyValue)
        case .object(let v): return v.mapValues(\.anyValue)
        }
    }

    /// Create from a Swift `Any` value.
    public static func from(_ value: Any) -> JSONValue {
        switch value {
        case is NSNull: return .null
        case let v as Bool: return .bool(v)
        case let v as Int: return .int(Int64(v))
        case let v as Int64: return .int(v)
        case let v as Double: return .double(v)
        case let v as String: return .string(v)
        case let v as [Any]: return .array(v.map { from($0) })
        case let v as [String: Any]: return .object(v.mapValues { from($0) })
        default: return .string(String(describing: value))
        }
    }
}

/// JSON-RPC 2.0 envelope used for both requests and responses.
public struct RPCEnvelope: Codable, Sendable {
    public let jsonrpc: String
    public var id: JSONValue?
    public var method: String?
    public var params: JSONValue?
    public var result: JSONValue?
    public var error: RPCError?

    public init(
        jsonrpc: String = "2.0",
        id: JSONValue? = nil,
        method: String? = nil,
        params: JSONValue? = nil,
        result: JSONValue? = nil,
        error: RPCError? = nil
    ) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.method = method
        self.params = params
        self.result = result
        self.error = error
    }

    public var hasID: Bool {
        guard let id else { return false }
        if case .null = id { return false }
        return true
    }
}

public struct RPCError: Codable, Sendable {
    public let code: Int
    public let message: String
    public var data: JSONValue?

    public init(code: Int, message: String, data: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

// MARK: - MCP Tool Types

public struct MCPTool: Codable, Sendable {
    public let name: String
    public let description: String?
    public let inputSchema: JSONValue?

    public init(name: String, description: String? = nil, inputSchema: JSONValue? = nil) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

public struct MCPCallResult: Sendable {
    public let result: [String: JSONValue]
    public let isError: Bool

    public init(result: [String: JSONValue], isError: Bool = false) {
        self.result = result
        self.isError = isError
    }
}

// MARK: - Response Builders

public func rpcSuccessResponse(id: JSONValue?, result: JSONValue) -> RPCEnvelope {
    RPCEnvelope(id: id, result: result)
}

public func rpcErrorResponse(id: JSONValue?, code: Int, message: String, data: JSONValue? = nil) -> RPCEnvelope {
    RPCEnvelope(id: id, error: RPCError(code: code, message: message, data: data))
}

// MARK: - JSON Line Encoding

public enum JSONLineCodec {
    private static let decoder = JSONDecoder()
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = .sortedKeys
        return e
    }()

    public static func decode(_ line: String) throws -> RPCEnvelope {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw XcodeCLIError.mcpRPCError(code: -32700, message: "empty message")
        }
        return try decoder.decode(RPCEnvelope.self, from: Data(trimmed.utf8))
    }

    public static func encode(_ envelope: RPCEnvelope) throws -> String {
        let data = try encoder.encode(envelope)
        return String(data: data, encoding: .utf8)! + "\n"
    }
}
