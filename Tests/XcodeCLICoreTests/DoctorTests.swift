import Testing
import Foundation
@testable import XcodeCLICore

// MARK: - Mock Process Runner

struct MockProcessRunner: ProcessRunning {
    var results: [String: ProcessResult] = [:]
    var defaultResult = ProcessResult(stdout: "", stderr: "", exitCode: 0)

    func run(
        _ command: String,
        arguments: [String],
        environment: [String: String]?,
        workingDirectory: String?,
        stdinData: Data?
    ) async throws -> ProcessResult {
        let key = ([command] + arguments).joined(separator: " ")
        return results[key] ?? defaultResult
    }
}

@Suite("Doctor")
struct DoctorTests {
    @Test("report with all checks OK is successful")
    func successfulReport() {
        let checks = [
            DoctorCheck(name: "test1", status: .ok, detail: "good"),
            DoctorCheck(name: "test2", status: .info, detail: "fyi"),
        ]
        let report = DoctorReport(checks: checks)
        #expect(report.isSuccess)
    }

    @Test("report with a fail check is not successful")
    func failedReport() {
        let checks = [
            DoctorCheck(name: "test1", status: .ok, detail: "good"),
            DoctorCheck(name: "test2", status: .fail, detail: "bad"),
        ]
        let report = DoctorReport(checks: checks)
        #expect(!report.isSuccess)
    }

    @Test("summary counts statuses correctly")
    func summaryCounts() {
        let checks = [
            DoctorCheck(name: "a", status: .ok, detail: ""),
            DoctorCheck(name: "b", status: .ok, detail: ""),
            DoctorCheck(name: "c", status: .warn, detail: ""),
            DoctorCheck(name: "d", status: .fail, detail: ""),
            DoctorCheck(name: "e", status: .info, detail: ""),
            DoctorCheck(name: "f", status: .info, detail: ""),
        ]
        let report = DoctorReport(checks: checks)
        let s = report.summary
        #expect(s.ok == 2)
        #expect(s.warn == 1)
        #expect(s.fail == 1)
        #expect(s.info == 2)
    }

    @Test("text report includes status icons")
    func textReportFormat() {
        let checks = [
            DoctorCheck(name: "xcrun lookup", status: .ok, detail: "/usr/bin/xcrun"),
        ]
        let report = DoctorReport(checks: checks)
        let text = report.textReport
        #expect(text.contains("[OK] xcrun lookup: /usr/bin/xcrun"))
        #expect(text.contains("xcodecli doctor"))
    }

    @Test("JSON report encodes correctly")
    func jsonReportEncoding() throws {
        let checks = [
            DoctorCheck(name: "test", status: .ok, detail: "fine"),
        ]
        let report = DoctorReport(checks: checks)
        let encoder = JSONEncoder()
        let data = try encoder.encode(report.jsonReport)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"success\":true"))
        #expect(json.contains("\"ok\":1"))
    }

    @Test("inspector handles xcrun not found")
    func xcrunNotFound() async {
        let runner = MockProcessRunner()
        let inspector = DoctorInspector(
            processRunner: runner,
            lookPath: { _ in nil },
            listProcesses: { [] }
        )
        let report = await inspector.run(opts: DoctorOptions())
        let xcrunCheck = report.checks.first { $0.name == "xcrun lookup" }
        #expect(xcrunCheck?.status == .fail)
    }

    @Test("inspector skips mcpbridge check when xcrun unavailable")
    func mcpbridgeSkippedWithoutXcrun() async {
        let runner = MockProcessRunner()
        let inspector = DoctorInspector(
            processRunner: runner,
            lookPath: { _ in nil },
            listProcesses: { [] }
        )
        let report = await inspector.run(opts: DoctorOptions())
        let bridgeCheck = report.checks.first { $0.name == "xcrun mcpbridge --help" }
        #expect(bridgeCheck?.status == .info)
        #expect(bridgeCheck?.detail.contains("skipped") == true)
    }
}
