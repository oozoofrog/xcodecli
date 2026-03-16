import Foundation
import XcodeCLICore

/// Minimal stdin↔stdout passthrough for bridge mode.
/// This target has minimal dependencies to keep the bridge path lightweight.
public enum StdioBridge {
    /// Run xcrun mcpbridge as a raw stdin/stdout passthrough.
    public static func run(
        processRunner: some ProcessRunning,
        environment: [String: String],
        debug: Bool
    ) async throws -> Int32 {
        // Placeholder: will be implemented in Phase 3
        fatalError("StdioBridge.run not yet implemented")
    }
}
