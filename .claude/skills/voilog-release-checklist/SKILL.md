---
name: voilog-release-checklist
description: Step-by-step release checklist for VoiLog iOS and Android app submission to App Store and Google Play. Use when preparing release, updating version, submitting to app stores, creating release, or mentioning App Store or Google Play submission.
metadata:
  author: VoiLog Team
  version: 2.1.0
  category: deployment
  tags: [release, fastlane, app-store, google-play, ios, android]
---

# VoiLog Release Checklist

**IMPORTANT**: Complete ALL steps before App Store or Google Play submission.

## Prerequisites

### iOS Requirements
- Xcode installed
- `bundle install` completed
- App Store Connect API Key configured (environment variables)
- Apple Developer account access

### Android Requirements
- JDK 17 installed (`java -version`)
- `bundle install` completed
- Google Play Console API Key (`play-store-credentials.json`)
- Signing keystore (`app-keys/SimpleRecord.keystore`)

---

## Workflow: iOS Release

Copy this checklist and check off items as you complete them:

```
iOS Release Progress:
- [ ] Step 1: Update release notes (ja + en-US + all languages)
- [ ] Step 2: Bump version in project.pbxproj
- [ ] Step 3: Commit and create git tag
- [ ] Step 4: Archive and upload to App Store Connect
- [ ] Step 5: Run fastlane upload_metadata
- [ ] Step 5.1: Configure App Store Connect (if needed)
- [ ] Step 6: Verify submission
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

Update `MARKETING_VERSION`:
```bash
# Find current version
grep "MARKETING_VERSION" ios/VoiLog.xcodeproj/project.pbxproj

# Update to new version (e.g., 1.3.1 → 1.3.2)
# Edit the file directly or use sed
```

### Step 3: Commit and Create Git Tag

```bash
git add fastlane/metadata/
git add fastlane/screenshots/ # if screenshots changed
git add ios/VoiLog.xcodeproj/project.pbxproj
git commit -m "chore: bump version to 1.x.x

- Update release notes
- Increment version number

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

git tag v1.x.x
git push origin main
git push origin v1.x.x
```

### Step 4: Archive and Upload to App Store Connect

**Option A: Via Command Line (Recommended)**

Complete workflow in one go:
```bash
# 1. Create ExportOptions.plist
cat > /tmp/ExportOptions.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>destination</key>
    <string>upload</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>4YZQY4C47E</string>
</dict>
</plist>
EOF

# 2. Create archive and upload
xcodebuild -project ios/VoiLog.xcodeproj \
  -scheme VoiLog \
  -configuration Release \
  -archivePath build/VoiLog.xcarchive \
  archive && \
xcodebuild -exportArchive \
  -archivePath build/VoiLog.xcarchive \
  -exportOptionsPlist /tmp/ExportOptions.plist \
  -exportPath build/export \
  -allowProvisioningUpdates
