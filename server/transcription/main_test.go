package main

import (
	"errors"
	"reflect"
	"strings"
	"testing"
)

func TestParseMinutes(t *testing.T) {
	tests := []struct {
		name string
		raw  string
		want minutesResult
	}{
		{
			name: "plain JSON",
			raw:  `{"summary":"要約です","todos":["TODO1","TODO2"]}`,
			want: minutesResult{Summary: "要約です", Todos: []string{"TODO1", "TODO2"}},
		},
		{
			name: "markdown fenced JSON",
			raw:  "```json\n{\"summary\":\"要約\",\"todos\":[]}\n```",
			want: minutesResult{Summary: "要約", Todos: []string{}},
		},
		{
			name: "JSON with surrounding prose",
			raw:  "はい、こちらが議事録です。\n{\"summary\":\"会議の要約\",\"todos\":[\"資料送付\"]}\nご確認ください。",
			want: minutesResult{Summary: "会議の要約", Todos: []string{"資料送付"}},
		},
		{
			name: "todos omitted becomes empty slice",
			raw:  `{"summary":"要約のみ"}`,
			want: minutesResult{Summary: "要約のみ", Todos: []string{}},
		},
		{
			name: "unparseable falls back to raw text as summary",
			raw:  "  JSONではないただのテキスト  ",
			want: minutesResult{Summary: "JSONではないただのテキスト", Todos: []string{}},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := parseMinutes(tt.raw)
			if !reflect.DeepEqual(got, tt.want) {
				t.Errorf("parseMinutes() = %+v, want %+v", got, tt.want)
			}
		})
	}
}

func TestTruncateRunes(t *testing.T) {
	if got := truncateRunes("あいうえお", 3); got != "あいう" {
		t.Errorf("truncateRunes multibyte = %q, want %q", got, "あいう")
	}
	if got := truncateRunes("short", 100); got != "short" {
		t.Errorf("truncateRunes short = %q, want %q", got, "short")
	}
}

func TestExtractJSON(t *testing.T) {
	raw := "```json\n{\"a\":1}\n```"
	if got := extractJSON(raw); got != `{"a":1}` {
		t.Errorf("extractJSON = %q", got)
	}
}

func TestTranscribeWithRetry_SucceedsFirstTry(t *testing.T) {
	calls := 0
	fetch := func() (string, error) {
		calls++
		return `{"transcription":"こんにちは","segments":[],"summary":"挨拶"}`, nil
	}
	result, err := transcribeWithRetry(fetch)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if calls != 1 {
		t.Errorf("calls = %d, want 1 (should not retry on success)", calls)
	}
	if result["transcription"] != "こんにちは" {
		t.Errorf("transcription = %v", result["transcription"])
	}
}

func TestTranscribeWithRetry_RecoversOnRetry(t *testing.T) {
	calls := 0
	fetch := func() (string, error) {
		calls++
		if calls == 1 {
			return `{"transcription": "途中で切れた`, nil // unexpected end of JSON input
		}
		return `{"transcription":"やり直し成功","segments":[],"summary":""}`, nil
	}
	result, err := transcribeWithRetry(fetch)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if calls != 2 {
		t.Errorf("calls = %d, want 2", calls)
	}
	if result["transcription"] != "やり直し成功" {
		t.Errorf("transcription = %v, want retried result", result["transcription"])
	}
}

func TestTranscribeWithRetry_PropagatesFetchError(t *testing.T) {
	calls := 0
	wantErr := errors.New("gemini api error")
	fetch := func() (string, error) {
		calls++
		return "", wantErr
	}
	result, err := transcribeWithRetry(fetch)
	if !errors.Is(err, wantErr) {
		t.Fatalf("err = %v, want %v", err, wantErr)
	}
	if result != nil {
		t.Errorf("result = %v, want nil", result)
	}
	if calls != 1 {
		t.Errorf("calls = %d, want 1 (should not retry on transport error)", calls)
	}
}

func TestTranscribeWithRetry_SalvagesAfterBothAttemptsBroken(t *testing.T) {
	calls := 0
	fetch := func() (string, error) {
		calls++
		return `{"transcription": "録音の内容はここまでしか届きませんでした`, nil
	}
	result, err := transcribeWithRetry(fetch)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if calls != 2 {
		t.Errorf("calls = %d, want 2", calls)
	}
	transcription, _ := result["transcription"].(string)
	if transcription != "録音の内容はここまでしか届きませんでした" {
		t.Errorf("transcription = %q, want salvaged text", transcription)
	}
	if strings.ContainsAny(transcription, "{}") || strings.Contains(transcription, `"transcription"`) {
		t.Errorf("transcription leaked raw JSON syntax: %q", transcription)
	}
}

func TestTranscribeWithRetry_UnrecoverableWhenNoTranscriptionField(t *testing.T) {
	fetch := func() (string, error) {
		return `{"summary": "要約だけ壊れ`, nil
	}
	result, err := transcribeWithRetry(fetch)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result != nil {
		t.Errorf("result = %v, want nil (unrecoverable)", result)
	}
}

func TestSalvageTranscription(t *testing.T) {
	tests := []struct {
		name   string
		broken string
		want   string
	}{
		{
			name:   "truncated mid string",
			broken: `{"transcription": "途中で切れたテキストです`,
			want:   "途中で切れたテキストです",
		},
		{
			name:   "resolves escape sequences",
			broken: `{"transcription": "line1\nline2\ttabbed and \"quoted\"`,
			want:   "line1\nline2\ttabbed and \"quoted\"",
		},
		{
			name:   "properly closed string",
			broken: `{"transcription": "完全なテキスト", "summary": "壊れて`,
			want:   "完全なテキスト",
		},
		{
			name:   "field not present",
			broken: `{"summary": "壊れて`,
			want:   "",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := salvageTranscription(tt.broken); got != tt.want {
				t.Errorf("salvageTranscription() = %q, want %q", got, tt.want)
			}
		})
	}
}
