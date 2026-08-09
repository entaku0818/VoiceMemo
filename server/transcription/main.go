package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"cloud.google.com/go/storage"
	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/auth"
	"github.com/google/uuid"
	"golang.org/x/time/rate"
	"google.golang.org/genai"
)

var (
	firebaseAuth  *auth.Client
	storageClient *storage.Client
	geminiClient  *genai.Client
	bucketName    = getEnv("AUDIO_BUCKET", "voilog-transcription-audio")

	// premium会員判定を導入するまでの暫定的な濫用対策。UIDごとにGemini呼び出しを伴う
	// エンドポイントの呼び出し回数を制限する（issue #180）。
	transcribeLimiter = newPerUIDLimiter(parseRateEnv("TRANSCRIBE_RATE_LIMIT_PER_HOUR", 20))
	minutesLimiter    = newPerUIDLimiter(parseRateEnv("MINUTES_RATE_LIMIT_PER_HOUR", 30))
)

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// initClients は外部クライアントを初期化する。
// init() ではなく main() から呼ぶことで、単体テスト時に認証情報を要求しない。
func initClients() {
	ctx := context.Background()

	app, err := firebase.NewApp(ctx, nil)
	if err != nil {
		log.Fatalf("firebase init: %v", err)
	}
	firebaseAuth, err = app.Auth(ctx)
	if err != nil {
		log.Fatalf("firebase auth: %v", err)
	}

	storageClient, err = storage.NewClient(ctx)
	if err != nil {
		log.Fatalf("storage client: %v", err)
	}

	geminiAPIKey := getEnv("GEMINI_API_KEY", "")
	if geminiAPIKey == "" {
		log.Fatal("GEMINI_API_KEY is required")
	}
	geminiClient, err = genai.NewClient(ctx, &genai.ClientConfig{
		APIKey:     geminiAPIKey,
		Backend:    genai.BackendGeminiAPI,
		HTTPClient: newGeminiHTTPClient(),
	})
	if err != nil {
		log.Fatalf("gemini client: %v", err)
	}
}

// newGeminiHTTPClient は Gemini API 呼び出し用の http.Client を構築する。
// 本番で観測された /transcribe 失敗は、成功リクエストが10〜20sで完了する一方
// 失敗は例外なく親コンテキストの480sタイムアウトぴったりで発生しており、処理が
// 遅いのではなく接続がハングして応答が返らないパターンだった。ResponseHeaderTimeout
// を設定することで、ハングした試行を親コンテキストの残り時間いっぱい待たせず早期に
// 失敗させ、generateContentWithRetry が新しいコネクションで実際にリトライできるようにする。
// IdleConnTimeout は、NAT/LB 経由で無応答のまま片方だけ生き残ったアイドル接続の再利用を防ぐ。
//
// 旧 SDK（github.com/google/generative-ai-go）では option.WithHTTPClient を渡すと
// google.golang.org/api の transport が APIキー付与ラッパーを一切適用しなくなるため、
// 自前の RoundTripper で ?key= を足す必要があった（2026-07-21 の本番全断の原因）。
// google.golang.org/genai は HTTPClient を差し替えても自分で x-goog-api-key ヘッダを
// 付けるので、その回避策は不要になった。回帰はテストで担保する
// （TestGeminiClient_AttachesAPIKeyEndToEnd）。
func newGeminiHTTPClient() *http.Client {
	return &http.Client{
		Transport: &http.Transport{
			DialContext: (&net.Dialer{
				Timeout:   10 * time.Second,
				KeepAlive: 30 * time.Second,
			}).DialContext,
			TLSHandshakeTimeout:   10 * time.Second,
			ResponseHeaderTimeout: 120 * time.Second,
			IdleConnTimeout:       90 * time.Second,
			ExpectContinueTimeout: 1 * time.Second,
		},
	}
}