```

**Option B: Via Xcode (Alternative)**
1. Open `ios/VoiLog.xcodeproj` in Xcode
2. Select **VoiLog** scheme (NOT VoiLogDevelop)
3. Product → Archive
4. Distribute App → App Store Connect
5. Wait for upload completion

### Step 5: Run Fastlane

```bash
bundle exec fastlane upload_metadata
```

This command will:
- Upload metadata (app description, keywords, etc.)
- Delete old screenshots
- Upload new screenshots from `fastlane/screenshots/`
- Select the latest build
- Attempt to submit for review

**⚠️ IMPORTANT**: If submission fails with "missing required attribute" errors, proceed to Step 5.1.

### Step 5.1: Configure App Store Connect (Manual Setup)

If fastlane submission fails, manually configure these in App Store Connect:

1. Go to https://appstoreconnect.apple.com
2. Navigate to: **マイApp** → **VoiLog** → version 1.x.x → **App情報**
3. Configure required attributes:
   - **advertising**: はい (AdMob使用)
   - **userGeneratedContent**: いいえ
   - **healthOrWellnessTopics**: いいえ
   - **lootBox**: いいえ
   - **parentalControls**: いいえ
   - **ageAssurance**: いいえ
   - **messagingAndChat**: いいえ
   - **gunsOrOtherWeapons**: いいえ
4. Save and click **審査に提出**

**Note**: These attributes are required by Apple but cannot be set via Fastlane API.

### Step 6: Verify Submission

Check App Store Connect:
- ✅ Version number correct (1.x.x)
- ✅ Release notes visible in all languages
- ✅ Screenshots updated (6.9" display)
- ✅ Status: "Waiting for Review"

---

## Workflow: Android Release

```
Android Release Progress:
- [ ] Step 1: Update release notes
- [ ] Step 2: Bump versionCode and versionName
- [ ] Step 3: Commit and create git tag
- [ ] Step 4: Build release AAB/APK
- [ ] Step 5: Upload with fastlane
- [ ] Step 6: Verify submission
```

### Step 1: Update Release Notes

Update in Google Play Console or fastlane metadata directory:
- `fastlane/metadata/android/ja-JP/changelogs/[versionCode].txt`
- `fastlane/metadata/android/en-US/changelogs/[versionCode].txt`

### Step 2: Bump Version

**File**: `android/simpleRecord/app/build.gradle.kts`

```kotlin
versionCode = 123  // Increment by 1 (e.g., 122 → 123)
versionName = "1.x.x"  // Update semantic version (e.g., 1.3.1 → 1.3.2)
```

### Step 3: Commit and Create Git Tag

```bash
git add android/simpleRecord/app/build.gradle.kts
git add fastlane/metadata/android/ # if release notes changed
git commit -m "chore(android): bump version to 1.x.x

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

git tag android-v1.x.x
git push origin main
git push origin android-v1.x.x
```

### Step 4: Build Release

```bash
cd android/simpleRecord

# Clean previous builds
./gradlew clean

# Build release AAB (recommended for Play Store)
./gradlew bundleRelease

# Or build APK
./gradlew assembleRelease
```

Output locations:
- AAB: `app/build/outputs/bundle/release/app-release.aab`
- APK: `app/build/outputs/apk/release/app-release.apk`

### Step 5: Upload with Fastlane

```bash
cd android/simpleRecord

# Upload to internal testing track
bundle exec fastlane internal

# Upload to closed beta track
bundle exec fastlane beta

# Upload to production (本番リリース)
bundle exec fastlane production

# Or upload existing AAB to production
bundle exec fastlane upload_production
```

**Available Fastlane Lanes:**

| Lane | Description |
|------|-------------|
| `build` | Build release AAB |
| `internal` | Deploy to internal testing track |
| `beta` | Deploy to closed beta track |
| `production` | Build and deploy to production |
| `upload_internal` | Upload existing AAB to internal testing |
| `upload_production` | Upload existing AAB to production |

### Step 6: Verify Submission

Check Google Play Console:
- ✅ Version uploaded (versionCode and versionName)
- ✅ Release notes visible
- ✅ Status: "In Review" or "Pending Publication"

---

## Environment Variables

### iOS (App Store Connect)
```bash
export APP_STORE_CONNECT_API_KEY_KEY_ID="R2Q4FFAG8D"
export APP_STORE_CONNECT_API_KEY_ISSUER_ID="your-issuer-id"
export APP_STORE_CONNECT_API_KEY_CONTENT="$(cat AuthKey_R2Q4FFAG8D.p8)"
```

Or configure in `fastlane/Appfile` and use API key file directly.

### Android (Google Play)
- Place `play-store-credentials.json` in project root or `android/simpleRecord/`
- Configure keystore credentials in `app-keys/key.properties`

---

## Common Issues & Troubleshooting

### iOS Issues

#### Issue: Fastlane submission fails with "missing required attribute"
**Error**: `appStoreVersions is not in valid state... missing 'userGeneratedContent', 'advertising', etc.`

**Solution**:
These attributes must be set manually in App Store Connect (cannot be set via Fastlane):
1. Go to App Store Connect web interface
2. Navigate to app version → **App情報**
3. Set all required attributes (see Step 5.1 above)
4. Click **審査に提出**

#### Issue: Archive build fails
**Solution**:
1. Clean build folder: Product → Clean Build Folder (Shift+Cmd+K)
2. Update Swift packages: `xcodebuild -resolvePackageDependencies -project ios/VoiLog.xcodeproj`
3. Check SwiftLint errors: `cd ios && swiftlint`
4. Verify Signing & Capabilities settings in Xcode

#### Issue: Certificate/Provisioning Profile errors
**Solution**:
1. Use automatic signing: set `signingStyle: automatic` in ExportOptions.plist
2. Add `-allowProvisioningUpdates` flag to xcodebuild export command
3. Verify Team ID is correct: `4YZQY4C47E`

#### Issue: Fastlane authentication fails
**Solution**:
1. Check App Store Connect API key environment variables
2. Verify `AuthKey_R2Q4FFAG8D.p8` file exists and is readable
3. Check API key permissions in App Store Connect (Admin or App Manager role)

#### Issue: Screenshots not uploading
**Solution**:
1. Verify screenshot dimensions (6.9" display: 1290x2796 px)
2. Check file naming: `[0-4]_APP_IPHONE_69_[0-4].png`
3. Ensure directories exist for all languages in `fastlane/screenshots/`

### Android Issues

#### Issue: Build fails with wrong JDK version
**Error**: `Unsupported class file major version`

**Solution**:
```bash
# Check current Java version
java -version

