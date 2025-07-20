# VoiLog開発でのPeekaboo活用ガイド

このガイドは、VoiLogアプリの開発時にPeekabooを使用してUI/UXの確認、バグレポート作成、ドキュメント作成を効率化する方法を説明します。

## VoiLog開発での主な用途

### 1. UI/UXレビュー

#### 録音画面のUI確認
```bash
# VoiLogの録音画面をキャプチャして分析
peekaboo --app "VoiLog" --window-title "録音" --analyze "この録音UIの使いやすさを評価し、改善点を提案してください"
```

#### プレイリスト機能のUI確認
```bash
# Enhanced Playlist機能の画面をキャプチャ
peekaboo --app "VoiLog" --analyze "プレイリスト機能のUIデザインについて、ユーザビリティの観点から評価してください"
```

### 2. バグレポート作成

#### エラー画面のキャプチャと分析
```bash
# エラーが発生した画面をキャプチャ
peekaboo --app "VoiLog" --analyze "表示されているエラーメッセージから、考えられる原因と解決策を提案してください" --path ~/Desktop/voilog-error-$(date +%Y%m%d-%H%M%S).png
```

#### 音声再生の不具合確認
```bash
# 再生画面の状態をキャプチャして分析
peekaboo --app "VoiLog" --window-title "再生" --analyze "音声再生UIの状態を確認し、正常に動作しているか判断してください"
```

### 3. ドキュメント作成支援

#### 各機能の画面キャプチャ
```bash
# VoiLogの主要機能を一括キャプチャ
mkdir -p ~/Desktop/voilog-docs/screenshots

# 録音画面
peekaboo --app "VoiLog" --window-title "録音" --path ~/Desktop/voilog-docs/screenshots/recording.png

# 再生画面
peekaboo --app "VoiLog" --window-title "再生" --path ~/Desktop/voilog-docs/screenshots/playback.png

# プレイリスト画面
peekaboo --app "VoiLog" --window-title "プレイリスト" --path ~/Desktop/voilog-docs/screenshots/playlist.png

# 設定画面
peekaboo --app "VoiLog" --window-title "設定" --path ~/Desktop/voilog-docs/screenshots/settings.png
```

### 4. Issue #82: 詳細な音声情報表示の確認

```bash
# 音声詳細画面をキャプチャして分析
peekaboo --app "VoiLog" --window-title "詳細情報" --analyze "この音声詳細表示画面に表示されている情報の見やすさと、追加すべき情報があれば提案してください"
```

## Claude Codeとの連携

### 1. スクリーンショットを撮影してClaude Codeで分析

```bash
# UIの問題を発見した場合
peekaboo --app "VoiLog" --path ~/Desktop/voilog-ui-issue.png

# Claude Codeで以下のように依頼
# "~/Desktop/voilog-ui-issue.png を見て、UIの改善点を提案してください"
```

### 2. 実装確認の自動化

```bash
# 実装した機能の動作確認スクリプト
#!/bin/bash

# Enhanced Playlist機能の動作確認
echo "Enhanced Playlist機能の確認中..."
peekaboo --app "VoiLog" --window-title "プレイリスト" \
  --analyze "プレイリスト機能が正しく実装されているか確認してください。特に以下の点を確認：
  1. シャッフル機能
  2. リピート機能
  3. 音声追加機能" \
  --path ~/Desktop/voilog-playlist-check.png

# 音声詳細表示の確認
echo "音声詳細表示機能の確認中..."
peekaboo --app "VoiLog" --window-title "詳細情報" \
  --analyze "Issue #82の要件通り、詳細な音声情報が表示されているか確認してください" \
  --path ~/Desktop/voilog-detail-check.png
```

## トラブルシューティング手順

### アプリが起動しない場合の診断
```bash
# Xcodeのエラー画面をキャプチャ
peekaboo --app "Xcode" --analyze "表示されているコンパイルエラーを解析し、修正方法を提案してください"
```

### UI要素が正しく表示されない場合
```bash
# 問題のある画面をキャプチャして分析
peekaboo --app "VoiLog" --mode frontmost \
  --analyze "UI要素の配置やレイアウトの問題を特定し、SwiftUIでの修正方法を提案してください"
```

## 開発ワークフローの例

### 新機能実装後の確認フロー
```bash
#!/bin/bash
# check-new-feature.sh

FEATURE_NAME=$1
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTPUT_DIR=~/Desktop/voilog-checks/$TIMESTAMP

mkdir -p $OUTPUT_DIR

echo "新機能 '$FEATURE_NAME' の確認を開始します..."

# 1. アプリ全体のスクリーンショット
peekaboo --app "VoiLog" --mode multi --path $OUTPUT_DIR/

# 2. 新機能の画面を分析
peekaboo --app "VoiLog" --analyze "新しく実装された '$FEATURE_NAME' 機能について、以下を評価してください：
- UIの一貫性
- ユーザビリティ
- アクセシビリティ
- パフォーマンスの観点から見た潜在的な問題" \
--path $OUTPUT_DIR/feature-analysis.png

# 3. レポート生成
echo "確認結果は $OUTPUT_DIR に保存されました"
```

## コード品質チェック

### SwiftUIビューの視覚的確認
```bash
# プレビューの状態をキャプチャ
peekaboo --app "Xcode" --window-title "Preview" \
  --analyze "このSwiftUIプレビューを見て、レイアウトの問題や改善点を指摘してください"
```

### デバッグ情報の確認
```bash
# デバッグコンソールをキャプチャ
peekaboo --app "Xcode" --window-title "Debug" \
  --analyze "デバッグコンソールに表示されている情報から、問題の原因を特定してください"
```

## 継続的インテグレーション

### PR作成時の自動スクリーンショット
```bash
#!/bin/bash
# pr-screenshots.sh

PR_NUMBER=$1
BRANCH_NAME=$(git branch --show-current)

echo "PR #$PR_NUMBER のスクリーンショットを生成中..."

# アプリをビルドして実行
xcodebuild -project VoiLog.xcodeproj -scheme VoiLogDevelop -configuration Debug -sdk iphonesimulator

# 主要画面をキャプチャ
for screen in "録音" "再生" "プレイリスト" "設定"; do
  peekaboo --app "Simulator" --window-title "$screen" \
    --path ~/Desktop/pr-$PR_NUMBER/$screen.png
done

echo "スクリーンショットが ~/Desktop/pr-$PR_NUMBER/ に保存されました"
```

## ベストプラクティス

1. **定期的なUI確認**: 新機能実装後は必ずPeekabooでUIを確認
2. **エラー記録**: エラーが発生したら即座にキャプチャして記録
3. **ドキュメント更新**: 機能変更時は自動的にスクリーンショットを更新
4. **チーム共有**: キャプチャした画像はチームで共有してレビュー

## 参考コマンド集

```bash
# VoiLogのウィンドウ一覧を確認
peekaboo list windows --app "VoiLog"

# シミュレーターのウィンドウを確認
peekaboo list windows --app "Simulator"

# 権限状態の確認（初回セットアップ時）
peekaboo permissions

# Peekabooの設定確認
peekaboo config show
```