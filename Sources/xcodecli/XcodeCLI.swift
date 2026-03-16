import ArgumentParser
import XcodeCLICore

@main
struct XcodeCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "xcodecli",
        abstract: "xcodecli wraps xcrun mcpbridge for local macOS use.",
        version: Version.line,
        subcommands: [
            VersionCommand.self,
            UpdateCommand.self,
            BridgeCommand.self,
            ServeCommand.self,
            DoctorCommand.self,
            MCPCommand.self,
            ToolsCommand.self,
            ToolCommand.self,
            AgentCommand.self,
        ],
        defaultSubcommand: nil
    )
}
