package main

import (
	"context"
	"errors"
	"fmt"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/google/generative-ai-go/genai"
	"google.golang.org/api/googleapi"
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

type fakeTimeoutError struct{}

func (fakeTimeoutError) Error() string   { return "fake timeout" }
func (fakeTimeoutError) Timeout() bool   { return true }
func (fakeTimeoutError) Temporary() bool { return true }

func TestIsTransientGeminiError(t *testing.T) {
	tests := []struct {
		name string
		err  error
		want bool
	}{
		{"nil", nil, false},
		{"deadline exceeded", context.DeadlineExceeded, true},
		{"wrapped deadline exceeded", fmt.Errorf("post failed: %w", context.DeadlineExceeded), true},
		{"net timeout error", fakeTimeoutError{}, true},
		{"googleapi 429", &googleapi.Error{Code: 429}, true},
		{"googleapi 500", &googleapi.Error{Code: 500}, true},
		{"googleapi 503", &googleapi.Error{Code: 503}, true},
		{"googleapi 400 (not transient)", &googleapi.Error{Code: 400}, false},
		{"plain error", errors.New("boom"), false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := isTransientGeminiError(tt.err); got != tt.want {
				t.Errorf("isTransientGeminiError(%v) = %v, want %v", tt.err, got, tt.want)
			}
		})
	}
}

func TestGenerateContentWithRetry_SucceedsFirstTry(t *testing.T) {
	calls := 0
	want := &genai.GenerateContentResponse{}
	callGenerate := func(ctx context.Context) (*genai.GenerateContentResponse, error) {
		calls++
		return want, nil
	}
	got, err := generateContentWithRetry(context.Background(), time.Second, callGenerate)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got != want {
		t.Errorf("got %v, want %v", got, want)
	}
	if calls != 1 {
		t.Errorf("calls = %d, want 1 (should not retry on success)", calls)
	}
}

func TestGenerateContentWithRetry_RetriesOnceOnTransientError(t *testing.T) {
	calls := 0
	want := &genai.GenerateContentResponse{}
	callGenerate := func(ctx context.Context) (*genai.GenerateContentResponse, error) {
		calls++
		if calls == 1 {
			return nil, context.DeadlineExceeded
		}
		return want, nil
	}
	got, err := generateContentWithRetry(context.Background(), time.Second, callGenerate)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got != want {
		t.Errorf("got %v, want %v", got, want)
	}
	if calls != 2 {
		t.Errorf("calls = %d, want 2", calls)
	}
}

func TestGenerateContentWithRetry_DoesNotRetryOnPermanentError(t *testing.T) {
	calls := 0
	wantErr := errors.New("invalid request")
	callGenerate := func(ctx context.Context) (*genai.GenerateContentResponse, error) {
		calls++
		return nil, wantErr
	}
	_, err := generateContentWithRetry(context.Background(), time.Second, callGenerate)
	if !errors.Is(err, wantErr) {
		t.Fatalf("err = %v, want %v", err, wantErr)
	}
	if calls != 1 {
		t.Errorf("calls = %d, want 1 (permanent errors must not be retried)", calls)
	}
}

func TestGenerateContentWithRetry_GivesUpAfterTwoTransientErrors(t *testing.T) {
	calls := 0
	callGenerate := func(ctx context.Context) (*genai.GenerateContentResponse, error) {
		calls++
		return nil, context.DeadlineExceeded
	}
	_, err := generateContentWithRetry(context.Background(), time.Second, callGenerate)
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("err = %v, want context.DeadlineExceeded", err)
	}
	if calls != 2 {
		t.Errorf("calls = %d, want 2 (at most one retry)", calls)
	}
}

func TestGenerateContentWithRetry_SkipsRetryWhenParentDeadlineExpired(t *testing.T) {
	parentCtx, cancel := context.WithTimeout(context.Background(), 0)
	defer cancel()
	time.Sleep(time.Millisecond)

	calls := 0
	callGenerate := func(ctx context.Context) (*genai.GenerateContentResponse, error) {
		calls++
		return nil, context.DeadlineExceeded
	}
	_, err := generateContentWithRetry(parentCtx, time.Second, callGenerate)
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("err = %v, want context.DeadlineExceeded", err)
	}
	if calls != 1 {
		t.Errorf("calls = %d, want 1 (should not retry once parent ctx is already expired)", calls)
	}
}

func TestGenerateContentWithRetry_AttemptContextBoundedByParent(t *testing.T) {
	parentCtx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()

	var gotDeadline time.Time
	callGenerate := func(ctx context.Context) (*genai.GenerateContentResponse, error) {
		gotDeadline, _ = ctx.Deadline()
		return &genai.GenerateContentResponse{}, nil
	}
	if _, err := generateContentWithRetry(parentCtx, time.Hour, callGenerate); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	parentDeadline, _ := parentCtx.Deadline()
	if gotDeadline.After(parentDeadline) {
		t.Errorf("attempt deadline %v exceeds parent deadline %v", gotDeadline, parentDeadline)
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
