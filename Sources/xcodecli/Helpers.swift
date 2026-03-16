import Foundation
import XcodeCLICore

/// Resolve bridge options from environment and CLI flags.
func resolveOptions(
    env: [String: String],
    xcodePID: String?,
    sessionID: String?
) throws -> (EnvOptions, ResolvedOptions) {
    let sessionPath = (try? PathUtilities.sessionFilePath()) ?? ""
    let overrides = EnvOptions(
        xcodePID: xcodePID ?? "",
        sessionID: sessionID ?? ""
    )
    let resolved = try SessionManager.resolve(
        baseEnv: env, overrides: overrides, sessionPath: sessionPath
    )
    let effective = resolved.envOptions
    try effective.validate()
    return (effective, resolved)
}
