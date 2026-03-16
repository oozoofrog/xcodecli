import Testing
import Foundation
@testable import XcodeCLICore

@Suite("MCP Protocol")
struct MCPProtocolTests {
    @Test("JSONValue encodes and decodes null")
    func jsonValueNull() throws {
        let value = JSONValue.null
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(decoded == .null)
    }

    @Test("JSONValue encodes and decodes nested object")
    func jsonValueNestedObject() throws {
        let value = JSONValue.object([
            "name": .string("test"),
            "count": .int(42),
            "nested": .object(["flag": .bool(true)]),
        ])
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(decoded == value)
    }

    @Test("RPCEnvelope round-trips through JSON")
    func envelopeRoundTrip() throws {
        let original = RPCEnvelope(
            id: .int(1),
            method: "tools/list",
            params: .object([:])
        )
        let line = try JSONLineCodec.encode(original)
        let decoded = try JSONLineCodec.decode(line)
        #expect(decoded.method == "tools/list")
        #expect(decoded.id == .int(1))
    }

    @Test("RPCEnvelope hasID is true for integer id")
    func envelopeHasIDInteger() {
        let env = RPCEnvelope(id: .int(1))
        #expect(env.hasID)
    }

    @Test("RPCEnvelope hasID is false for null id")
    func envelopeHasIDNull() {
        let env = RPCEnvelope(id: .null)
        #expect(!env.hasID)
    }

    @Test("RPCEnvelope hasID is false for nil id")
    func envelopeHasIDNil() {
        let env = RPCEnvelope()
        #expect(!env.hasID)
    }

    @Test("supported protocol versions include 2025-11-25")
    func supportedVersions() {
        #expect(MCPConstants.isSupportedVersion("2025-11-25"))
        #expect(MCPConstants.isSupportedVersion("2024-11-05"))
        #expect(!MCPConstants.isSupportedVersion("1999-01-01"))
    }

    @Test("success response has correct structure")
    func successResponse() throws {
        let response = rpcSuccessResponse(
            id: .int(1),
            result: .object(["tools": .array([])])
        )
        #expect(response.id == .int(1))
        #expect(response.error == nil)
        #expect(response.result != nil)
    }

    @Test("error response has correct structure")
    func errorResponse() throws {
        let response = rpcErrorResponse(
            id: .int(1), code: -32601, message: "Method not found"
        )
        #expect(response.error?.code == -32601)
        #expect(response.error?.message == "Method not found")
    }

    @Test("JSONLineCodec rejects empty line")
    func emptyLineDecoding() {
        #expect(throws: (any Error).self) {
            _ = try JSONLineCodec.decode("")
        }
    }
}