// geminiGenerationConfig は Gemini 呼び出し共通の生成設定を作る。
//
// gemini-2.5-flash は thinking（思考トークン）が既定でONで、思考トークンは
// candidatesTokenCount とは別枠で「出力トークン」として課金される。実測では
// /transcribe で出力の約45%、/minutes では約81%が思考トークンだった（本番の課金内訳で
// 「短いテキスト入力に対し出力200万トークン」という不自然な比率が出ていた原因）。
// thinkingBudget=0 で無効化する。
//
// maxOutputTokens は暴走時のコスト上限。思考トークンも maxOutputTokens を消費するため、
// thinking を切らずに小さい上限だけ入れると思考だけで打ち切られて空応答になる。
// 必ず両方セットで設定すること。
//
// GEMINI_THINKING_BUDGET に負値を指定すると thinkingConfig 自体を送らない。
// thinkingBudget を受け付けるかはモデルごとに違い、世代では割り切れない（2026-08-07 実測:
// gemini-2.5-flash と gemini-3.1-flash-lite は受け付ける / gemini-3.5-flash-lite は
// 400 INVALID_ARGUMENT を返す）。GEMINI_MODEL を変えるときは実際に叩いて確認し、
// 弾かれるモデルなら GEMINI_THINKING_BUDGET=-1 で送信自体を止めること。
func geminiGenerationConfig(maxOutputTokens int32) *genai.GenerateContentConfig {
	cfg := &genai.GenerateContentConfig{MaxOutputTokens: maxOutputTokens}
	if budget := int32(parseIntEnv("GEMINI_THINKING_BUDGET", 0)); budget >= 0 {
		cfg.ThinkingConfig = &genai.ThinkingConfig{ThinkingBudget: &budget}
	}
	return cfg
}

// 出力トークンの上限。
//
// transcribe は「モデルの outputTokenLimit そのもの」を入れる。当初 32768 にしていたが、
// 2026-08-08 に35分の実録音（音声52,859トークン）で本当に打ち切られた。
// このプロンプトは transcription（全文）と segments[].text（同じ内容の分割）を
// **両方**返させるので、出力トークンは音声の長さのおよそ2倍で伸びる。
// 2分で約1,100トークンだったから1時間でも余裕、という見積もりはこの二重出力を
// 数え落としていた。65536 は gemini-2.5-flash / gemini-3.1-flash-lite 共通の上限で、
// これ以上は上げられない（models.get の outputTokenLimit で確認できる）。
//
// 上限に当たると transcribeWithRetry がもう一度モデルを呼ぶため、打ち切りは
// 「ユーザーの文字起こしが欠ける」だけでなく出力トークンを二重に課金する。
// 暴走の歯止めとしては thinking 無効化＋この上限で足り、ここを絞ることではない。
//
// なお 65536 でも約25〜30分を超える録音は構造的に収まらない。恒久対策は
// transcription フィールドをモデルに出させず segments[].text をサーバ側で連結すること
// （出力が半分になり、コストも収容時間も倍改善する）。
//
// 議事録は summary + todos だけの短い出力（実測168〜239トークン）なので 2048 で十分。
const (
	defaultTranscribeMaxOutputTokens = 65536
	defaultMinutesMaxOutputTokens    = 2048
)

// logGeminiUsage は1リクエストあたりのトークン内訳を構造化ログに出す。
// thoughts が 0 でない場合は thinking 無効化が効いていない（モデルが thinkingBudget を
// 無視した等）ことを意味するので、コスト回帰にすぐ気づけるようにしている。
// finishReason が MAX_TOKENS の場合は出力が途中で打ち切られており、
// 文字起こしが欠けたまま返っているので上限の見直しが必要。
func logGeminiUsage(endpoint, model string, resp *genai.GenerateContentResponse) {
	if resp == nil || resp.UsageMetadata == nil {
		return
	}
	u := resp.UsageMetadata
	log.Printf("gemini usage endpoint=%s model=%s prompt=%d thoughts=%d candidates=%d total=%d",
		endpoint, model, u.PromptTokenCount, u.ThoughtsTokenCount, u.CandidatesTokenCount, u.TotalTokenCount)
	if len(resp.Candidates) > 0 && resp.Candidates[0].FinishReason == genai.FinishReasonMaxTokens {
		log.Printf("gemini output truncated by maxOutputTokens endpoint=%s model=%s", endpoint, model)
		notifySlack(fmt.Sprintf(":warning: [VoiLog] Gemini output hit maxOutputTokens (endpoint=%s, model=%s) — 出力が途中で切れています", endpoint, model))
	}
}

func verifyToken(r *http.Request) (string, error) {
	header := r.Header.Get("Authorization")
	if !strings.HasPrefix(header, "Bearer ") {
		return "", fmt.Errorf("missing token")
	}
	token, err := firebaseAuth.VerifyIDToken(r.Context(), strings.TrimPrefix(header, "Bearer "))
	if err != nil {
		return "", err
	}
	return token.UID, nil
}

