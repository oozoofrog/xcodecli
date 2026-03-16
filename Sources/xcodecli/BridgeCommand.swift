import ArgumentParser
import Foundation
import XcodeCLICore

struct BridgeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bridge",
        abstract: "Run raw STDIO passthrough to xcrun mcpbridge"
    )

    @Option(name: .customLong("xcode-pid"), help: "Override MCP_XCODE_PID")
    var xcodePID: String?

    @Option(name: .customLong("session-id"), help: "Override MCP_XCODE_SESSION_ID")
    var sessionID: String?

    @Flag(name: .customLong("debug"), help: "Emit wrapper debug logs to stderr")
    var debug = false

    func run() async throws {
        let env = envDictionary()
        let sessionPath = (try? PathUtilities.sessionFilePath()) ?? ""

        let overrides = EnvOptions(
            xcodePID: xcodePID ?? "",
            sessionID: sessionID ?? ""
        )

        let resolved = try SessionManager.resolve(
            baseEnv: env, overrides: overrides, sessionPath: sessionPath
        )

        if debug {
            logResolvedSession(resolved, to: FileHandle.standardError)
        }

        let effective = resolved.envOptions
        try effective.validate()

        let bridgeEnv = EnvOptions.applyOverrides(baseEnv: env, opts: effective)

        let result = try await runBridge(
            config: BridgeConfig(
                environment: bridgeEnv,
                debug: debug
            )
        )

        throw ExitCode(result.exitCode)
    }
}

/// Log session resolution details to stderr.
func logResolvedSession(_ resolved: ResolvedOptions, to handle: FileHandle) {
    let message: String
    switch resolved.sessionSource {
    case .explicit:
        message = "[debug] using MCP_XCODE_SESSION_ID from --session-id\n"
    case .env:
        message = "[debug] using MCP_XCODE_SESSION_ID from environment\n"
    case .persisted:
        message = "[debug] using persisted MCP_XCODE_SESSION_ID \(resolved.envOptions.sessionID) from \(resolved.sessionPath)\n"
    case .generated:
        message = "[debug] generated persistent MCP_XCODE_SESSION_ID \(resolved.envOptions.sessionID) at \(resolved.sessionPath)\n"
    case .unset:
        return
    }
    handle.write(Data(message.utf8))
}
