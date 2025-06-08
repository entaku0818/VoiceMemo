# VoiceMemo v0.17.0 リリース手順書

## 概要
GitHub issue #72「録音完了後の保存フロー実装」の対応とFirebase Analytics機能追加を含むv0.17.0のリリース作業手順

## 実装作業

### 1. 録音完了後の保存フロー実装
**指示**: GitHub issue #72の実装

#### 実装内容
- **RecordingFeature の修正**
  - VoiceMemoRepositoryClient の依存関係追加
  - 録音完了時のデータベース保存処理実装
  - 一意なUUID管理の改善
  - タイトル保存機能の追加

- **PlaybackFeature の修正**
  - 実際のデータベースからのデータ読み込み実装
  - 削除機能のデータベース連携
  - データ再読み込み機能追加

- **VoiceAppFeature の修正**
  - 録音完了時の自動データ同期処理

- **VoiceMemoRepositoryClient の修正**
  - RecordingVoiceモデルにtitleフィールド追加
  - 型エラーの修正（VoiceMemoVoice → VoiceMemoRepositoryClient.VoiceMemoVoice）
  - CloudKitファイルパスの修正

### 2. Firebase Analytics機能追加
**指示**: PaywallViewのアクセスをFirebase Analyticsのイベントログとして取得、Dependency Clientで作成、コミットは2つに分ける

#### コミット1: Firebase Analytics Dependency Client作成
- `FirebaseAnalyticsClient`構造体作成
- イベントログ送信機能
- ユーザープロパティ設定機能
- 定義済みイベント名とプロパティ定数
- プレビュー・テスト用モック実装

#### コミット2: PaywallViewトラッキング実装
- PaywallView表示・非表示イベント
- 購入関連イベント（試行・成功・失敗）
- リストア関連イベント（試行・成功・失敗）
- 詳細なパラメータ付きイベントログ

## リリース作業

### 3. バージョン確認とタグ作成
**指示**: Xcodeプロジェクトでバージョン0.17.0確認、v0.17.0でタグ付け

```bash
# バージョン確認
grep "MARKETING_VERSION" VoiLog.xcodeproj/project.pbxproj

# タグ作成
git tag v0.17.0
git push origin v0.17.0
```

### 4. GitHubリリース作成
**指示**: リリース設定

```bash
# リリース作成
gh release create v0.17.0 --title "Release v0.17.0" --notes "軽微な不具合を修正しました。"
```

### 5. Fastlaneリリース実行
**指示**: Fastlaneでreleaseコマンド実行

```bash
# 利用可能レーン確認
fastlane lanes

# メタデータアップロードと審査提出
fastlane upload_metadata
```

## トラブルシューティング

### 発生した問題と対応

1. **型エラー**: `VoiceMemoVoice`が見つからない
   - **対応**: 完全修飾名`VoiceMemoRepositoryClient.VoiceMemoVoice`に修正

2. **Fastlaneレーン不存在**: `release`レーンが存在しない
   - **対応**: `upload_metadata`レーンを使用

3. **リリースノート言語構造問題**
   - **指示**: 既存内容を削除して「軽微な不具合を修正しました」に変更
   - **対応**: Fastlaneメタデータファイル更新、タグ・リリース再作成

## 変動要素（今後のリリースで変更が必要な項目）

### バージョン番号
- **Xcodeプロジェクト**: `MARKETING_VERSION = X.X.X`
- **タグ名**: `vX.X.X`
- **リリースタイトル**: `Release vX.X.X`

### リリースノート
- **日本語**: `fastlane/metadata/ja/release_notes.txt`
- **英語**: `fastlane/metadata/en-US/release_notes.txt`
- **その他言語**: 各言語ディレクトリの`release_notes.txt`

### GitHub issue番号
- 実装対象のissue番号に応じて変更

### 実装内容
- 各リリースの機能追加・修正内容に応じて変更

## 実行結果

- ✅ v0.17.0タグ作成完了
- ✅ GitHubリリース作成完了
- ✅ Fastlane upload_metadata実行完了
- ✅ App Store Connect審査提出完了

## 次回リリース時の注意点

1. バージョン番号の更新確認
2. リリースノートの内容更新
3. 実装内容に応じたテスト実行
4. Fastlaneの環境変数設定確認
5. App Store Connect APIキーの有効性確認 