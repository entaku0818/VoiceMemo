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

### Step 3: アーカイブ作成・アップロード
```bash
# アーカイブ作成
xcodebuild -project ios/VoiLog.xcodeproj -scheme VoiLog -configuration Release -archivePath build/VoiLog.xcarchive archive

# ExportOptions.plist 作成
cat > /tmp/ExportOptions.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>upload</string>
    <key>teamID</key>
    <string>4YZQY4C47E</string>
</dict>
</plist>
EOF

# App Store Connect にアップロード
xcodebuild -exportArchive -archivePath build/VoiLog.xcarchive -exportOptionsPlist /tmp/ExportOptions.plist -exportPath build/export
```

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

### Step 6: GitHub Release作成
```bash
gh release create v1.x.x --title "v1.x.x" --latest --notes "$(cat <<'EOF'
## iOS
- 変更内容をここに記載

## Android
- 変更内容をここに記載
EOF
)"
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