# Should be JDK 17 (recommended: JetBrains Runtime)
# Set JAVA_HOME if needed
export JAVA_HOME=/path/to/jdk-17
```

#### Issue: Keystore password error
**Solution**:
1. Verify `app-keys/key.properties` exists and contains correct passwords
2. Check keystore file exists: `app-keys/SimpleRecord.keystore`
3. Test keystore: `keytool -list -keystore app-keys/SimpleRecord.keystore`

#### Issue: Fastlane upload fails
**Solution**:
1. Verify `play-store-credentials.json` exists
2. Check Google Play Console API is enabled
3. Verify service account has correct permissions (Release Manager)

#### Issue: AAB validation fails
**Solution**:
1. Ensure versionCode is incremented from previous release
2. Check signing configuration in `build.gradle.kts`
3. Verify minimum SDK version matches Play Console requirements

### General Issues

#### Issue: Git tag already exists
**Solution**:
```bash
# Delete local tag
git tag -d v1.x.x

# Delete remote tag
git push origin :refs/tags/v1.x.x

# Create new tag
git tag v1.x.x
git push origin v1.x.x
```

#### Issue: Bundle install fails
**Solution**:
```bash
# Update bundler
gem install bundler

# Clean and reinstall
rm Gemfile.lock
bundle install
```

---

## Post-Release Checklist

After successful submission:

- [ ] Create GitHub Release
  ```bash
  gh release create v1.x.x --title "v1.x.x" --latest --notes "$(cat <<'EOF'
  ## iOS
  - 広告システムを最新版にアップデート

  ## Android
  - 変更内容をここに記載
  EOF
  )"
  ```

- [ ] Update CHANGELOG.md (if exists)
- [ ] Announce release to team/users
- [ ] Monitor crash reports (Firebase Crashlytics)
- [ ] Monitor app reviews in store consoles

---

## Quick Reference

### iOS Complete Command-Line Workflow

**Full automation (after version bump and commit):**
```bash
# Create export options
cat > /tmp/ExportOptions.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>destination</key>
    <string>upload</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>4YZQY4C47E</string>
</dict>
</plist>
EOF

# Archive, upload, and submit for review
xcodebuild -project ios/VoiLog.xcodeproj -scheme VoiLog -configuration Release -archivePath build/VoiLog.xcarchive archive && \
xcodebuild -exportArchive -archivePath build/VoiLog.xcarchive -exportOptionsPlist /tmp/ExportOptions.plist -exportPath build/export -allowProvisioningUpdates && \
bundle exec fastlane upload_metadata
```

**Metadata and submission only (after manual archive upload):**
```bash
bundle exec fastlane upload_metadata
```

### Android One-Liner (Full build + upload)
```bash
cd android/simpleRecord && ./gradlew clean bundleRelease && bundle exec fastlane production
```

---

## References

See `CLAUDE.md` for:
- Full command reference
- Architecture overview
- Development guidelines
- Testing procedures
