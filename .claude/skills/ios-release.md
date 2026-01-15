# iOS App Release Skill

## Overview
iOSアプリ(VoiLog)をApp Storeにリリースする手順。

## Prerequisites
- Xcode がインストールされていること
- App Store Connect API Key が設定されていること（環境変数）
- `bundle install` が完了していること

## Release Steps

### Step 1: バージョン更新
```bash
# project.pbxproj の MARKETING_VERSION を更新
# 例: 1.3.0 → 1.3.1
```

### Step 2: リリースノート更新
以下のファイルを更新:
- `fastlane/metadata/ja/release_notes.txt` (日本語)
- `fastlane/metadata/en-US/release_notes.txt` (英語)

### Step 3: Xcodeでアーカイブ作成・アップロード
1. Xcodeでプロジェクトを開く: `ios/VoiLog.xcodeproj`
2. Scheme を `VoiLog` (Production) に変更
3. Product → Archive を実行
4. Archives window で「Distribute App」を選択
5. 「App Store Connect」→「Upload」を選択
6. アップロード完了を待つ

### Step 4: Fastlaneでメタデータアップロード・審査提出
```bash
bundle exec fastlane upload_metadata
```

このコマンドは以下を実行:
- メタデータのアップロード
- スクリーンショットのアップロード
- 最新ビルドを選択して審査提出

### Step 5: Git Tag作成
```bash
git tag v1.x.x
git push origin v1.x.x
```

## Environment Variables Required
```bash
APP_STORE_CONNECT_API_KEY_KEY_ID=xxx
APP_STORE_CONNECT_API_KEY_ISSUER_ID=xxx
APP_STORE_CONNECT_API_KEY_CONTENT=xxx
```

## Troubleshooting

### アーカイブが失敗する場合
- Signing & Capabilities の設定を確認
- Team が正しく設定されているか確認

### fastlane upload_metadata が失敗する場合
- 環境変数が正しく設定されているか確認
- `bundle exec fastlane lanes` でレーン一覧を確認
