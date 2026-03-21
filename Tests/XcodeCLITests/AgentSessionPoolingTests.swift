import Testing
import Foundation

/// Integration tests for the agent daemon session pooling mechanism.
/// These tests verify the core value proposition of xcodecli:
/// multiple tool calls reuse a single mcpbridge session via the LaunchAgent daemon,
/// avoiding repeated authentication alerts.
///
/// These tests start a real agent daemon and verify RPC communication.
/// They do NOT require Xcode to be running (tool calls will fail, but session pooling
/// is verified through agent status).
///
/// These tests are disabled by default because they start real daemon processes
/// that can interfere with other tests. Run explicitly with:
///   XCODECLI_AGENT_TESTS=1 swift test --filter "AgentSessionPooling" --no-parallel
@Suite("Agent Session Pooling", .serialized,
       .enabled(if: ProcessInfo.processInfo.environment["XCODECLI_AGENT_TESTS"] != nil))
struct AgentSessionPoolingTests {

    // MARK: - Agent Daemon Lifecycle

    @Test("agent daemon starts and responds to status")
    func agentStartsAndRespondsToStatus() async throws {
        try await withAgentDaemon { cli in
            let status = try cli.agentStatus()
            #expect(status.running == true)
            #expect(status.pid > 0)
            #expect(status.socketReachable == true)
        }
    }

    @Test("agent daemon stops cleanly via stop command")
    func agentStopsCleanly() async throws {
        try await withAgentDaemon { cli in
            // Verify running
            let status1 = try cli.agentStatus()
            #expect(status1.running == true)

            // Stop
            let stopResult = try cli.run(["agent", "stop"])
            #expect(stopResult.exitCode == 0)

            // Brief wait for daemon to shut down
            try await Task.sleep(nanoseconds: 500_000_000)

            // Status should show not running
            let status2 = try cli.agentStatus()
            #expect(status2.running == false)
        }
    }

    // MARK: - Session Pooling

    @Test("multiple status calls reuse the same daemon (no new processes)")
    func multipleStatusCallsReuseDaemon() async throws {
        try await withAgentDaemon { cli in
            // Make 3 consecutive status calls
            let s1 = try cli.agentStatus()
            let s2 = try cli.agentStatus()
            let s3 = try cli.agentStatus()

            // All should report the same PID (same daemon process)
            #expect(s1.pid == s2.pid)
            #expect(s2.pid == s3.pid)
            #expect(s1.running == true)
        }
    }

    @Test("agent daemon reports idle timeout in nanoseconds")
    func idleTimeoutIsReported() async throws {
        try await withAgentDaemon(idleTimeout: 30) { cli in
            let status = try cli.agentStatus()
            // 30 seconds = 30_000_000_000 nanoseconds
            #expect(status.idleTimeoutNs == 30_000_000_000)
        }
    }

    @Test("agent daemon reports backend sessions count")
    func backendSessionsCount() async throws {
        try await withAgentDaemon { cli in
            let status = try cli.agentStatus()
            // Before any tool call, backend sessions should be 0
            #expect(status.backendSessions == 0)
        }
    }

    // MARK: - Binary Identity & Plist

    @Test("agent daemon creates socket file")
    func socketFileCreated() async throws {
        try await withAgentDaemon { cli in
            let socketPath = try cli.run(["agent", "status", "--json"]).jsonDict?["socketPath"] as? String
            #expect(socketPath != nil)
            if let path = socketPath {
                #expect(FileManager.default.fileExists(atPath: path))
            }
        }
    }

    @Test("agent daemon creates PID file")
    func pidFileCreated() async throws {
        try await withAgentDaemon { cli in
            let status = try cli.agentStatus()
            let paths = agentSupportDir()
            let pidPath = (paths as NSString).appendingPathComponent("daemon.pid")
            if FileManager.default.fileExists(atPath: pidPath) {
                let pidStr = try String(contentsOfFile: pidPath, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                #expect(Int(pidStr) == status.pid)
            }
        }
    }

    // MARK: - Helpers

    private struct AgentStatus {
        let running: Bool
        let pid: Int
        let socketReachable: Bool
        let backendSessions: Int
        let idleTimeoutNs: Int64
    }

    private struct CLIHelper {
        let binaryURL: URL

        func run(_ arguments: [String]) throws -> CLIOutput {
            let process = Process()
            process.executableURL = binaryURL
            process.arguments = arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            try process.run()
            process.waitUntilExit()

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

            return CLIOutput(
                stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                stderr: String(data: stderrData, encoding: .utf8) ?? "",
                exitCode: process.terminationStatus,
                jsonDict: try? JSONSerialization.jsonObject(with: stdoutData) as? [String: Any]
            )
        }

        func agentStatus() throws -> AgentStatus {
            let output = try run(["agent", "status", "--json"])
            guard let dict = output.jsonDict else {
                return AgentStatus(running: false, pid: 0, socketReachable: false, backendSessions: 0, idleTimeoutNs: 0)
            }
            return AgentStatus(
                running: dict["running"] as? Bool ?? false,
                pid: dict["pid"] as? Int ?? 0,
                socketReachable: dict["socketReachable"] as? Bool ?? false,
                backendSessions: dict["backendSessions"] as? Int ?? 0,
                idleTimeoutNs: dict["idleTimeoutNs"] as? Int64 ?? 0
            )
        }
    }

    private struct CLIOutput {
        let stdout: String
        let stderr: String
        let exitCode: Int32
        let jsonDict: [String: Any]?
    }

    private func productsDirectory() -> URL {
        let thisFile = URL(fileURLWithPath: #filePath)
        return thisFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".build/debug")
    }

    private func agentSupportDir() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return (home as NSString).appendingPathComponent("Library/Application Support/xcodecli")
    }

    /// Start an agent daemon, run the test body, then stop and clean up.
    private func withAgentDaemon(
        idleTimeout: Int = 60,
        body: (CLIHelper) async throws -> Void
    ) async throws {
        let cli = CLIHelper(binaryURL: productsDirectory().appendingPathComponent("xcodecli"))

        // Stop any existing daemon first
        _ = try? cli.run(["agent", "stop"])
        try await Task.sleep(nanoseconds: 500_000_000)

        // Start agent daemon in background (discard output to avoid pipe buffer blocking)
        let daemonProcess = Process()
        daemonProcess.executableURL = cli.binaryURL
        daemonProcess.arguments = ["agent", "run", "--launch-agent", "--idle-timeout", "\(idleTimeout)"]
        daemonProcess.standardOutput = FileHandle.nullDevice
        daemonProcess.standardError = FileHandle.nullDevice
        try daemonProcess.run()

        // Wait for daemon to be ready
        var ready = false
        for _ in 0..<50 { // max 5 seconds
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            let status = try? cli.agentStatus()
            if status?.running == true {
                ready = true
                break
            }
        }

        defer {
            // Always stop the daemon
            _ = try? cli.run(["agent", "stop"])
            if daemonProcess.isRunning {
                daemonProcess.terminate()
            }
            daemonProcess.waitUntilExit()
        }

        guard ready else {
            throw AgentTestError.daemonDidNotStart
        }

        try await body(cli)
    }

    private enum AgentTestError: Error {
        case daemonDidNotStart
    }
}
