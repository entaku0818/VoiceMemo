# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VoiLog is a cross-platform voice recording app ("シンプル録音" - Simple Recording) available on iOS and Android.

- **iOS**: Built with SwiftUI and The Composable Architecture (TCA). Provides audio recording, playback, playlist management, and premium features via in-app purchases.
- **Android**: Built with Kotlin and Jetpack Compose. Located in `android/simpleRecord/`.

## TCA Resources

- **Official TCA Collection**: https://www.pointfree.co/collections/composable-architecture
- **GitHub Repository**: https://github.com/pointfreeco/swift-composable-architecture

## Essential Commands

### iOS Development
```bash
# Setup dependencies
bundle install

# Build for development
xcodebuild -project ios/VoiLog.xcodeproj -scheme VoiLogDevelop -configuration Debug

# Run all tests
xcodebuild test -project ios/VoiLog.xcodeproj -scheme VoiLogTests -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test -project ios/VoiLog.xcodeproj -scheme VoiLogTests -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:VoiLogTests/PlaylistListFeatureTests

# Code quality checks
cd ios && swiftlint --fix && swiftlint
```

### Android Development
```bash
# Build debug APK
cd android/simpleRecord && ./gradlew assembleDebug

# Build release APK
cd android/simpleRecord && ./gradlew assembleRelease

# Run tests
cd android/simpleRecord && ./gradlew test

# Clean build
cd android/simpleRecord && ./gradlew clean
```

**Requirements**: JDK 17 (JetBrains Runtime recommended)

### Deployment (Launchpad)

`.launchpadrc` で iOS/Android の設定が管理されている。

```bash
# iOS: ビルド → アップロード → メタデータ → スクリーンショット → 審査提出
launchpad ios build
launchpad ios upload
launchpad ios metadata
launchpad ios screenshots
launchpad ios submit

# Android: ビルド → アップロード
launchpad android build
launchpad android upload
```

### App Store メタデータ運用ルール（2026-06 巻き戻し事故の再発防止）

- **`fastlane/metadata/` が唯一のソース。App Store Connect 上で直接編集しない**（直接編集した場合は即座に同じ値を repo にコミットする）。
- fastlane のリリースレーン `release` は `skip_metadata: true` でメタデータに一切触れない。
- name/subtitle/keywords 等の更新は専用レーンで明示的に行う: `bundle exec fastlane update_metadata`（編集可能バージョンがなければ ASC 上に新規作成される。ストア反映はそのバージョンの審査通過後）。
- 背景: 2026-04 に ASC 直編集した日本語タイトルが、2026-06 のリリース時に deliver で旧値に上書きされ「ボイスメモ」検索順位が20位→67位に急落した。

### Release Checklist
**IMPORTANT: Before submitting to App Store or Google Play, always complete these steps:**

1. **Update Release Notes** (MUST DO BEFORE SUBMISSION)
   - iOS: `fastlane/metadata/ja/release_notes.txt` and `fastlane/metadata/en-US/release_notes.txt`
   - Android: Update in Google Play Console or fastlane metadata
   - Include version number, new features, improvements, and bug fixes

2. **Version Bump**
   - iOS: Update `MARKETING_VERSION` in `ios/VoiLog.xcodeproj/project.pbxproj`
   - Android: Update `versionCode` and `versionName` in `android/simpleRecord/app/build.gradle.kts`

3. **Create Git Tag**
   ```bash
   git tag v1.x.x && git push origin v1.x.x
   ```

4. **Submit**
   - iOS: `launchpad ios build && launchpad ios upload && launchpad ios metadata && launchpad ios screenshots --overwrite && launchpad ios submit`
   - Android: `launchpad android build && launchpad android upload` (from android/simpleRecord/)

### Package Management
```bash
# Update Swift packages
xcodebuild -resolvePackageDependencies -project ios/VoiLog.xcodeproj

# Clean package cache if needed
rm -rf ~/Library/Caches/org.swift.swiftpm
```

## Architecture Overview

### State Management: The Composable Architecture (TCA)
- **Modern Patterns**: Uses `@ObservableState` and `@ViewAction` patterns
- **Dual Architecture**: Legacy `VoiceMemos` (production) + Modern `VoiceAppFeature` (debug/development)
- **Feature Modules**: Each major feature has its own TCA reducer (Recording, Playback, Playlists)
- **Dependencies**: Structured dependency injection for testability

### Core Features Structure
```
/ios/VoiLog/Voice/           # Legacy voice recording/playback features (AVOID MODIFYING)
├── VoiceMemos.swift         # Legacy root app state management
├── RecordingMemo.swift      # Legacy recording state and UI
├── VoiceMemoReducer.swift   # Individual memo management
└── Audio*.swift             # Audio processing components

/ios/VoiLog/Recording/       # Modern recording architecture
└── RecordingFeature.swift   # New TCA recording feature with delegate pattern

/ios/VoiLog/Playback/        # Modern playback architecture
└── PlaybackFeature.swift    # New TCA playback feature with data management

/ios/VoiLog/DebugMode/       # Main app coordinator (PREFERRED FOR MODIFICATIONS)
└── VoiceAppFeature.swift    # VoiceAppFeature - coordinates Recording/Playback

/ios/VoiLog/Playlist/        # Playlist management features
├── PlaylistListFeature.swift # TCA feature implementation
└── PlaylistListView.swift    # SwiftUI views

/ios/VoiLog/data/           # Data layer with repository pattern
├── VoiceMemoRepository.swift      # Main data access layer
├── VoiceMemoCoredataAccessor.swift # Core Data operations
└── UserDefaultsManager.swift      # Settings persistence
```

