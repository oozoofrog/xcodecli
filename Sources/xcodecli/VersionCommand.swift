import ArgumentParser
import XcodeCLICore

struct VersionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Print the current xcodecli version"
    )

    func run() throws {
        print(Version.line)
    }
}
