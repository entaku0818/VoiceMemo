# Peekaboo 使い方ガイド

Peekabooは、macOSでスクリーンショットを撮影し、AIで画像を分析できるツールです。

## 権限設定（初回のみ）

1. **システム設定** を開く
2. **プライバシーとセキュリティ** → **画面収録** に移動
3. ターミナルアプリケーション（Terminal、iTerm2など）にチェックを入れる
4. ターミナルを再起動

## 基本的なスクリーンショット撮影

```bash
# 画面全体を撮影
peekaboo image --mode screen --path ~/Desktop/fullscreen.png

# アクティブなウィンドウを撮影
peekaboo image --mode frontmost --path ~/Desktop/active-window.png

# 特定のアプリを撮影（例：Safari）
peekaboo image --app Safari --path ~/Desktop/safari.png

# 特定のウィンドウタイトルを撮影
peekaboo image --app Chrome --window-title "Gmail" --path ~/Desktop/gmail.png

# 複数のウィンドウを一度に撮影
peekaboo image --app "Visual Studio Code" --mode multi --path ~/Desktop/
```

## AI画像分析

### 事前準備（AI機能を使う場合）
```bash
# 設定ファイルを作成
peekaboo config init

# 設定ファイルを編集（APIキーを設定）
peekaboo config edit
```

設定ファイルに以下を追加：
```json
{
  "ai": {
    "providers": ["openai/gpt-4o", "ollama/llava:latest"],
    "openai": {
      "api_key": "${OPENAI_API_KEY}"  // 環境変数から読み込み
    }
  }
}
```

### 画像分析の実行
```bash
# 画像の内容を分析
peekaboo analyze screenshot.png "この画像には何が表示されていますか？"

# エラーメッセージを確認
peekaboo analyze error.png "表示されているエラーを説明してください"

# UI の問題を検出
peekaboo analyze ui.png "UIデザインの改善点を教えてください"

# 特定のAIモデルを使用
peekaboo analyze diagram.png "この図を説明してください" --model gpt-4o
```

## ワンステップでキャプチャ＆分析

```bash
# Safariをキャプチャして即座に分析
peekaboo --app Safari --analyze "このページの主な内容を要約してください"

# アクティブウィンドウをキャプチャして分析
peekaboo --mode frontmost --analyze "画面に表示されている情報を説明してください"

# デスクトップ全体をキャプチャして分析
peekaboo --mode screen --analyze "デスクトップの状態を確認してください"
```

## その他の便利なコマンド

```bash
# 実行中のアプリ一覧を表示
peekaboo list apps

# 特定アプリのウィンドウ一覧を表示
peekaboo list windows --app Safari

# 権限の状態を確認
peekaboo permissions

# 設定内容を確認
peekaboo config show

# バージョン確認
peekaboo --version
```

## 活用例

### 1. バグレポート作成
```bash
# エラー画面をキャプチャして分析
peekaboo --app "MyApp" --analyze "表示されているエラーの原因を推測してください" --path ~/Desktop/bug-report.png
```

### 2. ドキュメント作成
```bash
# 複数のアプリ画面を一括撮影
for app in Safari Chrome "Visual Studio Code"; do
  peekaboo --app "$app" --path ~/Desktop/docs/
done
```

### 3. UI/UXレビュー
```bash
# UIをキャプチャして改善点を分析
peekaboo --app "MyApp" --analyze "このUIの使いやすさを評価し、改善点を提案してください"
```

## トラブルシューティング

- **権限エラーが出る場合**: システム設定で画面収録の権限を確認
- **AI分析が動作しない場合**: `peekaboo config show` で設定を確認し、APIキーが正しく設定されているか確認
- **特定のアプリが撮影できない場合**: `peekaboo list apps` でアプリ名を正確に確認

## 参考リンク

- GitHub: https://github.com/steipete/Peekaboo
- 公式サイト: https://peekaboo.boo