### Data Layer Architecture
- **Repository Pattern**: `VoiceMemoRepository` abstracts data access
- **Core Data**: Primary storage with `Voice.xcdatamodeld` model
- **iCloud Sync**: Bidirectional synchronization via `CloudUploader`
- **Audio Files**: Stored in Documents directory with URL references

### Key Dependencies
- **ComposableArchitecture**: State management
- **Firebase**: Analytics and Crashlytics
- **RevenueCat**: In-app purchase management
- **Google Mobile Ads**: Advertisement integration
- **Rollbar**: Error tracking

## Development Patterns

### TCA Feature Development
1. **Use Templates**: Start with `/ios/VoiLog/Template/FeatureTemplate.swift` for new features
2. **State Structure**: Follow `@ObservableState struct State` pattern
3. **Action Organization**: Use nested Action enums with Delegate pattern
4. **Testing**: Write TestStore tests for all reducers

### Code Organization
- **Feature Modules**: Group related functionality in directories
- **Repository Pattern**: Keep Core Data operations abstracted
- **Protocol-Based Design**: Enable testing with mock implementations
- **SwiftUI Patterns**: Use `WithViewStore` for TCA integration

### Testing Strategy
- **Unit Tests**: `ios/VoiLogTests/` with TCA TestStore patterns
- **UI Tests**: `ios/VoiLogUITests/` for end-to-end testing
- **Mock Infrastructure**: Protocol-based mocking in test files
- **Audio Testing**: Comprehensive interrupt handling tests

## Build Configuration

### Schemes
- **VoiLogDevelop**: Debug builds with development settings
- **VoiLog**: Production builds for App Store
- **VoiLogTests**: Test-only scheme

### Environment Variables (CI/Release)
```bash
ROLLBAR_KEY="your_rollbar_key"
ADMOB_KEY="your_admob_key"
REVENUECAT_KEY="your_revenuecat_key"
```

### Code Quality
- **SwiftLint**: Automatic fixing and checking integrated in build process
- **Configuration**: `ios/.swiftlint.yml` with project-specific rules

## Key Implementation Details

### Dual Architecture Pattern
This project uses **two parallel architectures**:

#### Legacy Architecture (Production - `/ios/VoiLog/Voice`)
- **Entry Point**: `VoiceMemosView` (used in production builds)
- **State Management**: `VoiceMemos` reducer with single shared state
- **Mode Switching**: Toggle between recording/playback modes
- **⚠️ IMPORTANT**: Avoid modifying `/ios/VoiLog/Voice` directory files

#### Modern Architecture (Debug/Development - `/ios/VoiLog/Recording`, `/Playback`, `/DebugMode`)
- **Entry Point**: `VoiceAppView` with `VoiceAppFeature` coordinator
- **Tab-Based UI**: Separate Recording and Playback tabs
- **Auto-Switch Feature**: Recording completion automatically switches to Playback tab
- **✅ PREFERRED**: Use this architecture for new features and modifications

### Audio Recording Flow (Modern Architecture)
1. **Recording Start**: `RecordingFeature` manages recording state with modern TCA patterns
2. **Completion**: Delegate pattern sends `recordingCompleted` to `VoiceAppFeature`
3. **Auto Tab Switch**: `VoiceAppFeature` automatically switches to playback tab (`selectedTab = 1`)
4. **Data Persistence**: Repository saves to Core Data and Documents
5. **UI Update**: `PlaybackFeature` reloads data and displays new recording

### Tab Management (VoiceAppFeature)
- **Recording Tab** (tag: 0): `RecordingFeature` with recording controls
- **Playback Tab** (tag: 1): `PlaybackFeature` with memo list and playback controls
- **Auto-Switch Logic**: Controlled by `selectedTab` state in `VoiceAppFeature`

### Premium Features
- **RevenueCat Integration**: Subscription and purchase management
- **Feature Gating**: Premium vs free functionality
- **Ad Management**: Google AdMob with premium ad removal

### Internationalization
- **12 Languages**: en, de, es, fr, it, ja, pt-PT, ru, tr, vi, zh-Hans, zh-Hant
- **Localization**: `.xcstrings` format for modern string management
- **Fastlane Metadata**: Multi-language App Store metadata

## Common Development Tasks

### Adding New TCA Feature
1. Copy `/ios/VoiLog/Template/FeatureTemplate.swift`
2. Rename `FeatureReducer` and `FeatureView` to your feature name
3. Implement `State`, `Action`, and `body` reducer logic
4. **For Modern Architecture**: Add to `VoiceAppFeature` as a Scope
5. Write TestStore tests

