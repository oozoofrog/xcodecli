import Foundation

/// Configuration for running xcrun mcpbridge as a passthrough.
public struct BridgeConfig: Sendable {
    public let command: String
    public let arguments: [String]
    public let environment: [String: String]
    public let debug: Bool

    public init(
        command: String = "/usr/bin/xcrun",
        arguments: [String] = ["mcpbridge"],
        environment: [String: String] = [:],
        debug: Bool = false
    ) {
        self.command = command
        self.arguments = arguments
        self.environment = environment
        self.debug = debug
    }
}

/// Result of a bridge process execution.
public struct BridgeResult: Sendable {
    public let exitCode: Int32

    public init(exitCode: Int32) {
        self.exitCode = exitCode
    }
}

/// Runs xcrun mcpbridge as a stdin/stdout passthrough.
/// Protocol traffic flows through stdin→child→stdout.
/// Debug and diagnostic output flows through stderr.
public func runBridge(
    config: BridgeConfig,
    stdin: FileHandle = .standardInput,
    stdout: FileHandle = .standardOutput,
    stderr: FileHandle = .standardError
) async throws -> BridgeResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: config.command)
    process.arguments = config.arguments
    process.environment = config.environment

    // Pipe stdin from parent to child
    let stdinPipe = Pipe()
    process.standardInput = stdinPipe

    // Pipe child stdout to parent stdout
    let stdoutPipe = Pipe()
    process.standardOutput = stdoutPipe

    // Pipe child stderr to parent stderr
    let stderrPipe = Pipe()
    process.standardError = stderrPipe

    if config.debug {
        stderr.write(Data("[debug] spawning \(config.command) \(config.arguments.joined(separator: " "))\n".utf8))
    }

    try process.run()

    if config.debug {
        stderr.write(Data("[debug] bridge process started (pid \(process.processIdentifier))\n".utf8))
    }

    // Forward signals to child process
    let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    let sighupSource = DispatchSource.makeSignalSource(signal: SIGHUP, queue: .main)

    signal(SIGINT, SIG_IGN)
    signal(SIGTERM, SIG_IGN)
    signal(SIGHUP, SIG_IGN)

    let pid = process.processIdentifier
    for source in [sigintSource, sigtermSource, sighupSource] {
        source.setEventHandler {
            kill(pid, Int32(source.data))
        }
        source.resume()
    }

    // Copy stdin from parent to child in a background task
    let stdinTask = Task.detached {
        while true {
            let data = stdin.availableData
            if data.isEmpty { break }
            stdinPipe.fileHandleForWriting.write(data)
        }
        stdinPipe.fileHandleForWriting.closeFile()
    }

    // Copy child stdout to parent stdout
    Task.detached {
        while true {
            let data = stdoutPipe.fileHandleForReading.availableData
            if data.isEmpty { break }
            stdout.write(data)
        }
    }

    // Copy child stderr to parent stderr
    Task.detached {
        while true {
            let data = stderrPipe.fileHandleForReading.availableData
            if data.isEmpty { break }
            stderr.write(data)
        }
    }

    // Wait for process to exit
    return await withCheckedContinuation { continuation in
        process.terminationHandler = { proc in
            // Clean up signal sources
            sigintSource.cancel()
            sigtermSource.cancel()
            sighupSource.cancel()
            signal(SIGINT, SIG_DFL)
            signal(SIGTERM, SIG_DFL)
            signal(SIGHUP, SIG_DFL)

            // Cancel stdin forwarding
            stdinTask.cancel()

            continuation.resume(returning: BridgeResult(exitCode: proc.terminationStatus))
        }
    }
}
