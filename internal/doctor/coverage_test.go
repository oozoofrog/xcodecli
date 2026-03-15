package doctor

import (
	"context"
	"errors"
	"os"
	"strings"
	"testing"
)

func TestDoctorHelperFunctions(t *testing.T) {
	inspector := NewInspector()
	if inspector.LookPath == nil || inspector.RunCommand == nil || inspector.ListProcesses == nil {
		t.Fatalf("NewInspector returned incomplete inspector: %+v", inspector)
	}

	failure := formatCommandFailure(CommandResult{ExitCode: 7, Stderr: "stderr text", Stdout: "stdout text"}, errors.New("boom"))
	for _, want := range []string{"boom", "exit 7", "stderr text", "stdout text"} {
		if !strings.Contains(failure, want) {
			t.Fatalf("formatCommandFailure missing %q: %s", want, failure)
		}
	}

	pid, cmd, ok := splitProcessLine("123 /Applications/Xcode.app/Contents/MacOS/Xcode")
	if !ok || pid != "123" || cmd != "/Applications/Xcode.app/Contents/MacOS/Xcode" {
		t.Fatalf("splitProcessLine returned (%q, %q, %t)", pid, cmd, ok)
	}
	if _, _, ok := splitProcessLine("no-space"); ok {
		t.Fatal("splitProcessLine should reject lines without whitespace")
	}
}

func TestDefaultRunCommandAndDefaultListProcesses(t *testing.T) {
	result, err := defaultRunCommand(context.Background(), CommandRequest{Name: "/bin/sh", Args: []string{"-c", "printf hello"}})
	if err != nil {
		t.Fatalf("defaultRunCommand returned error: %v", err)
	}
	if result.Stdout != "hello" {
		t.Fatalf("stdout = %q, want hello", result.Stdout)
	}

	failResult, failErr := defaultRunCommand(context.Background(), CommandRequest{Name: "/bin/sh", Args: []string{"-c", "printf boom >&2; exit 7"}})
	if failErr == nil {
		t.Fatal("expected failing defaultRunCommand result")
	}
	if failResult.ExitCode != 7 {
		t.Fatalf("exit code = %d, want 7", failResult.ExitCode)
	}

	processes, err := defaultListProcesses(context.Background())
	if err != nil {
		t.Fatalf("defaultListProcesses returned error: %v", err)
	}
	currentPID := os.Getpid()
	found := false
	for _, proc := range processes {
		if proc.PID == currentPID {
			found = true
			break
		}
	}
	if !found {
		t.Fatalf("expected current pid %d in process list", currentPID)
	}
}
