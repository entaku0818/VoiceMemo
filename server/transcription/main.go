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
	"strings"
	"time"

	"cloud.google.com/go/storage"
	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/auth"
	"github.com/google/generative-ai-go/genai"
	"github.com/google/uuid"
	"google.golang.org/api/googleapi"
	"google.golang.org/api/option"
)

// idTokenVerifier abstracts auth.Client.VerifyIDToken so handler tests can inject a fake
// verifier instead of requiring real Firebase credentials.
type idTokenVerifier interface {
	VerifyIDToken(ctx context.Context, idToken string) (*auth.Token, error)
}

var (
	firebaseAuth  idTokenVerifier
	storageClient *storage.Client
	geminiClient  *genai.Client
	bucketName    = getEnv("AUDIO_BUCKET", "voilog-transcription-audio")
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
	geminiClient, err = genai.NewClient(ctx, option.WithAPIKey(geminiAPIKey))
	if err != nil {
		log.Fatalf("gemini client: %v", err)
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

	geminiFile, err := geminiClient.UploadFile(geminiCtx, "", reader, &genai.UploadFileOptions{
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
	defer geminiClient.DeleteFile(context.Background(), geminiFile.Name)

	// Gemini で文字起こし
	model := geminiClient.GenerativeModel(getEnv("GEMINI_MODEL", "gemini-2.5-flash"))
	prompt := fmt.Sprintf(`この音声を文字起こしして、以下のJSON形式のみを返してください。
言語: %s

話者が複数いる場合は speaker フィールドで識別してください（A, B, C ...）。
話者が1人または不明な場合は speaker を空文字にしてください。

{
  "transcription": "全文テキスト（話者ラベルなし）",
  "segments": [
    {"time": "0:00", "speaker": "A", "text": "..."},
    {"time": "0:15", "speaker": "B", "text": "..."}
  ],
  "summary": "内容の要約（3文以内）"
}`, body.Language)

	result, err := transcribeWithRetry(func() (string, error) {
		resp, err := generateContentWithRetry(geminiCtx, generateContentAttemptTimeout, func(attemptCtx context.Context) (*genai.GenerateContentResponse, error) {
			return model.GenerateContent(attemptCtx,
				genai.FileData{URI: geminiFile.URI, MIMEType: mimeType},
				genai.Text(prompt),
			)
		})
		if err != nil {
			return "", err
		}
		text := ""
		if len(resp.Candidates) > 0 && len(resp.Candidates[0].Content.Parts) > 0 {
			if t, ok := resp.Candidates[0].Content.Parts[0].(genai.Text); ok {
				text = string(t)
			}
		}
		return text, nil
	})
	if err != nil {
		log.Printf("gemini error: %s", redactAPIKey(err.Error()))
		notifySlack(fmt.Sprintf(":x: [VoiLog] Transcription failed (Gemini)\n```%s```", sanitizeError(err)))
		http.Error(w, `{"error":"Transcription failed"}`, http.StatusInternalServerError)
		return
	}
	if result == nil {
		notifySlack(":x: [VoiLog] Transcription JSON unrecoverable after retry (no salvageable transcription field)")
		http.Error(w, `{"error":"Transcription failed"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

const generateContentAttemptTimeout = 240 * time.Second

// minutesAttemptTimeout は handleMinutes の geminiCtx（120s）に対して、
// generateContentWithRetry が最大2回試行してもgeminiCtxの期限内に収まるよう半分の値にする。
const minutesAttemptTimeout = 60 * time.Second

// contentGenerator abstracts genai.GenerativeModel.GenerateContent so handleMinutes'
// HTTPハンドラレベルの異常系テストが実際のGeminiクライアントなしで書けるようにする。
type contentGenerator interface {
	GenerateContent(ctx context.Context, parts ...genai.Part) (*genai.GenerateContentResponse, error)
}

// newMinutesModel は handleMinutes が使うGeminiモデルを生成する。テストでは差し替え可能にする
// ためパッケージ変数にしている。
var newMinutesModel = func() contentGenerator {
	return geminiClient.GenerativeModel(getEnv("GEMINI_MODEL", "gemini-2.5-flash"))
}

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
func isTransientGeminiError(err error) bool {
	if err == nil {
		return false
	}
	if errors.Is(err, context.DeadlineExceeded) {
		return true
	}
	var netErr net.Error
	if errors.As(err, &netErr) && netErr.Timeout() {
		return true
	}
	var apiErr *googleapi.Error
	if errors.As(err, &apiErr) {
		switch apiErr.Code {
		case http.StatusTooManyRequests, http.StatusInternalServerError, http.StatusBadGateway, http.StatusServiceUnavailable, http.StatusGatewayTimeout:
			return true
		}
	}
	return false
}

// transcribeWithRetry は fetchText で Gemini の生レスポンスを取得し、JSON としてパースする。
// パースに失敗した場合（Gemini の出力が途中で途切れるなど）は fetchText をもう一度だけ呼び直す。
// リトライしてもパースできない場合は、壊れた JSON から transcription フィールドの値を
// 可能な範囲でサルベージし、JSON の記号がユーザーに見えない形で返す。
// サルベージもできない場合は nil, nil を返す（呼び出し元でエラー応答にする）。
func transcribeWithRetry(fetchText func() (string, error)) (map[string]any, error) {
	var lastBroken string
	for attempt := 1; attempt <= 2; attempt++ {
		raw, err := fetchText()
		if err != nil {
			return nil, err
		}
		text := extractJSON(raw)
		var result map[string]any
		if err := json.Unmarshal([]byte(text), &result); err == nil {
			return result, nil
		} else {
			log.Printf("json parse error (attempt %d/2): %v, raw: %s", attempt, err, text)
			lastBroken = text
		}
	}

	salvaged := salvageTranscription(lastBroken)
	if salvaged == "" {
		return nil, nil
	}
	return map[string]any{
		"transcription": salvaged,
		"segments":      []any{},
		"summary":       "",
	}, nil
}

var transcriptionFieldPattern = regexp.MustCompile(`"transcription"\s*:\s*"`)

// salvageTranscription は途切れた/壊れた JSON 文字列から transcription フィールドの値を
// 可能な範囲で取り出す。JSON のエスケープシーケンス（\n, \", \\ など）を解決し、
// クオートやブレースなどの JSON 記号がユーザーに見える形で残らないようにする。
// フィールド自体が見つからない場合は空文字を返す。
func salvageTranscription(broken string) string {
	loc := transcriptionFieldPattern.FindStringIndex(broken)
	if loc == nil {
		return ""
	}
	rest := broken[loc[1]:]

	var sb strings.Builder
	for i := 0; i < len(rest); i++ {
		c := rest[i]
		if c == '"' {
			break
		}
		if c == '\\' && i+1 < len(rest) {
			i++
			switch rest[i] {
			case 'n':
				sb.WriteByte('\n')
			case 't':
				sb.WriteByte('\t')
			case '"':
				sb.WriteByte('"')
			case '\\':
				sb.WriteByte('\\')
			default:
				sb.WriteByte(rest[i])
			}
			continue
		}
		sb.WriteByte(c)
	}
	return strings.TrimSpace(sb.String())
}

// 議事録生成: 文字起こし済みテキストから要約とTODOを生成する
func handleMinutes(w http.ResponseWriter, r *http.Request) {
	_, err := verifyToken(r)
	if err != nil {
		http.Error(w, `{"error":"Unauthorized"}`, http.StatusUnauthorized)
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

	model := newMinutesModel()
	prompt := fmt.Sprintf(`以下の会議の文字起こしから議事録を作成し、次のJSON形式のみを返してください。
出力言語: %s

{
  "summary": "会議の要約（3〜5文で簡潔に）",
  "todos": ["会議で決まったアクションアイテムやTODO"]
}

TODOがない場合は todos を空配列にしてください。

文字起こし:
%s`, body.Language, body.Text)

	resp, err := generateContentWithRetry(geminiCtx, minutesAttemptTimeout, func(attemptCtx context.Context) (*genai.GenerateContentResponse, error) {
		return model.GenerateContent(attemptCtx, genai.Text(prompt))
	})
	if err != nil {
		log.Printf("gemini minutes error: %s", redactAPIKey(err.Error()))
		notifySlack(fmt.Sprintf(":x: [VoiLog] Minutes generation failed (Gemini)\n```%s```", sanitizeError(err)))
		http.Error(w, `{"error":"Minutes generation failed"}`, http.StatusInternalServerError)
		return
	}

	text := ""
	if len(resp.Candidates) > 0 && len(resp.Candidates[0].Content.Parts) > 0 {
		if t, ok := resp.Candidates[0].Content.Parts[0].(genai.Text); ok {
			text = string(t)
		}
	}

	result := parseMinutes(text)
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
