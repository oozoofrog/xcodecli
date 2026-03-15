package main

import "testing"

func TestAgentDemoHelperExtractors(t *testing.T) {
	if got := extractDemoToolMessage(nil); got != "" {
		t.Fatalf("extractDemoToolMessage(nil) = %q, want empty", got)
	}

	structured := map[string]any{
		"structuredContent": map[string]any{"message": "structured hello"},
		"content":           []any{map[string]any{"text": "ignored"}},
	}
	if got := extractDemoToolMessage(structured); got != "structured hello" {
		t.Fatalf("structured message = %q, want structured hello", got)
	}

	contentOnly := map[string]any{
		"content": []any{
			map[string]any{"text": "first"},
			map[string]any{"text": "second"},
		},
	}
	if got := extractDemoToolMessage(contentOnly); got != "first\nsecond" {
		t.Fatalf("content message = %q, want combined lines", got)
	}

	raw := map[string]any{"foo": "bar"}
	if got := extractDemoToolMessage(raw); got == "" {
		t.Fatalf("raw fallback message should not be empty")
	}

	if got := indentText("a\nb", "  "); got != "  a\n  b" {
		t.Fatalf("indentText = %q, want indented text", got)
	}
	if got := stringValue("hello"); got != "hello" {
		t.Fatalf("stringValue = %q, want hello", got)
	}
	if got := stringValue(123); got != "" {
		t.Fatalf("stringValue(non-string) = %q, want empty", got)
	}
}
