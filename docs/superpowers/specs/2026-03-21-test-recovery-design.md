# Test Recovery Design: Go → Swift 전체 포팅 + Swift 특화

## Context

xcodecli의 Go→Swift 전환 후 테스트 커버리지가 ~199개(Go, subprocess helper 제외)에서 24개(Swift)로 감소. Go 동작 테스트를 Swift로 포팅하고 Swift 특화 테스트를 추가하여 총 ~220개로 회복한다.

## Approach

하이브리드(C): Go 테스트 1:1 직역 + Swift 특화 추가(async race, Sendable, ContinuousClock timeout).

## Access Control Strategy

`@testable import XcodeCLICore`를 사용하여 `internal` 타입에 접근. `private` 타입(`InFlightTracker`, `readLaunchAgentBinaryPathFromString`, `xmlEscape` 등)은 `internal`로 승격하여 직접 테스트 가능하게 한다. 최소한의 변경: `private` → 접근 제한자 제거(default internal).

## Test File Structure

```
Tests/
├── XcodeCLICoreTests/
│   ├── DoctorTests.swift            (기존, 7 tests)
│   ├── MCPProtocolTests.swift       (기존, 10 tests)
│   ├── VersionTests.swift           (기존, 5 tests)
│   ├── AgentPathsTests.swift        (신규, 5 tests)
│   ├── AgentServerTests.swift       (신규, 20 tests)
│   ├── AgentClientTests.swift       (신규, 8 tests)
│   ├── MCPClientTests.swift         (신규, 8 tests)
│   ├── MCPServerTests.swift         (신규, 10 tests)
│   ├── BridgeEnvTests.swift         (신규, 10 tests)
│   ├── TimeoutPolicyTests.swift     (신규, 8 tests)
│   ├── PlistHelperTests.swift       (신규, 6 tests)
│   ├── BinaryIdentityTests.swift    (신규, 5 tests)
│   ├── LaunchdHelperTests.swift     (신규, 4 tests)
│   ├── InFlightTrackerTests.swift   (신규, 6 tests) [Swift 특화]
│   ├── SocketHelpersTests.swift     (신규, 4 tests) [Swift 특화]
│   └── Helpers/
│       ├── MockMCPSession.swift
│       ├── MockLaunchd.swift
│       ├── MockSessionClient.swift
│       └── TestUtilities.swift
├── XcodeCLITests/
│   ├── CLIIntegrationTests.swift    (기존, 2 tests)
│   ├── CLIParsingTests.swift        (신규, 25 tests)
│   ├── MCPConfigTests.swift         (신규, 18 tests)
│   ├── AgentGuideTests.swift        (신규, 12 tests)
│   ├── AgentDemoTests.swift         (신규, 8 tests)
│   ├── ServeTests.swift             (신규, 3 tests)
│   ├── CLIRunTests.swift            (신규, 20 tests)
│   ├── UpdaterTests.swift           (신규, 10 tests)
│   ├── ConcurrencyTests.swift       (신규, 4 tests) [Swift 특화]
│   └── ErrorAggregationTests.swift  (신규, 4 tests) [Swift 특화]
```

## Tier Breakdown

### Tier 1: 순수 로직 (28 tests, mock 불필요)

**TimeoutPolicyTests.swift** (8 tests)
- `defaultToolCallTimeout("BuildProject")` == 1800
- `defaultToolCallTimeout("XcodeRead")` == 60
- `defaultToolCallTimeout("XcodeWrite")` == 120
- `defaultToolCallTimeout("UnknownTool")` == 300
- `formatDuration(3600)` == "1h"
- `formatDuration(300)` == "5m"
- `formatDuration(60)` == "60s"
- `formatDuration(0)` == "0s"
- Go 참조: `cmd/xcodecli/coverage_helpers_test.go` TestFormatTimeoutDurationHelper

**AgentPathsTests.swift** (5 tests)
- `defaultPaths()` produces non-empty fields
- `resolvePaths(homeDir:)` produces correct relative paths
- socketPath is under supportDir
- plistPath is under ~/Library/LaunchAgents/
- convenience accessors match defaultPaths()
- Go 참조: `internal/pathutil/pathutil_test.go`

