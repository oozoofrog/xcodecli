import ArgumentParser
import Foundation
import XcodeCLICore

struct AgentCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agent",
        abstract: "Inspect or manage the LaunchAgent used by tools commands",
        subcommands: [
            StatusSubcommand.self,
            StopSubcommand.self,
            UninstallSubcommand.self,
        ]
    )

    struct StatusSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "status",
            abstract: "Show LaunchAgent installation and runtime state"
        )

        @Flag(name: .long, help: "Print as pretty JSON")
        var json = false

        func run() async throws {
            let status = try await AgentClient.status()

            if json {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(status)
                FileHandle.standardOutput.write(data)
                FileHandle.standardOutput.write(Data("\n".utf8))
            } else {
                print(formatAgentStatus(status))
            }
        }
    }

    struct StopSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "stop",
            abstract: "Ask the running LaunchAgent process to stop"
        )

        func run() async throws {
            try await AgentClient.stop()
            print("stopped LaunchAgent process if it was running")
        }
    }

    struct UninstallSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "uninstall",
            abstract: "Remove the LaunchAgent plist and local agent runtime files"
        )

        func run() async throws {
            try await AgentClient.uninstall()
            print("removed LaunchAgent plist and local agent runtime files")
        }
    }
}

func formatAgentStatus(_ status: AgentStatus) -> String {
    let binaryLine = status.registeredBinary.isEmpty ? "not installed" : status.registeredBinary
    let matchText: String
    if !status.registeredBinary.isEmpty && !status.currentBinary.isEmpty {
        matchText = status.binaryPathMatches ? "yes" : "no"
    } else {
        matchText = "n/a"
    }
    let runningText = status.running ? "yes" : "no"
    let socketText = status.socketReachable ? "yes" : "no"

    return """
    xcodecli agent

    label: \(status.label)
    plist installed: \(status.plistInstalled)
    plist path: \(status.plistPath)
    registered binary: \(binaryLine)
    current binary: \(status.currentBinary)
    binary matches: \(matchText)
    socket path: \(status.socketPath)
    socket reachable: \(socketText)
    running: \(runningText)
    pid: \(status.pid)
    backend sessions: \(status.backendSessions)
    """
}
