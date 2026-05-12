package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
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
	"google.golang.org/api/option"
)

var (
	firebaseAuth   *auth.Client
	storageClient  *storage.Client
	geminiClient   *genai.Client
	bucketName     = getEnv("AUDIO_BUCKET", "voilog-transcription-audio")
)

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func init() {
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

	// Gemini操作に明示的なタイムアウトを設定（SDKデフォルトの120s上限を回避）
	geminiCtx, geminiCancel := context.WithTimeout(r.Context(), 300*time.Second)
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

	resp, err := model.GenerateContent(geminiCtx,
		genai.FileData{URI: geminiFile.URI, MIMEType: mimeType},
		genai.Text(prompt),
	)
	if err != nil {
		log.Printf("gemini error: %s", redactAPIKey(err.Error()))
		notifySlack(fmt.Sprintf(":x: [VoiLog] Transcription failed (Gemini)\n```%s```", sanitizeError(err)))
		http.Error(w, `{"error":"Transcription failed"}`, http.StatusInternalServerError)
		return
	}

	// レスポンス返却
	text := ""
	if len(resp.Candidates) > 0 && len(resp.Candidates[0].Content.Parts) > 0 {
		if t, ok := resp.Candidates[0].Content.Parts[0].(genai.Text); ok {
			text = string(t)
		}
	}

	// markdown コードブロック除去 → JSON境界抽出 → パース
	text = extractJSON(text)
	var result map[string]any
	if err := json.Unmarshal([]byte(text), &result); err != nil {
		log.Printf("json parse error: %v, raw: %s", err, text)
		notifySlack(fmt.Sprintf(":warning: [VoiLog] JSON parse error (fell back to raw text)\n```%s```", sanitizeError(err)))
		result = map[string]any{
			"transcription": text,
			"segments":      []any{},
			"summary":       "",
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
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
	http.HandleFunc("/health", handleHealth)
	http.HandleFunc("/upload-url", handleUploadURL)
	http.HandleFunc("/transcribe", handleTranscribe)

	port := getEnv("PORT", "8080")
	log.Printf("listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