**PlistHelperTests.swift** (6 tests)
- `renderLaunchAgentPlist` contains Label, ProgramArguments, RunAtLoad
- `readLaunchAgentBinaryPathFromString` extracts first ProgramArguments string
- render → parse round-trip returns same binary path
- xmlEscape handles &, <, >, ", '
- `ensureLaunchAgentPlist` returns changed=false for identical content
- `ensureLaunchAgentPlist` returns changed=true when content differs
- Go 참조: `internal/agent/plist.go` (implied by agent_test.go)

**BinaryIdentityTests.swift** (5 tests)
- existing file returns "sha256:<hex>"
- nonexistent file returns "path:<path>"
- empty path throws
- write + read round-trip preserves identity
- `binaryIdentityPath` returns correct path
- Go 참조: `internal/agent/binary_identity.go`

**LaunchdHelperTests.swift** (4 tests)
- `launchAgentDomainTarget()` returns "gui/<uid>"
- `launchAgentServiceTarget(label:)` returns "gui/<uid>/<label>"
- CommandLaunchd with mock runner invokes correct launchctl args
- Non-zero exit code throws agentUnavailable
- Go 참조: `internal/agent/launchd_test.go`

### Tier 2: Mock 기반 단위 테스트 (50 tests)

**BridgeEnvTests.swift** (10 tests)
- effective options prefers overrides
- applyOverrides merges correctly
- validate rejects invalid PID
- validate rejects invalid UUID
- resolve uses explicit > env > persisted
- resolve creates and persists new UUID
- resolve reuses persisted UUID
- resolve repairs invalid persisted UUID
- newUUID returns valid format
- debug log output
- Go 참조: `internal/bridge/env_test.go`, `session_test.go`

**DoctorTests.swift** (+2 = 9 total)
- (기존 7 유지)
- agent status info included in report
- skips smoke when overrides invalid
- Go 참조: `internal/doctor/doctor_test.go`

**MCPConfigTests.swift** (18 tests)
- codex invocation format: "codex mcp add ..."
- claude invocation: "claude mcp add-json -s ..."
- gemini invocation: "gemini mcp add -s ..."
- buildClaudeJSONPayload structure
- shell quoting: safe chars passthrough
- shell quoting: special chars single-quoted
- envArgs sorted output
- performWrite codex success
- performWrite claude replace existing server
- performWrite claude retry when remove says not found
- resolveCurrentExecutablePath uses argv[0]
- resolveCurrentExecutablePath absolute path
- config does not create persistent session file
- config rejects invalid session ID
- bridge mode preserves "bridge" target
- JSON output structure
- text output format
- unsupported client throws
- Go 참조: `cmd/xcodecli/mcp_config_test.go` (22 tests)

**AgentGuideTests.swift** (12 tests)
- classifyGuideIntent: "build project" → build
- classifyGuideIntent: "run all tests" → test
- classifyGuideIntent: "read Main.swift" → read
- classifyGuideIntent: "find AdManager" → search
- classifyGuideIntent: "update viewModel" → edit
- classifyGuideIntent: "diagnose build errors" → diagnose
- classifyGuideIntent: empty → catalog
- confidence formula: 0.35 + score*0.1, max 0.99
- resolveGuideWindowMatch: single match returns entry
- resolveGuideWindowMatch: ambiguous keeps placeholder
- resolveGuideWindowMatch: no match returns note
- guide catalog shows all workflow tool chains
- Go 참조: `cmd/xcodecli/agent_guide_test.go` (13 tests)

**AgentDemoTests.swift** (8 tests)
- demo text output structure
- demo JSON report structure
- demo handles tools list failure
- demo handles missing XcodeListWindows tool
- demo handles window tool execution failure
- success condition: all ok
- next commands template
- extractToolResultMessage from structuredContent/content
- Go 참조: `cmd/xcodecli/agent_demo_test.go` (8 tests)

### Tier 3: MCP 프로토콜 테스트 (18 tests)

**MCPClientTests.swift** (8 tests)
Pipe 기반: Pipe로 stdin/stdout 연결, 별도 Task에서 fake server 응답.
- listTools aggregates pagination (cursor loop)
- callTool returns result and isError
- callTool recognizes isError=true
- listTools rejects unsupported protocol version
- listTools handles server request (responds with error)
- listTools times out (Task cancellation)
- listTools fails on malformed JSON
- debug logs notifications
- Go 참조: `internal/mcp/client_test.go` (8 tests)

