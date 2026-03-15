package agent

import (
	"context"
	"strings"
	"testing"
)

func TestLaunchdHelperFunctions(t *testing.T) {
	if _, ok := defaultLaunchd().(commandLaunchd); !ok {
		t.Fatalf("defaultLaunchd did not return commandLaunchd")
	}

	domain := launchAgentDomainTarget()
	if !strings.HasPrefix(domain, "gui/") {
		t.Fatalf("launchAgentDomainTarget = %q, want gui/<uid>", domain)
	}

	service := launchAgentServiceTarget("io.oozoofrog.xcodecli")
	if !strings.HasSuffix(service, "/io.oozoofrog.xcodecli") {
		t.Fatalf("launchAgentServiceTarget = %q, want suffix /io.oozoofrog.xcodecli", service)
	}
}

func TestRunLaunchctlReturnsFormattedError(t *testing.T) {
	_, err := runLaunchctl(context.Background(), "this-subcommand-definitely-does-not-exist")
	if err == nil {
		t.Fatal("expected runLaunchctl to return an error")
	}
	if !strings.Contains(err.Error(), "launchctl this-subcommand-definitely-does-not-exist") {
		t.Fatalf("unexpected error: %v", err)
	}
}
