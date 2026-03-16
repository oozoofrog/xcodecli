import Foundation

public enum AgentPaths {
    public static let label = "io.oozoofrog.xcodecli"

    public static func plistPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/LaunchAgents/\(label).plist").path
    }

    public static func socketPath() -> String {
        let tmpDir = NSTemporaryDirectory()
        return (tmpDir as NSString).appendingPathComponent("\(label).sock")
    }

    public static func runtimeDirectory() throws -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/Application Support/xcodecli")
    }
}