**MCPServerTests.swift** (10 tests)
Pipe 기반: serveMCPStdio에 Pipe 연결.
- initialize responds with protocolVersion and serverInfo
- initialize negotiates supported version
- initialize rejects unsupported version
- initialize rejects missing protocolVersion
- cancellation suppresses response and keeps server alive
- cancellation supports numeric request ID
- ignores malformed/unknown cancellation
- handles multiple requests after cancellation
- ping returns empty result
- unknown method returns -32601
- Go 참조: `internal/mcp/server_test.go` (8 tests)

### Tier 4: Agent RPC 통합 테스트 (28 tests)

**AgentServerTests.swift** (20 tests)
FakeAgentServer: temp dir에 소켓 생성, MockSessionClient 주입.
- listTools auto-installs LaunchAgent and reuses backend session
- LaunchAgent stops after idle timeout
- default idle timeout is 24 hours
- listTools replaces idle session when session key changes
- listTools retires previous in-flight session after handoff
- listTools recycles LaunchAgent when registered binary changes
- listTools recycles when binary identity changes at same path
- listTools does not block on retired idle session abort
- finishSession does not block on retired in-flight abort
- listTools autostart honors caller timeout
- listTools backend initialization honors request timeout
- callTool timeout includes request timeout message
- doRPC cancel without deadline unblocks read
- doWithAutostart returns server response error verbatim
- server status returns correct runtime fields
- request context timeout from timeoutMS
- session key from different fields
- handleConn cancels in-flight request on disconnect
- shutdown closes all sessions
- runtimeStatus backendSessions count
- Go 참조: `internal/agent/agent_test.go` (25 tests)

**AgentClientTests.swift** (8 tests)
FakeAgentServer로 로컬 RPC 테스트.
- status returns correct fields from ping
- stop sends stop method
- uninstall removes artifacts
- autostart uses remaining timeout budget
- waitForReady honors short caller deadline
- waitForReady can exceed 5 seconds when caller deadline allows
- handleRPCError distinguishes server vs unavailable
- launchAgentBinaryMismatch detection
- Go 참조: `internal/agent/agent_test.go` (remaining tests)

### Tier 5: CLI 파싱/실행 (33 tests)

**CLIParsingTests.swift** (25 tests)
ArgumentParser의 parseAsRoot 사용.
- default bridge with PID/session/debug
- version command
- --version flag
- doctor --json
- serve with debug/session-id
- tools list
- tools list default timeout
- tool inspect
- tool inspect custom timeout
- tool call inline JSON
- tool call default timeouts by tool
- tool call JSON stdin
- tool call rejects conflicting inputs
- agent status
- agent run requires --launch-agent
- mcp config codex
- mcp alias codex
- mcp config claude defaults scope
- mcp config gemini defaults scope
- mcp config rejects missing client
- help command
- unknown command shows help
- root usage includes guidance
- version usage mentions flag
- update usage
- Go 참조: `cmd/xcodecli/main_test.go` (19 parsing tests)

**ServeTests.swift** (3 tests)
- serve delegates listTools to AgentClient
- serve delegates callTool to AgentClient
- serve passes debug flag to MCPServerConfig
- Go 참조: `cmd/xcodecli/main_test.go` TestRunServe*

**CLIIntegrationTests.swift** (+5 = 7 total)
- (기존 2 유지)
- doctor command exits 0
- tools list --json exits 0 (requires agent, may skip)
- agent status --json exits 0
- help exits 0
- unknown command exits non-zero

### Tier 5b: CLI 실행 테스트 (20 tests)

**CLIRunTests.swift** (20 tests)
Mock 기반 실행: AgentClient/MCPSession을 mock하여 실제 프로세스 없이 CLI 실행 검증.
- run version command outputs version line
- run --version flag outputs version line
- run doctor --json produces valid JSON
- run tools list --json returns tools array
- run tool inspect text shows name/description/schema
- run tool inspect --json returns tool object
- run tool inspect missing tool exits 1
- run tool call with inline JSON returns result
- run tool call --json-stdin reads from stdin
- run tool call isError exits 1
- run tool call from @file reads file
- run tool call uses request timeout context
- run agent status text shows fields
- run agent status --json returns valid JSON
- run agent commands do not create persistent session
- run serve uses persistent session ID
- run serve passes agent request context to handlers
- run serve reports server error
- run rejects invalid bridge options
- run help shows version header
- Go 참조: `cmd/xcodecli/main_test.go` TestRun* (37 execution tests)

