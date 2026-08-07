package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"
	"time"

	"google.golang.org/genai"
)

func TestPerUIDLimiter_AllowsUpToBurstThenBlocks(t *testing.T) {
	l := newPerUIDLimiter(3)
	for i := 0; i < 3; i++ {
		if !l.Allow("uid-a") {
			t.Fatalf("request %d should be allowed within burst of 3", i+1)
		}
	}
	if l.Allow("uid-a") {
		t.Errorf("4th request should be blocked once burst is exhausted")
	}
}

func TestPerUIDLimiter_TracksUsersIndependently(t *testing.T) {
	l := newPerUIDLimiter(1)
	if !l.Allow("uid-a") {
		t.Fatalf("uid-a first request should be allowed")
	}
	if l.Allow("uid-a") {
		t.Errorf("uid-a second request should be blocked (burst=1)")
	}
	if !l.Allow("uid-b") {
		t.Errorf("uid-b should have its own independent quota")
	}
}

func TestParseRateEnv(t *testing.T) {
	const key = "TEST_RATE_LIMIT_PER_HOUR"
	tests := []struct {
		name     string
		envValue string
		setEnv   bool
		fallback int
		want     int
	}{
		{"unset uses fallback", "", false, 20, 20},
		{"valid value overrides fallback", "5", true, 20, 5},
		{"invalid value falls back", "not-a-number", true, 20, 20},
		{"zero falls back", "0", true, 20, 20},
		{"negative falls back", "-1", true, 20, 20},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setEnv {
				t.Setenv(key, tt.envValue)
			}
			if got := parseRateEnv(key, tt.fallback); got != tt.want {
				t.Errorf("parseRateEnv() = %d, want %d", got, tt.want)
			}
		})
	}
}

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

// fakeConnResetError models a net.Error like "read tcp ...: connection reset by peer",
// where Timeout() is false but the error is still a transient network failure.
type fakeConnResetError struct{}

func (fakeConnResetError) Error() string   { return "read tcp: connection reset by peer" }
func (fakeConnResetError) Timeout() bool   { return false }
func (fakeConnResetError) Temporary() bool { return false }

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
		{"net error without timeout (connection reset)", fakeConnResetError{}, true},
		{"gemini api 429", genai.APIError{Code: 429}, true},
		{"gemini api 500", genai.APIError{Code: 500}, true},
		{"gemini api 503", genai.APIError{Code: 503}, true},
		{"gemini api 400 (not transient)", genai.APIError{Code: 400}, false},
		{"wrapped gemini api 503", fmt.Errorf("generate failed: %w", genai.APIError{Code: 503}), true},
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

func TestNewGeminiHTTPClient_BoundsHungConnections(t *testing.T) {
	client := newGeminiHTTPClient()
	transport, ok := client.Transport.(*http.Transport)
	if !ok {
		t.Fatalf("Transport = %T, want *http.Transport", client.Transport)
	}
	if transport.ResponseHeaderTimeout <= 0 {
		t.Error("ResponseHeaderTimeout must be set so a hung connection fails before the caller's context deadline")
	}
	if transport.IdleConnTimeout <= 0 {
		t.Error("IdleConnTimeout must be set to avoid reusing stale idle connections")
	}
}

// newTestGeminiClient builds a genai.Client the same way initClients does, but pointed
// at a fake server. Keeping the construction identical (APIKey + custom HTTPClient) is
// the point: see TestGeminiClient_AttachesAPIKeyEndToEnd.
func newTestGeminiClient(t *testing.T, baseURL, apiKey string) *genai.Client {
	t.Helper()
	client, err := genai.NewClient(context.Background(), &genai.ClientConfig{
		APIKey:      apiKey,
		Backend:     genai.BackendGeminiAPI,
		HTTPClient:  newGeminiHTTPClient(),
		HTTPOptions: genai.HTTPOptions{BaseURL: baseURL},
	})
	if err != nil {
		t.Fatalf("genai.NewClient failed: %v", err)
	}
	return client
}

