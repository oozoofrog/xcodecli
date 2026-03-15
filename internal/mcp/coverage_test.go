package mcp

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestMCPClientHelperFunctions(t *testing.T) {
	var buffer stderrBuffer
	buffer.append("hello")
	buffer.append(" world")
	if got := buffer.String(); got != "hello world" {
		t.Fatalf("stderrBuffer.String() = %q, want %q", got, "hello world")
	}

	if _, err := parseID(nil); err == nil || !strings.Contains(err.Error(), "response did not include an id") {
		t.Fatalf("expected missing id error, got %v", err)
	}

	if _, err := parseID(json.RawMessage(`"abc"`)); err == nil || !strings.Contains(err.Error(), "decode response id") {
		t.Fatalf("expected decode id error, got %v", err)
	}
}