### Tier 5c: Update 테스트 (10 tests)

**UpdaterTests.swift** (10 tests)
- parseLatestTag selects newest semantic version
- parseLatestTag fails when missing versions
- run Homebrew update reports already up to date
- run direct update builds and replaces executable
- run direct update returns already up to date
- run Homebrew path without brew returns helpful error
- command execution propagates exit code
- command execution reports missing CLI
- prepare replacement path creates sibling file
- inspect binary version rejects unexpected output
- Go 참조: `internal/update/update_test.go` (22 tests, Go 특화 제외)

### Tier 6: Swift 특화 추가 (18 tests)

**InFlightTrackerTests.swift** (6 tests)
- register returns true, finish returns true
- register duplicate returns false
- cancel sets cancelled flag, finish returns false
- cancelAll cancels all tasks
- concurrent register/finish from multiple tasks
- canonical key: int, string, double

**SocketHelpersTests.swift** (4 tests)
- setUnixSocketPath with normal path returns true
- setUnixSocketPath with 103+ char path returns false
- writeAllToFD writes all bytes
- writeAllToFD handles empty data

**ConcurrencyTests.swift** (4 tests)
- getOrCreateClient double-check prevents duplicate clients
- Task.checkCancellation in request loop
- adjustTimeout subtracts elapsed time correctly
- readEnvelope loop handles many empty lines without stack overflow

**ErrorAggregationTests.swift** (4 tests)
- uninstall collects multiple errors
- stop ignores unavailable but throws other errors
- writeResponse sends fallback on encoding failure
- setsockopt warning logged on failure

## Mock/Fake Designs

### MockMCPSession
```swift
final class MockMCPSession: @unchecked Sendable {
    let inputPipe = Pipe()   // test writes requests here
    let outputPipe = Pipe()  // test reads responses here
    var responses: [(String) -> String?] = []  // request → response mapping
}
```

### MockLaunchd
```swift
final class MockLaunchd: LaunchdInterface, @unchecked Sendable {
    var calls: [(method: String, args: [String])] = []
    var printResult: Result<String, Error> = .success("")
    var bootstrapResult: Result<Void, Error> = .success(())
    var kickstartResult: Result<Void, Error> = .success(())
    var bootoutResult: Result<Void, Error> = .success(())
}
```

### MockSessionClient
```swift
protocol SessionClientProtocol: Sendable {
    func listTools() async throws -> [JSONValue]
    func callTool(name: String, arguments: [String: JSONValue]) async throws -> MCPCallResult
    func close() async
    func abort() async
}
```

### Test Utilities
```swift
func withTemporaryDirectory<T>(_ body: (String) throws -> T) rethrows -> T
func withPipedMCPSession(_ body: (Pipe, Pipe) async throws -> Void) async throws
```

## Verification

```bash
# 전체 테스트
swift test

# 특정 Suite만
swift test --filter "TimeoutPolicy"
swift test --filter "MCPServer"
swift test --filter "AgentServer"

# 테스트 수 확인
swift test 2>&1 | grep "Test run"
# 기대: "Test run with ~220 tests in ~22 suites passed"
```

## Implementation Priority

1. Tier 1 (순수 로직, 28 tests) — 가장 쉬움, 즉시 가치
2. Tier 6 (Swift 특화, 18 tests) — 기존 리뷰 이슈 검증
3. Tier 3 (MCP 프로토콜, 18 tests) — 프로토콜 정합성
4. Tier 2 (Mock 기반, 50 tests) — 가장 많은 양
5. Tier 5a (CLI 파싱, 25 tests) — ArgumentParser 기반
6. Tier 5b (CLI 실행, 20 tests) — Mock 기반 실행 검증
7. Tier 5c (Update, 10 tests) — 업데이트 로직
8. Tier 4 (Agent RPC, 28 tests) — 가장 복잡한 인프라 (마지막)
