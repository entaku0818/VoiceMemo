---
name: voilog-release-checklist
description: Step-by-step release checklist for VoiLog iOS and Android app submission to App Store and Google Play. Use when preparing release, updating version, submitting to app stores, creating release, or mentioning App Store or Google Play submission.
metadata:
  author: VoiLog Team
  version: 1.0.0
  category: deployment
  tags: [release, fastlane, app-store, google-play]
---

# VoiLog Release Checklist

**IMPORTANT**: Complete ALL steps before App Store or Google Play submission.

## Workflow: iOS Release

Copy this checklist and check off items as you complete them:

```
iOS Release Progress:
- [ ] Step 1: Update release notes (ja + en-US)
- [ ] Step 2: Bump version in project.pbxproj
- [ ] Step 3: Create git tag
- [ ] Step 4: Archive and upload via Xcode
- [ ] Step 5: Run fastlane upload_metadata
- [ ] Step 6: Verify submission
```

### Step 1: Update Release Notes

**Files to update:**
- `fastlane/metadata/ja/release_notes.txt`
- `fastlane/metadata/en-US/release_notes.txt`

**Format:**
```
バージョン 1.x.x
・新機能の説明
・改善点
・バグ修正
```

### Step 2: Bump Version

**File**: `ios/VoiLog.xcodeproj/project.pbxproj`

Update `MARKETING_VERSION`:
```bash
# Find current version
grep "MARKETING_VERSION" ios/VoiLog.xcodeproj/project.pbxproj

# Update to new version (e.g., 1.2.0)
```

### Step 3: Create Git Tag

```bash
git add fastlane/metadata/
git add ios/VoiLog.xcodeproj/project.pbxproj
git commit -m "chore: bump version to 1.x.x

- Update release notes
- Increment version number

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

git tag v1.x.x
git push origin main
git push origin v1.x.x
```

### Step 4: Archive via Xcode

1. Open `ios/VoiLog.xcodeproj` in Xcode
2. Select **VoiLog** scheme (NOT VoiLogDevelop)
3. Product → Archive
4. Distribute App → App Store Connect
5. Wait for upload completion

### Step 5: Run Fastlane

```bash
bundle exec fastlane upload_metadata
```

This will:
- Upload metadata and screenshots
- Submit for review automatically

### Step 6: Verify

Check App Store Connect:
- Version number correct
- Release notes visible
- Status: "Waiting for Review"

## Workflow: Android Release

```
Android Release Progress:
- [ ] Step 1: Update release notes in Play Console
- [ ] Step 2: Bump versionCode and versionName
- [ ] Step 3: Create git tag
- [ ] Step 4: Build release APK
- [ ] Step 5: Run fastlane upload_production
- [ ] Step 6: Verify submission
```

### Step 1: Update Release Notes

Update in Google Play Console or fastlane metadata

### Step 2: Bump Version

**File**: `android/simpleRecord/app/build.gradle.kts`

```kotlin
versionCode = 123  // Increment by 1
versionName = "1.x.x"  // Update semantic version
```

### Step 3: Create Git Tag

```bash
git add android/simpleRecord/app/build.gradle.kts
git commit -m "chore(android): bump version to 1.x.x

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

git tag android-v1.x.x
git push origin main
git push origin android-v1.x.x
```

### Step 4: Build Release

```bash
cd android/simpleRecord
./gradlew assembleRelease
```

### Step 5: Upload with Fastlane

```bash
cd android/simpleRecord
bundle exec fastlane upload_production
```

### Step 6: Verify

Check Google Play Console:
- Version uploaded
- Release notes visible
- Status: "In Review"

## Common Issues

### Issue: Fastlane authentication fails
**Solution**:
1. Check FASTLANE_USER environment variable
2. Verify App Store Connect API key
3. Run `fastlane fastlane-credentials add --username your@email.com`

### Issue: Archive build fails
**Solution**:
1. Clean build folder: Product → Clean Build Folder
2. Update Swift packages: `xcodebuild -resolvePackageDependencies`
3. Check SwiftLint errors: `cd ios && swiftlint`

### Issue: Git tag already exists
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

## References

See `CLAUDE.md` for:
- Full command reference
- Environment variables
- Fastlane lanes documentation
