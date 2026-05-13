---
name: voilog-release-checklist
description: Step-by-step release checklist for VoiLog iOS and Android app submission to App Store and Google Play. Use when preparing release, updating version, submitting to app stores, creating release, or mentioning App Store or Google Play submission.
metadata:
  author: VoiLog Team
  version: 3.0.0
  category: deployment
  tags: [release, launchpad, app-store, google-play, ios, android]
---

# VoiLog Release Checklist

**IMPORTANT FOR CLAUDE**: このスキルを使う際は、すべてのコマンドを **自動で実行** すること。ユーザーに「手動でやってください」と言ってはいけない。各ステップのコマンドは Claude が Bash ツールで直接叩く。確認が必要な場合は AskUserQuestion を使う。

**IMPORTANT**: Complete ALL steps before App Store or Google Play submission.

## Tool

リリースには `launchpad` を使用する（`bundle exec fastlane` は使わない）。  
設定は `.launchpadrc` で管理されている。

```
launchpad ios build       # アーカイブ作成 & エクスポート
launchpad ios upload      # App Store Connect にアップロード
launchpad ios metadata    # メタデータ更新 (fastlane/metadata/ を読む)
launchpad ios screenshots # スクリーンショットアップロード
launchpad ios submit      # 審査提出

launchpad android build   # AAB ビルド
launchpad android upload  # Google Play にアップロード
launchpad android promote # トラック昇格 (例: internal → production)
```

---

## Workflow: iOS Release

**Claude はこのワークフローをすべて自動実行する。** 各ステップのコマンドを Bash ツールで直接叩くこと。ユーザーに手動実行を求めてはいけない。

```
iOS Release Progress:
- [ ] Step 1: Update release notes (ja + en-US + all languages)
- [ ] Step 2: Bump version in project.pbxproj
- [ ] Step 3: Commit and create git tag
- [ ] Step 4: launchpad ios build
- [ ] Step 5: launchpad ios upload
- [ ] Step 6: launchpad ios metadata && launchpad ios screenshots --overwrite
- [ ] Step 7: launchpad ios submit
- [ ] Step 8: Create GitHub Release
```

### Step 1: Update Release Notes

**Files to update:**
- `fastlane/metadata/ja/release_notes.txt` (日本語 - 必須)
- `fastlane/metadata/en-US/release_notes.txt` (英語 - 必須)
- その他の言語 (`de-DE`, `es-ES`, `fr-FR`, `it`, `pt-PT`, `ru`, `tr`, `vi`, `zh-Hans`, `zh-Hant`)

**Format:**
```
バージョン 1.x.x

【新機能】
・新機能の説明

【改善】
・改善点

【修正】
・バグ修正
```

### Step 2: Bump Version

**File**: `ios/VoiLog.xcodeproj/project.pbxproj`

```bash
# 現在のバージョン確認
grep "MARKETING_VERSION" ios/VoiLog.xcodeproj/project.pbxproj | head -1

# バージョンアップ (例: 1.3.3 → 1.3.4)
sed -i '' 's/MARKETING_VERSION = 1.3.3;/MARKETING_VERSION = 1.3.4;/g' ios/VoiLog.xcodeproj/project.pbxproj
```

### Step 3: Commit and Create Git Tag

```bash
git add fastlane/metadata/
git add ios/VoiLog.xcodeproj/project.pbxproj
git commit -m "chore: bump version to 1.x.x

- Update release notes
- Increment version number

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"

git tag v1.x.x
git push origin main
git push origin v1.x.x
```

### Step 4: Build

```bash
launchpad ios build
```

`.launchpadrc` の `ios.project` / `ios.scheme` / `ios.output` / `ios.exportMethod` を使う。

### Step 5: Upload

```bash
launchpad ios upload
```

App Store Connect にバイナリを送信する。Apple 側の処理完了まで数分かかることがある。

### Step 6: Metadata & Screenshots

```bash
launchpad ios metadata
launchpad ios screenshots --overwrite
```

`fastlane/metadata/` と `fastlane/screenshots/` の内容をそのまま使う。

### Step 7: Submit for Review

```bash
launchpad ios submit
```

**⚠️ IMPORTANT**: submission fails with "missing required attribute" の場合は App Store Connect で手動設定が必要（次節参照）。

