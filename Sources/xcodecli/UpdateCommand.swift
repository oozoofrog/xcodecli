import ArgumentParser
import Foundation
import XcodeCLICore

struct UpdateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "update",
        abstract: "Update the installed xcodecli binary"
    )

    func run() async throws {
        let result = try await Updater.run(
            currentVersion: Version.current,
            processRunner: SystemProcessRunner()
        )

        if result.alreadyUpToDate {
            print("xcodecli is already up to date (\(result.currentVersion))")
        } else {
            print("xcodecli updated from \(result.currentVersion) to \(result.targetVersion) (\(result.mode))")
        }
    }
}