### Modifying Recording/Playback Features
**⚠️ IMPORTANT**: Use Modern Architecture only

#### For Recording Changes:
- **Primary File**: `/ios/VoiLog/Recording/RecordingFeature.swift`
- **Delegate Pattern**: Send results via `recordingCompleted` delegate action
- **Auto-Integration**: `VoiceAppFeature` handles tab switching and data sync

#### For Playback Changes:
- **Primary File**: `/ios/VoiLog/Playback/PlaybackFeature.swift`
- **Data Loading**: Use `reloadData` action for refresh functionality
- **Repository Integration**: Access via `voiceMemoRepository` dependency

#### For App-Level Coordination:
- **Primary File**: `/ios/VoiLog/DebugMode/VoiceAppFeature.swift` (`VoiceAppFeature`)
- **Tab Management**: Control via `selectedTab` state
- **Inter-Feature Communication**: Use delegate actions and effect coordination

### Audio Recording Core Modifications
- **Core Implementation**: `ios/VoiLog/Voice/AudioRecoder.swift` handles recording (shared by both architectures)
- **Interruption Handling**: Built-in support for calls, alarms, notifications

### Data Model Changes
1. Modify `Voice.xcdatamodeld` Core Data model
2. Update `VoiceMemoCoredataAccessor.swift` data access methods
3. Update repository methods in `VoiceMemoRepository.swift`
4. Update TCA state structs accordingly
5. Handle data migration if needed

### UI Development
- **Modern TCA Patterns**: Use `@ViewAction` and `@ObservableState` (preferred)
- **Legacy Patterns**: `WithViewStore` (only for `/ios/VoiLog/Voice` directory)
- **View Actions**: Use `@ViewAction` pattern for user interactions
- **Navigation**: Programmatic navigation via TCA state
- **Presentation**: Sheets and alerts managed by `@PresentationState`

## Development Guidelines

### Architecture Decision Rules
1. **New Features**: Always use Modern Architecture (`/ios/VoiLog/Recording`, `/Playback`, `/DebugMode`)
2. **Bug Fixes**:
   - For production issues: Fix in Legacy Architecture (`/ios/VoiLog/Voice`)
   - For new features: Fix in Modern Architecture
3. **Refactoring**: Gradually migrate functionality from Legacy to Modern

## Development Tools

### Peekaboo Integration
Peekaboo is available for capturing and analyzing UI screenshots during development:

```bash
# Capture and analyze VoiLog screens
peekaboo --app "VoiLog" --analyze "このUIの改善点を提案してください"

# Capture specific window
peekaboo --app "VoiLog" --window-title "録音" --path ~/Desktop/recording-ui.png

# Check implementation results
peekaboo --app "Simulator" --analyze "実装した機能が正しく動作しているか確認してください"

# Debug error screens
peekaboo --app "Xcode" --analyze "表示されているエラーの解決方法を提案してください"
```

### Recent Implementations (Reference Examples)
- **Auto Tab Switching**: See `VoiceAppFeature` in `VoiceAppFeature.swift` (Issue #72)
- **Recording Completion Flow**: `RecordingFeature` → `VoiceAppFeature` → `PlaybackFeature` delegation
- **Tab State Management**: `selectedTab` binding with TabView in `VoiceAppView`

## ループ運用（Loop Engineering）

このリポジトリは memo リポジトリのプロダクトループ（企画→開発→リリース→効果測定→再企画）の対象。
ここで働くエージェントは以下の規律に従う。

### 起点
- 実装するのは**ユーザーが起票した issue、または `loop-go` ラベル付き issue のみ**。勝手に仕事を選ばない
- 提案がある場合は実装せず、issue コメントか報告として出す

### ハーネス（検証ゲート）
- 実装は build / test / lint が緑になるまで自己修正する（コマンド: iOS: `xcodebuild test -project ios/VoiLog.xcodeproj -scheme VoiLogTests -destination 'platform=iOS Simulator,name=iPhone 15'` および `cd ios && swiftlint --fix && swiftlint` / Android: `cd android/simpleRecord && ./gradlew test`）
- **緑でない変更を main に入れない**。5回で緑にならなければブランチに残して報告
- 完了報告には実行した検証コマンドと実出力を含める（「たぶん動く」は完了ではない）

### エスカレーション（諦め方の設計）
- 同一 issue に2回挑戦して解けない → `loop-attempted` ラベルを付けて人間へ
- スコープが当初依頼から拡大しそう → 黙って続けず「続けると+N時間 / 切り出すと今すぐ完了」の2択を提示
- 製品挙動の判断（仕様の分かれ道）に当たった → 勝手に決めず、選択肢と推奨を添えて人間へ

### タイムボックス
- 軽微修正30分・機能実装2時間が目安。超える見込みなら途中で現状報告し分割を提案する
- 深い修理（テストスイート全体・インフラ）は issue 化して夜間ループに回すのがデフォルト

### 記録（Persistence）
- 非自明な発見・設計判断は issue かコミットメッセージに残す（次のエージェントの Discovery 入力になる）
- 機能リリース時は対応する提案の「答え合わせキー」をリリースノートに含める（リリース+7日で memo のループが KPI 答え合わせをする）