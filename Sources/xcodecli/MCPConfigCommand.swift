import ArgumentParser
import Foundation
import XcodeCLICore

struct MCPCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mcp",
        abstract: "Print or write MCP client configuration",
        subcommands: [
            ConfigSubcommand.self,
            CodexAlias.self,
            ClaudeAlias.self,
            GeminiAlias.self,
        ]
    )

    struct ConfigSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "config",
            abstract: "Print or write a client-specific MCP registration command"
        )

        @Option(name: .long, help: "Target client preset: claude, codex, or gemini")
        var client: String

        @Option(name: .long, help: "MCP server mode: agent or bridge")
        var mode: String = "agent"

        @Option(name: .long, help: "Registered MCP server name")
        var name: String = "xcodecli"

        @Option(name: .long, help: "Scope: local, user, or project")
        var scope: String?

        @Flag(name: .long, help: "Execute the generated registration command")
        var write = false

        @Flag(name: .long, help: "Print a machine-readable plan/result object")
        var json = false

        @Option(name: .customLong("xcode-pid"), help: "Include an explicit MCP_XCODE_PID override")
        var xcodePID: String?

        @Option(name: .customLong("session-id"), help: "Include an explicit MCP_XCODE_SESSION_ID override")
        var sessionID: String?

        func run() async throws {
            let config = try buildMCPConfig(
                client: client, mode: mode, name: name, scope: scope,
                xcodePID: xcodePID, sessionID: sessionID
            )

            if json {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(config)
                FileHandle.standardOutput.write(data)
                FileHandle.standardOutput.write(Data("\n".utf8))
            } else {
                print(config.command)
            }

            if write {
                let runner = SystemProcessRunner()
                let parts = config.command.split(separator: " ").map(String.init)
                guard let cmd = parts.first else { return }
                _ = try await runner.run(cmd, arguments: Array(parts.dropFirst()))
            }
        }
    }

    struct CodexAlias: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "codex",
            abstract: "Alias for mcp config --client codex"
        )

        @Option(name: .long, help: "MCP server mode") var mode: String = "agent"
        @Option(name: .long, help: "Server name") var name: String = "xcodecli"
        @Flag(name: .long, help: "Execute command") var write = false
        @Flag(name: .long, help: "JSON output") var json = false
        @Option(name: .customLong("xcode-pid")) var xcodePID: String?
        @Option(name: .customLong("session-id")) var sessionID: String?

        func run() async throws {
            var cmd = ConfigSubcommand()
            cmd.client = "codex"
            cmd.mode = mode
            cmd.name = name
            cmd.write = write
            cmd.json = json
            cmd.xcodePID = xcodePID
            cmd.sessionID = sessionID
            try await cmd.run()
        }
    }

    struct ClaudeAlias: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "claude",
            abstract: "Alias for mcp config --client claude"
        )

        @Option(name: .long, help: "MCP server mode") var mode: String = "agent"
        @Option(name: .long, help: "Server name") var name: String = "xcodecli"
        @Option(name: .long, help: "Scope") var scope: String?
        @Flag(name: .long, help: "Execute command") var write = false
        @Flag(name: .long, help: "JSON output") var json = false
        @Option(name: .customLong("xcode-pid")) var xcodePID: String?
        @Option(name: .customLong("session-id")) var sessionID: String?

        func run() async throws {
            var cmd = ConfigSubcommand()
            cmd.client = "claude"
            cmd.mode = mode
            cmd.name = name
            cmd.scope = scope
            cmd.write = write
            cmd.json = json
            cmd.xcodePID = xcodePID
            cmd.sessionID = sessionID
            try await cmd.run()
        }
    }

    struct GeminiAlias: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "gemini",
            abstract: "Alias for mcp config --client gemini"
        )

        @Option(name: .long, help: "MCP server mode") var mode: String = "agent"
        @Option(name: .long, help: "Server name") var name: String = "xcodecli"
        @Option(name: .long, help: "Scope") var scope: String?
        @Flag(name: .long, help: "Execute command") var write = false
        @Flag(name: .long, help: "JSON output") var json = false
        @Option(name: .customLong("xcode-pid")) var xcodePID: String?
        @Option(name: .customLong("session-id")) var sessionID: String?

        func run() async throws {
            var cmd = ConfigSubcommand()
            cmd.client = "gemini"
            cmd.mode = mode
            cmd.name = name
            cmd.scope = scope
            cmd.write = write
            cmd.json = json
            cmd.xcodePID = xcodePID
            cmd.sessionID = sessionID
            try await cmd.run()
        }
    }
}

// MARK: - MCP Config Generation

struct MCPConfigResult: Codable {
    let client: String
    let mode: String
    let name: String
    let command: String
    let scope: String?
}

func buildMCPConfig(
    client: String, mode: String, name: String, scope: String?,
    xcodePID: String?, sessionID: String?
) throws -> MCPConfigResult {
    let xcodecliPath = "/usr/local/bin/xcodecli"
    let subcommand = mode == "bridge" ? "bridge" : "serve"

    var args = [xcodecliPath, subcommand]
    if let pid = xcodePID, !pid.isEmpty {
        args += ["--xcode-pid", pid]
    }
    if let sid = sessionID, !sid.isEmpty {
        args += ["--session-id", sid]
    }

    let command: String
    let resolvedScope: String?

    switch client.lowercased() {
    case "codex":
        command = "codex mcp add \(name) -- \(args.joined(separator: " "))"
        resolvedScope = nil
    case "claude":
        let s = scope ?? "local"
        command = "claude mcp add \(name) --scope \(s) -- \(args.joined(separator: " "))"
        resolvedScope = s
    case "gemini":
        let s = scope ?? "user"
        command = "gemini mcp add \(name) --scope \(s) -- \(args.joined(separator: " "))"
        resolvedScope = s
    default:
        throw ValidationError("unsupported client: \(client)")
    }

    return MCPConfigResult(
        client: client, mode: mode, name: name, command: command, scope: resolvedScope
    )
}