// TestGeminiClient_AttachesAPIKeyEndToEnd exercises the exact construction used by
// initClients (APIKey + a custom HTTPClient) through a real genai.Client against a
// fake HTTP server, rather than unit-testing the transport in isolation.
//
// This class of bug bit production on 2026-07-21: under the old
// github.com/google/generative-ai-go SDK, passing option.WithHTTPClient silently
// disabled the SDK's own API-key-attaching transport wrapper, so a change that looked
// correct in isolated unit tests (and passed `go vet`/`go build`) still meant 100% of
// real requests were rejected with "403: Method doesn't allow unregistered callers".
// google.golang.org/genai sets x-goog-api-key itself and is not supposed to have that
// coupling — this test is what proves it stays true. If it ever fails because gotKey
// is empty, treat it as a signal that Gemini auth is broken — do not loosen the
// assertion to make it pass.
func TestGeminiClient_AttachesAPIKeyEndToEnd(t *testing.T) {
	const testKey = "test-api-key"

	var gotKey string
	var requestCount int
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requestCount++
		gotKey = r.Header.Get("x-goog-api-key")
		if gotKey == "" {
			gotKey = r.URL.Query().Get("key")
		}
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"candidates":[{"content":{"parts":[{"text":"ok"}],"role":"model"}}]}`))
	}))
	defer srv.Close()

	ctx := context.Background()
	client := newTestGeminiClient(t, srv.URL, testKey)

	if _, err := client.Models.GenerateContent(ctx, "gemini-2.5-flash", genai.Text("hi"), nil); err != nil {
		t.Fatalf("GenerateContent failed: %v", err)
	}

	if requestCount == 0 {
		t.Fatal("fake server never received a request")
	}
	if gotKey != testKey {
		t.Errorf("request reached the server without the API key attached: got %q, want %q", gotKey, testKey)
	}
}

// TestGeminiGenerationConfig_DisablesThinkingOnTheWire は thinkingBudget=0 と
// maxOutputTokens が実際にリクエストボディに載ることを、SDK を通した実リクエストで確認する。
// 思考トークンは出力トークンとして課金され、本番の Gemini コストの半分以上を占めていた。
// 設定が落ちても応答は正常に返るため、ボディを見る以外に回帰を検出する手段がない。
func TestGeminiGenerationConfig_DisablesThinkingOnTheWire(t *testing.T) {
	var gotBody map[string]any
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		json.NewDecoder(r.Body).Decode(&gotBody)
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"candidates":[{"content":{"parts":[{"text":"ok"}],"role":"model"}}]}`))
	}))
	defer srv.Close()

	client := newTestGeminiClient(t, srv.URL, "test-api-key")
	cfg := geminiGenerationConfig(1234)
	if _, err := client.Models.GenerateContent(context.Background(), "gemini-2.5-flash", genai.Text("hi"), cfg); err != nil {
		t.Fatalf("GenerateContent failed: %v", err)
	}

	genCfg, ok := gotBody["generationConfig"].(map[string]any)
	if !ok {
		t.Fatalf("request body has no generationConfig: %v", gotBody)
	}
	if got := genCfg["maxOutputTokens"]; got != float64(1234) {
		t.Errorf("maxOutputTokens = %v, want 1234", got)
	}
	thinking, ok := genCfg["thinkingConfig"].(map[string]any)
	if !ok {
		t.Fatalf("generationConfig has no thinkingConfig: %v", genCfg)
	}
	if got := thinking["thinkingBudget"]; got != float64(0) {
		t.Errorf("thinkingBudget = %v, want 0 (thinking must be disabled — it is billed as output tokens)", got)
	}
}

func TestGeminiGenerationConfig_OmitsThinkingWhenBudgetNegative(t *testing.T) {
	// Gemini 3.x 系は thinkingBudget を受け付けず 400 になるため、負値で送信自体を止められる。
	t.Setenv("GEMINI_THINKING_BUDGET", "-1")
	cfg := geminiGenerationConfig(100)
	if cfg.ThinkingConfig != nil {
		t.Errorf("ThinkingConfig = %+v, want nil when GEMINI_THINKING_BUDGET is negative", cfg.ThinkingConfig)
	}
	if cfg.MaxOutputTokens != 100 {
		t.Errorf("MaxOutputTokens = %d, want 100", cfg.MaxOutputTokens)
	}
}

func TestParseIntEnv(t *testing.T) {
	tests := []struct {
		name     string
		set      bool
		value    string
		fallback int
		want     int
	}{
		{"unset uses fallback", false, "", 42, 42},
		{"zero is a valid value", true, "0", 42, 0},
		{"negative is a valid value", true, "-1", 42, -1},
		{"positive", true, "8192", 42, 8192},
		{"garbage uses fallback", true, "abc", 42, 42},
		{"empty uses fallback", true, "", 42, 42},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.set {
				t.Setenv("TEST_PARSE_INT_ENV", tt.value)
			}
			if got := parseIntEnv("TEST_PARSE_INT_ENV", tt.fallback); got != tt.want {
				t.Errorf("parseIntEnv() = %d, want %d", got, tt.want)
			}
		})
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