// perUIDLimiter is an in-memory per-UID token bucket. Since the service runs as a single
// Cloud Run instance per request path (no shared store), this bounds cost abuse per instance
// but is not a distributed guarantee across scaled-out instances.
type perUIDLimiter struct {
	mu       sync.Mutex
	limiters map[string]*rate.Limiter
	perHour  int
}

func newPerUIDLimiter(perHour int) *perUIDLimiter {
	return &perUIDLimiter{
		limiters: make(map[string]*rate.Limiter),
		perHour:  perHour,
	}
}

// Allow は指定UIDが1回分のクォータを消費できるかを返す。トークンバケット方式のため、
// 未使用分は最大 perHour 件までバーストして消費できる（時間あたりの平均は perHour を超えない）。
func (l *perUIDLimiter) Allow(uid string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	lim, ok := l.limiters[uid]
	if !ok {
		lim = rate.NewLimiter(rate.Limit(float64(l.perHour)/3600), l.perHour)
		l.limiters[uid] = lim
	}
	return lim.Allow()
}

func parseRateEnv(key string, fallback int) int {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	n, err := strconv.Atoi(v)
	if err != nil || n <= 0 {
		return fallback
	}
	return n
}

// parseIntEnv は parseRateEnv と違い 0 や負値も有効な設定値として通す
// （thinkingBudget=0 が「思考を無効化する」という意味を持つため）。
func parseIntEnv(key string, fallback int) int {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return fallback
	}
	return n
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func handleUploadURL(w http.ResponseWriter, r *http.Request) {
	uid, err := verifyToken(r)
	if err != nil {
		http.Error(w, `{"error":"Unauthorized"}`, http.StatusUnauthorized)
		return
	}

	var body struct {
		Extension string `json:"extension"`
	}
	json.NewDecoder(r.Body).Decode(&body)
	if body.Extension == "" {
		body.Extension = "m4a"
	}

	fileID := uuid.New().String()
	blobName := fmt.Sprintf("%s/%s.%s", uid, fileID, body.Extension)

	opts := &storage.SignedURLOptions{
		GoogleAccessID: getEnv("SERVICE_ACCOUNT_EMAIL", "voilog-transcription@voilog.iam.gserviceaccount.com"),
		Method:         "PUT",
		Expires:        time.Now().Add(15 * time.Minute),
		ContentType:    audioMIMEType(body.Extension),
		Scheme:         storage.SigningSchemeV4,
	}
	url, err := storageClient.Bucket(bucketName).SignedURL(blobName, opts)
	if err != nil {
		log.Printf("signed url error: %v", err)
		http.Error(w, `{"error":"Internal"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"uploadUrl": url,
		"fileId":    fileID,
		"blobName":  blobName,
	})
}

func handleTranscribe(w http.ResponseWriter, r *http.Request) {
	uid, err := verifyToken(r)
	if err != nil {
		http.Error(w, `{"error":"Unauthorized"}`, http.StatusUnauthorized)
		return
	}
	if !transcribeLimiter.Allow(uid) {
		http.Error(w, `{"error":"Rate limit exceeded"}`, http.StatusTooManyRequests)
		return
	}

	var body struct {
		BlobName string `json:"blobName"`
		Language string `json:"language"`
	}
	json.NewDecoder(r.Body).Decode(&body)
	if !strings.HasPrefix(body.BlobName, uid+"/") {
		http.Error(w, `{"error":"Invalid file"}`, http.StatusBadRequest)
		return
	}
	if body.Language == "" {
		body.Language = "ja"
	}

	// MIMEタイプ判定
	ext := body.BlobName[strings.LastIndex(body.BlobName, ".")+1:]
	mimeType := audioMIMEType(ext)

	// Gemini操作に明示的なタイムアウトを設定（SDKデフォルトの120s上限を回避）。
	// Cloud Run側のリクエストタイムアウト(600s)にバッファを残す。
	geminiCtx, geminiCancel := context.WithTimeout(r.Context(), 480*time.Second)
	defer geminiCancel()

	// Cloud Storage から Gemini File API へストリーミングアップロード（メモリに乗せない）
	obj := storageClient.Bucket(bucketName).Object(body.BlobName)
	reader, err := obj.NewReader(geminiCtx)
	if err != nil {
		http.Error(w, `{"error":"File not found"}`, http.StatusNotFound)
		return
	}
	defer reader.Close()

	geminiFile, err := geminiClient.Files.Upload(geminiCtx, reader, &genai.UploadFileConfig{
		MIMEType: mimeType,
	})
	if err != nil {
		log.Printf("file upload error: %v", err)
		notifySlack(fmt.Sprintf(":warning: [VoiLog] Gemini file upload failed\n```%s```", sanitizeError(err)))
		http.Error(w, `{"error":"File upload failed"}`, http.StatusInternalServerError)
		return
	}
	// GCS の元ファイルとGeminiファイルを後始末
	go obj.Delete(context.Background())
	defer geminiClient.Files.Delete(context.Background(), geminiFile.Name, nil)

	// Gemini で文字起こし
	modelName := getEnv("GEMINI_MODEL", "gemini-2.5-flash")
	// transcription（全文）はモデルに出させない。segments[].text と同じ内容の二重出力になり、
	// 出力トークンが倍になっていたため。全文はサーバ側で segments を連結して組み立てる
	// （クライアントに返すJSONの形は変えない）。
	prompt := fmt.Sprintf(`この音声を文字起こししてください。
言語: %s

- segments に発話を時系列で入れてください。全文は segments の text をつなげたものになるので、
  取りこぼしがないようにしてください。
- 1つの segment は15〜30秒程度のまとまりにしてください。1文ごとに細かく分割しないでください。
- time は "0:00" 形式の開始時刻です。
- 話者が複数いる場合は speaker で識別してください（A, B, C ...）。
  話者が1人または不明な場合は speaker を空文字にしてください。
- summary は内容の要約を3文以内で。`, body.Language)

	contents := []*genai.Content{{
		Role: genai.RoleUser,
		Parts: []*genai.Part{
			{FileData: &genai.FileData{FileURI: geminiFile.URI, MIMEType: mimeType}},
			{Text: prompt},
		},
	}}
	genConfig := geminiGenerationConfig(int32(parseIntEnv("TRANSCRIBE_MAX_OUTPUT_TOKENS", defaultTranscribeMaxOutputTokens)))
	genConfig.ResponseMIMEType = "application/json"
	genConfig.ResponseSchema = transcribeResponseSchema()

	result, err := transcribeWithRetry(body.Language, func() (string, error) {
		resp, err := generateContentWithRetry(geminiCtx, generateContentAttemptTimeout, func(attemptCtx context.Context) (*genai.GenerateContentResponse, error) {
			return geminiClient.Models.GenerateContent(attemptCtx, modelName, contents, genConfig)
		})
		if err != nil {
			return "", err
		}
		logGeminiUsage("transcribe", modelName, resp)
		return resp.Text(), nil
	})
	if err != nil {
		log.Printf("gemini error: %s", redactAPIKey(err.Error()))
		notifySlack(fmt.Sprintf(":x: [VoiLog] Transcription failed (Gemini)\n```%s```", sanitizeError(err)))
		http.Error(w, `{"error":"Transcription failed"}`, http.StatusInternalServerError)
		return
	}
	if result == nil {
		notifySlack(":x: [VoiLog] Transcription JSON unrecoverable after retry (no salvageable segments)")
		http.Error(w, `{"error":"Transcription failed"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

const generateContentAttemptTimeout = 240 * time.Second

// generateContentWithRetry は callGenerate に対し、deadline exceeded やネットワーク瞬断など
// 一時的なエラー時に限り1回だけ再試行する。JSONパース失敗のリトライ（transcribeWithRetry）とは
// 独立したレイヤー。各試行は ctx から派生したタイムアウト付きコンテキストで実行されるため、
// リトライしても呼び出し元が設定した ctx 全体のデッドラインを超えることはない。
func generateContentWithRetry(ctx context.Context, timeout time.Duration, callGenerate func(context.Context) (*genai.GenerateContentResponse, error)) (*genai.GenerateContentResponse, error) {
	var lastErr error
	for attempt := 1; attempt <= 2; attempt++ {
		attemptCtx, cancel := context.WithTimeout(ctx, timeout)
		resp, err := callGenerate(attemptCtx)
		cancel()
		if err == nil {
			return resp, nil
		}
		lastErr = err
		if !isTransientGeminiError(err) {
			return nil, err
		}
		if attempt == 2 || ctx.Err() != nil {
			break
		}
		log.Printf("generateContent transient error (attempt %d/2), retrying: %s", attempt, redactAPIKey(err.Error()))
	}
	return nil, lastErr
}

// isTransientGeminiError は deadline exceeded・ネットワーク瞬断・Gemini側の5xx/429応答など
// 再試行すれば成功しうる一時的なエラーかどうかを判定する。
// net.Error は Timeout() の真偽に関わらず一時的なものとして扱う。
// "read tcp ...: connection reset by peer" のような接続断は Timeout()==false だが、
// 再送すれば成功しうる一時的なネットワークエラーであるため。
func isTransientGeminiError(err error) bool {
	if err == nil {
		return false
	}
	if errors.Is(err, context.DeadlineExceeded) {
		return true
	}
	var netErr net.Error
	if errors.As(err, &netErr) {
		return true
	}
	var apiErr genai.APIError
	if errors.As(err, &apiErr) {
		switch apiErr.Code {
		case http.StatusTooManyRequests, http.StatusInternalServerError, http.StatusBadGateway, http.StatusServiceUnavailable, http.StatusGatewayTimeout:
			return true
		}
	}
	return false
}

type transcriptionSegment struct {
	Time    string `json:"time"`
	Speaker string `json:"speaker"`
	Text    string `json:"text"`
}

// transcriptionResult はクライアントに返す形。transcription はモデル出力ではなく
// segments を連結してサーバ側で組み立てる（[[二重出力の廃止]]）。
type transcriptionResult struct {
	Transcription string                 `json:"transcription"`
	Segments      []transcriptionSegment `json:"segments"`
	Summary       string                 `json:"summary"`
}

// transcribeResponseSchema はモデル出力の構造を固定する。responseSchema を付けると
// マークダウンフェンスや前置きが混ざらなくなるため、JSONパース失敗による再試行
// （＝出力トークンの二重課金）が起きなくなる。
func transcribeResponseSchema() *genai.Schema {
	return &genai.Schema{
		Type: genai.TypeObject,
		Properties: map[string]*genai.Schema{
			"segments": {
				Type: genai.TypeArray,
				Items: &genai.Schema{
					Type: genai.TypeObject,
					Properties: map[string]*genai.Schema{
						"time":    {Type: genai.TypeString},
						"speaker": {Type: genai.TypeString},
						"text":    {Type: genai.TypeString},
					},
					Required:         []string{"time", "speaker", "text"},
					PropertyOrdering: []string{"time", "speaker", "text"},
				},
			},
			"summary": {Type: genai.TypeString},
		},
		Required:         []string{"segments", "summary"},
		PropertyOrdering: []string{"segments", "summary"},
	}
}

// joinSegmentText は segments[].text を全文テキストに連結する。
// 日本語・中国語は語の間に空白を入れない。それ以外の言語は入れないと単語が繋がってしまう。
func joinSegmentText(segments []transcriptionSegment, language string) string {
	sep := " "
	switch strings.ToLower(language) {
	case "ja", "zh", "zh-hans", "zh-hant", "zh-cn", "zh-tw":
		sep = ""
	}
	parts := make([]string, 0, len(segments))
	for _, s := range segments {
		if t := strings.TrimSpace(s.Text); t != "" {
			parts = append(parts, t)
		}
	}
	return strings.Join(parts, sep)
}

func newTranscriptionResult(segments []transcriptionSegment, summary, language string) *transcriptionResult {
	if segments == nil {
		segments = []transcriptionSegment{}
	}
	return &transcriptionResult{
		Transcription: joinSegmentText(segments, language),
		Segments:      segments,
		Summary:       summary,
	}
}

// transcribeWithRetry は fetchText で Gemini の生レスポンスを取得し、JSON としてパースする。
// パースに失敗した場合（出力が maxOutputTokens で途切れるなど）は fetchText をもう一度だけ呼び直す。
// リトライしてもパースできない場合は、壊れた JSON から完結している segment だけを
// 可能な範囲でサルベージする。サルベージもできない場合は nil, nil を返す
// （呼び出し元でエラー応答にする）。
func transcribeWithRetry(language string, fetchText func() (string, error)) (*transcriptionResult, error) {
	var lastBroken string
	for attempt := 1; attempt <= 2; attempt++ {
		raw, err := fetchText()
		if err != nil {
			return nil, err
		}
		text := extractJSON(raw)
		var parsed struct {
			Segments []transcriptionSegment `json:"segments"`
			Summary  string                 `json:"summary"`
		}
		if err := json.Unmarshal([]byte(text), &parsed); err == nil && len(parsed.Segments) > 0 {
			return newTranscriptionResult(parsed.Segments, parsed.Summary, language), nil
		} else if err != nil {
			// 生テキストはユーザーの録音内容そのものなのでログに出さない。
			// 切り分けに要るのは「どこで壊れたか」だけなので長さと末尾の形だけ残す。
			log.Printf("json parse error (attempt %d/2): %v (len=%d, endsWithBrace=%t)",
				attempt, err, len(text), strings.HasSuffix(strings.TrimSpace(text), "}"))
			lastBroken = text
		} else {
			log.Printf("json parsed but had no segments (attempt %d/2, len=%d)", attempt, len(text))
			lastBroken = text
		}
	}

	salvaged := salvageSegments(lastBroken)
	if len(salvaged) == 0 {
		return nil, nil
	}
	log.Printf("salvaged %d segments from broken JSON", len(salvaged))
	return newTranscriptionResult(salvaged, "", language), nil
}

// segmentObjectPattern は途切れた JSON の中から「閉じている」segment オブジェクトだけを拾う。
// 出力が途中で切れた場合、最後の不完全なオブジェクトはマッチしないので自然に捨てられる。
var segmentObjectPattern = regexp.MustCompile(`\{[^{}]*"text"\s*:\s*"(?:[^"\\]|\\.)*"[^{}]*\}`)

// salvageSegments は壊れた JSON から復元できる segment を順に取り出す。
func salvageSegments(broken string) []transcriptionSegment {
	var out []transcriptionSegment
	for _, m := range segmentObjectPattern.FindAllString(broken, -1) {
		var s transcriptionSegment
		if err := json.Unmarshal([]byte(m), &s); err == nil && strings.TrimSpace(s.Text) != "" {
			out = append(out, s)
		}
	}
	return out
}

// 議事録生成: 文字起こし済みテキストから要約とTODOを生成する
func handleMinutes(w http.ResponseWriter, r *http.Request) {
	uid, err := verifyToken(r)
	if err != nil {
		http.Error(w, `{"error":"Unauthorized"}`, http.StatusUnauthorized)
		return
	}
	if !minutesLimiter.Allow(uid) {
		http.Error(w, `{"error":"Rate limit exceeded"}`, http.StatusTooManyRequests)
		return
	}

	var body struct {
		Text     string `json:"text"`
		Language string `json:"language"`
	}
	json.NewDecoder(r.Body).Decode(&body)
	body.Text = strings.TrimSpace(body.Text)
	if body.Text == "" {
		http.Error(w, `{"error":"Text is required"}`, http.StatusBadRequest)
		return
	}
	if body.Language == "" {
		body.Language = "ja"
	}
	body.Text = truncateRunes(body.Text, maxMinutesInputRunes)

	geminiCtx, geminiCancel := context.WithTimeout(r.Context(), 120*time.Second)
	defer geminiCancel()

	modelName := getEnv("GEMINI_MODEL", "gemini-2.5-flash")
	prompt := fmt.Sprintf(`以下の会議の文字起こしから議事録を作成し、次のJSON形式のみを返してください。
出力言語: %s

{
  "summary": "会議の要約（3〜5文で簡潔に）",
  "todos": ["会議で決まったアクションアイテムやTODO"]
}

TODOがない場合は todos を空配列にしてください。

文字起こし:
%s`, body.Language, body.Text)

	minutesConfig := geminiGenerationConfig(int32(parseIntEnv("MINUTES_MAX_OUTPUT_TOKENS", defaultMinutesMaxOutputTokens)))
	minutesConfig.ResponseMIMEType = "application/json"
	minutesConfig.ResponseSchema = minutesResponseSchema()

	resp, err := geminiClient.Models.GenerateContent(geminiCtx, modelName, genai.Text(prompt), minutesConfig)
	if err != nil {
		log.Printf("gemini minutes error: %s", redactAPIKey(err.Error()))
		notifySlack(fmt.Sprintf(":x: [VoiLog] Minutes generation failed (Gemini)\n```%s```", sanitizeError(err)))
		http.Error(w, `{"error":"Minutes generation failed"}`, http.StatusInternalServerError)
		return
	}
	logGeminiUsage("minutes", modelName, resp)

	result := parseMinutes(resp.Text())
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

const maxMinutesInputRunes = 100_000

func truncateRunes(s string, max int) string {
	runes := []rune(s)
	if len(runes) <= max {
		return s
	}
	return string(runes[:max])
}

type minutesResult struct {
	Summary string   `json:"summary"`
	Todos   []string `json:"todos"`
}

// minutesResponseSchema は議事録出力の構造を固定する。これがないと Gemini が
// マークダウンフェンスや前置きを付けることがあり、parseMinutes のフォールバックで
// 本文まるごとが summary に入る（TODOが失われる）事故になる。
func minutesResponseSchema() *genai.Schema {
	return &genai.Schema{
		Type: genai.TypeObject,
		Properties: map[string]*genai.Schema{
			"summary": {Type: genai.TypeString},
			"todos":   {Type: genai.TypeArray, Items: &genai.Schema{Type: genai.TypeString}},
		},
		Required:         []string{"summary", "todos"},
		PropertyOrdering: []string{"summary", "todos"},
	}
}

// parseMinutes は Gemini の出力から {summary, todos} を取り出す。
// JSONとしてパースできない場合は本文全体を summary として返す。
func parseMinutes(raw string) minutesResult {
	text := extractJSON(raw)
	var result minutesResult
	if err := json.Unmarshal([]byte(text), &result); err != nil {
		log.Printf("minutes json parse error: %v", err)
		return minutesResult{Summary: strings.TrimSpace(raw), Todos: []string{}}
	}
	if result.Todos == nil {
		result.Todos = []string{}
	}
	return result
}

func notifySlack(msg string) {
	webhookURL := getEnv("SLACK_WEBHOOK_URL", "")
	if webhookURL == "" {
		return
	}
	payload, _ := json.Marshal(map[string]string{"text": msg})
	go func() {
		resp, err := http.Post(webhookURL, "application/json", bytes.NewReader(payload))
		if err != nil {
			log.Printf("slack notify error: %v", err)
			return
		}
		resp.Body.Close()
	}()
}

var apiKeyPattern = regexp.MustCompile(`[?&]key=[^&"'\s]+`)

func redactAPIKey(s string) string {
	return apiKeyPattern.ReplaceAllString(s, "&key=REDACTED")
}

var filePathPattern = regexp.MustCompile(`(/home|/usr|/var|/etc|/tmp|/root|/opt)[^\s"']+`)

func sanitizeError(err error) string {
	if err == nil {
		return ""
	}
	msg := err.Error()
	// Extract only the first line
	if idx := strings.Index(msg, "\n"); idx != -1 {
		msg = msg[:idx]
	}
	// Remove file path patterns
	msg = filePathPattern.ReplaceAllString(msg, "[path]")
	// Redact API keys
	msg = redactAPIKey(msg)
	// Truncate to max 200 characters
	if len(msg) > 200 {
		msg = msg[:200]
	}
	return msg
}

func audioMIMEType(ext string) string {
	if ext == "m4a" || ext == "mp4" {
		return "audio/mp4"
	}
	return "audio/" + ext
}

func extractJSON(s string) string {
	s = strings.TrimSpace(s)
	// strip markdown fence
	if strings.HasPrefix(s, "```") {
		if idx := strings.Index(s, "\n"); idx != -1 {
			s = s[idx+1:]
		}
		if strings.HasSuffix(s, "```") {
			s = s[:len(s)-3]
		}
		s = strings.TrimSpace(s)
	}
	// find outermost JSON object
	start := strings.Index(s, "{")
	end := strings.LastIndex(s, "}")
	if start != -1 && end > start {
		return s[start : end+1]
	}
	return s
}

func main() {
	initClients()

	http.HandleFunc("/health", handleHealth)
	http.HandleFunc("/upload-url", handleUploadURL)
	http.HandleFunc("/transcribe", handleTranscribe)
	http.HandleFunc("/minutes", handleMinutes)

	port := getEnv("PORT", "8080")
	log.Printf("listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
