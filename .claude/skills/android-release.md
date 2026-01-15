# Android App Release Skill

## Overview
AndroidアプリをGoogle Playにリリースする手順。

## Prerequisites
- JDK 17がインストールされていること
- `bundle install` が完了していること
- Google Play Console API Key (`play-store-credentials.json`) が設定されていること
- 署名用キーストア (`app-keys/SimpleRecord.keystore`) が存在すること

## Release Steps

### Step 1: バージョン更新
```bash
# app/build.gradle.kts の versionCode と versionName を更新
# versionCode: インクリメント (例: 8 → 9)
# versionName: セマンティックバージョン (例: 2.3.0 → 2.4.0)
```

### Step 2: ビルド
```bash
cd android/simpleRecord
./gradlew clean assembleRelease
# または AAB形式
./gradlew bundleRelease
```

### Step 3: Google Playにアップロード・リリース
```bash
cd android/simpleRecord

# 内部テスト
bundle exec fastlane android internal

# クローズドベータ
bundle exec fastlane android beta

# 本番リリース
bundle exec fastlane android production
```

### Step 4: Git Tag作成
```bash
git tag android-v2.x.x
git push origin android-v2.x.x
```

### Step 5: GitHub Release作成
```bash
gh release create android-v2.x.x --title "Android v2.x.x" --notes "$(cat <<'EOF'
## Android
- 変更内容をここに記載
EOF
)"
```

## Fastlane Lanes

| Lane | 説明 |
|------|------|
| `build` | リリースAABをビルド |
| `internal` | 内部テストにデプロイ |
| `beta` | クローズドベータにデプロイ |
| `production` | 本番リリース |
| `upload_internal` | 既存AABを内部テストにアップロード |
| `upload_production` | 既存AABを本番にアップロード |

## Troubleshooting

### ビルドが失敗する場合
- JDK 17が使用されているか確認: `java -version`
- キーストアのパスワードが正しいか確認: `app-keys/key.properties`

### fastlaneが失敗する場合
- `play-store-credentials.json` が存在するか確認
- Google Play Console APIが有効か確認
