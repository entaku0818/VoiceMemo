package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
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
		Method:      "PUT",
		Expires:     time.Now().Add(15 * time.Minute),
		ContentType: "audio/" + body.Extension,
		Scheme:      storage.SigningSchemeV4,
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

	// Cloud Storage から音声取得
	obj := storageClient.Bucket(bucketName).Object(body.BlobName)
	reader, err := obj.NewReader(r.Context())
	if err != nil {
		http.Error(w, `{"error":"File not found"}`, http.StatusNotFound)
		return
	}
	defer reader.Close()

	audioBytes, err := io.ReadAll(reader)
	if err != nil {
		http.Error(w, `{"error":"Read error"}`, http.StatusInternalServerError)
		return
	}

	// MIMEタイプ判定
	ext := body.BlobName[strings.LastIndex(body.BlobName, ".")+1:]
	mimeType := "audio/mp4"
	if ext != "m4a" {
		mimeType = "audio/" + ext
	}

	// Gemini で文字起こし
	model := geminiClient.GenerativeModel("gemini-2.0-flash")
	prompt := fmt.Sprintf(`この音声を文字起こしして、以下のJSON形式のみを返してください。
言語: %s

{
  "transcription": "全文テキスト",
  "segments": [
    {"time": "0:00", "text": "..."}
  ],
  "summary": "内容の要約（3文以内）"
}`, body.Language)

	resp, err := model.GenerateContent(r.Context(),
		genai.Blob{MIMEType: mimeType, Data: audioBytes},
		genai.Text(prompt),
	)
	if err != nil {
		log.Printf("gemini error: %v", err)
		http.Error(w, `{"error":"Transcription failed"}`, http.StatusInternalServerError)
		return
	}

	// 処理済みファイル削除
	go obj.Delete(context.Background())

	// レスポンス返却
	text := ""
	if len(resp.Candidates) > 0 && len(resp.Candidates[0].Content.Parts) > 0 {
		if t, ok := resp.Candidates[0].Content.Parts[0].(genai.Text); ok {
			text = string(t)
		}
	}

	// JSONパース試行、失敗したら生テキストを返す
	var result map[string]any
	if err := json.Unmarshal([]byte(strings.TrimSpace(text)), &result); err != nil {
		result = map[string]any{
			"transcription": text,
			"segments":      []any{},
			"summary":       "",
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

func main() {
	http.HandleFunc("/health", handleHealth)
	http.HandleFunc("/upload-url", handleUploadURL)
	http.HandleFunc("/transcribe", handleTranscribe)

	port := getEnv("PORT", "8080")
	log.Printf("listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

