import Foundation

public enum PathUtilities {
    /// Application Support directory for xcodecli.
    public static func applicationSupportDirectory() throws -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/Application Support/xcodecli")
    }

    /// Path to the persistent session ID file.
    public static func sessionFilePath() throws -> String {
        let dir = try applicationSupportDirectory()
        return dir.appendingPathComponent("session-id").path
    }

    /// Resolves the path to the xcrun binary via /usr/bin/xcrun.
    public static let xcrunPath = "/usr/bin/xcrun"
}