#### App Store Connect 手動設定 (必要な場合)

1. https://appstoreconnect.apple.com
2. **マイApp** → **VoiLog** → version 1.x.x → **App情報**
3. 必須属性を設定:
   - advertising: はい (AdMob使用)
   - userGeneratedContent: いいえ
   - healthOrWellnessTopics: いいえ
4. **審査に提出** をクリック

### Step 8: GitHub Release

```bash
gh release create v1.x.x --title "v1.x.x" --latest --notes "## iOS
- 変更内容"
```

---

## Workflow: Server Release (Cloud Run)

サーバー（`server/transcription/`）をデプロイした際は必ずタグとリリースを作成する。

**タグ命名規則**: `server-vX.Y.Z`

```
Server Release Progress:
- [ ] Step 1: 変更をコミット
- [ ] Step 2: gcloud run deploy でデプロイ
- [ ] Step 3: タグ作成 & push
- [ ] Step 4: GitHub Release 作成
```

```bash
# Step 2: Cloud Run デプロイ
cd server/transcription
gcloud run deploy voilog-transcription \
  --source . \
  --region asia-northeast1 \
  --no-allow-unauthenticated

# Step 3
git tag server-vX.Y.Z
git push origin main server-vX.Y.Z

# Step 4
gh release create server-vX.Y.Z --title "server-vX.Y.Z: 説明" --notes "## 変更内容"
```

---

## Workflow: Android Release

```
Android Release Progress:
- [ ] Step 1: Update release notes
- [ ] Step 2: Bump versionCode and versionName
- [ ] Step 3: Commit and create git tag
- [ ] Step 4: launchpad android build
- [ ] Step 5: launchpad android upload
- [ ] Step 6: Verify submission
```

### Step 1: Update Release Notes

- `fastlane/metadata/android/ja-JP/changelogs/[versionCode].txt`
- `fastlane/metadata/android/en-US/changelogs/[versionCode].txt`

### Step 2: Bump Version

**File**: `android/simpleRecord/app/build.gradle.kts`

```kotlin
versionCode = 123  // +1
versionName = "1.x.x"
```

### Step 3: Commit and Create Git Tag

```bash
git add android/simpleRecord/app/build.gradle.kts
git commit -m "chore(android): bump version to 1.x.x

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"

git tag android-v1.x.x
git push origin main && git push origin android-v1.x.x
```

### Step 4 & 5: Build and Upload

```bash
cd android/simpleRecord
launchpad android build
launchpad android upload
```

---

## Quick Reference

### iOS One-liner

```bash
launchpad ios build && \
launchpad ios upload && \
launchpad ios metadata && \
launchpad ios screenshots --overwrite && \
launchpad ios submit
```

### Android One-liner

```bash
cd android/simpleRecord && launchpad android build && launchpad android upload
```

---

## Environment Variables

### iOS (App Store Connect)
```bash
export APP_STORE_CONNECT_API_KEY_KEY_ID="R2Q4FFAG8D"
export APP_STORE_CONNECT_API_KEY_ISSUER_ID="3cc1c923-009c-4963-a9db-83d030e4c4e3"
export APP_STORE_CONNECT_API_KEY_CONTENT="$(cat /Users/entaku/.appstoreconnect/private_keys/AuthKey_R2Q4FFAG8D.p8)"
```

### Android (Google Play)
- `play-store-credentials.json` をプロジェクトルートに配置
- `app-keys/key.properties` にキーストア情報を設定

---

## Common Issues

### iOS

**Build fails**: Clean build folder → `rm -rf build/VoiLog.xcarchive`  
**Submit fails "missing required attribute"**: App Store Connect で手動設定 (Step 7 参照)  
**Upload fails "build could not be added"**: Apple 処理中。数分後に `launchpad ios upload` を再実行  
**Keywords too long**: `wc -c fastlane/metadata/*/keywords.txt` で確認（100文字以内）

### Android

**Wrong JDK**: `java -version` → JDK 17 が必要  
**Keystore error**: `app-keys/key.properties` と `app-keys/SimpleRecord.keystore` を確認  
**Upload fails**: `play-store-credentials.json` と Google Play Console API 権限を確認

---

## References

See `CLAUDE.md` for architecture overview and development guidelines.
