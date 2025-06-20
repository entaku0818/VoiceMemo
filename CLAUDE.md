# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VoiLog is an iOS voice recording app ("シンプル録音" - Simple Recording) built with SwiftUI and The Composable Architecture (TCA). The app provides audio recording, playback, playlist management, and premium features via in-app purchases.

## Essential Commands

### Development
```bash
# Setup dependencies
bundle install

# Build for development
xcodebuild -project VoiLog.xcodeproj -scheme VoiLogDevelop -configuration Debug

# Run all tests
xcodebuild test -project VoiLog.xcodeproj -scheme VoiLogTests -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test -project VoiLog.xcodeproj -scheme VoiLogTests -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:VoiLogTests/PlaylistListFeatureTests

# Code quality checks
swiftlint --fix && swiftlint
```

### Deployment (Fastlane)
```bash
# Upload to App Store Connect with metadata and submission
bundle exec fastlane upload_metadata

# List all available Fastlane lanes
bundle exec fastlane lanes
```

### Package Management
```bash
# Update Swift packages
xcodebuild -resolvePackageDependencies -project VoiLog.xcodeproj

# Clean package cache if needed
rm -rf ~/Library/Caches/org.swift.swiftpm
```

## Architecture Overview

### State Management: The Composable Architecture (TCA) v1.8.0
- **Modern Patterns**: Uses `@ObservableState` and `@ViewAction` patterns
- **Dual Architecture**: Legacy `VoiceMemos` (production) + Modern `VoiceAppFeature` (debug/development)
- **Feature Modules**: Each major feature has its own TCA reducer (Recording, Playback, Playlists)
- **Dependencies**: Structured dependency injection for testability

### Core Features Structure
```
/VoiLog/Voice/           # Legacy voice recording/playback features (AVOID MODIFYING)
├── VoiceMemos.swift     # Legacy root app state management
├── RecordingMemo.swift  # Legacy recording state and UI
├── VoiceMemoReducer.swift # Individual memo management
└── Audio*.swift         # Audio processing components

/VoiLog/Recording/       # Modern recording architecture
└── RecordingFeature.swift # New TCA recording feature with delegate pattern

/VoiLog/Playback/        # Modern playback architecture  
└── PlaybackFeature.swift # New TCA playback feature with data management

/VoiLog/DebugMode/       # Main app coordinator (PREFERRED FOR MODIFICATIONS)
└── DebugModeFeature.swift # VoiceAppFeature - coordinates Recording/Playback

/VoiLog/Playlist/        # Playlist management features
├── PlaylistListFeature.swift # TCA feature implementation
└── PlaylistListView.swift    # SwiftUI views

/VoiLog/data/           # Data layer with repository pattern
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
- **ComposableArchitecture** (1.8.0): State management
- **Firebase** (10.28.0): Analytics and Crashlytics
- **RevenueCat** (4.40.0): In-app purchase management
- **Google Mobile Ads** (11.5.0): Advertisement integration
- **Rollbar** (3.3.3): Error tracking

## Development Patterns

### TCA Feature Development
1. **Use Templates**: Start with `/VoiLog/Template/FeatureTemplate.swift` for new features
2. **State Structure**: Follow `@ObservableState struct State` pattern
3. **Action Organization**: Use nested Action enums with Delegate pattern
4. **Testing**: Write TestStore tests for all reducers

### Code Organization
- **Feature Modules**: Group related functionality in directories
- **Repository Pattern**: Keep Core Data operations abstracted
- **Protocol-Based Design**: Enable testing with mock implementations
- **SwiftUI Patterns**: Use `WithViewStore` for TCA integration

### Testing Strategy
- **Unit Tests**: `VoiLogTests/` with TCA TestStore patterns
- **UI Tests**: `VoiLogUITests/` for end-to-end testing
- **Mock Infrastructure**: Protocol-based mocking in test files
- **Audio Testing**: Comprehensive interrupt handling tests (see `AUDIO_RECORDING_TESTS.md`)

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
- **Configuration**: `.swiftlint.yml` with project-specific rules

## Key Implementation Details

### Dual Architecture Pattern
This project uses **two parallel architectures**:

#### Legacy Architecture (Production - `/Voice`)
- **Entry Point**: `VoiceMemosView` (used in production builds)
- **State Management**: `VoiceMemos` reducer with single shared state
- **Mode Switching**: Toggle between recording/playback modes
- **⚠️ IMPORTANT**: Avoid modifying `/Voice` directory files

#### Modern Architecture (Debug/Development - `/Recording`, `/Playback`, `/DebugMode`)
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
1. Copy `/VoiLog/Template/FeatureTemplate.swift`
2. Rename `FeatureReducer` and `FeatureView` to your feature name
3. Implement `State`, `Action`, and `body` reducer logic
4. **For Modern Architecture**: Add to `VoiceAppFeature` as a Scope
5. Write TestStore tests

### Modifying Recording/Playback Features
**⚠️ IMPORTANT**: Use Modern Architecture only

#### For Recording Changes:
- **Primary File**: `/VoiLog/Recording/RecordingFeature.swift`
- **Delegate Pattern**: Send results via `recordingCompleted` delegate action
- **Auto-Integration**: `VoiceAppFeature` handles tab switching and data sync

#### For Playback Changes:
- **Primary File**: `/VoiLog/Playback/PlaybackFeature.swift`
- **Data Loading**: Use `reloadData` action for refresh functionality
- **Repository Integration**: Access via `voiceMemoRepository` dependency

#### For App-Level Coordination:
- **Primary File**: `/VoiLog/DebugMode/DebugModeFeature.swift` (`VoiceAppFeature`)
- **Tab Management**: Control via `selectedTab` state
- **Inter-Feature Communication**: Use delegate actions and effect coordination

### Audio Recording Core Modifications
- **Core Implementation**: `AudioRecoder.swift` handles recording (shared by both architectures)
- **Interruption Handling**: Built-in support for calls, alarms, notifications
- **Testing**: Use comprehensive test checklist in `AUDIO_RECORDING_TESTS.md`

### Data Model Changes
1. Modify `Voice.xcdatamodeld` Core Data model
2. Update `VoiceMemoCoredataAccessor.swift` data access methods
3. Update repository methods in `VoiceMemoRepository.swift`
4. Update TCA state structs accordingly
5. Handle data migration if needed

### UI Development
- **Modern TCA Patterns**: Use `@ViewAction` and `@ObservableState` (preferred)
- **Legacy Patterns**: `WithViewStore` (only for `/Voice` directory)
- **View Actions**: Use `@ViewAction` pattern for user interactions
- **Navigation**: Programmatic navigation via TCA state
- **Presentation**: Sheets and alerts managed by `@PresentationState`

## Development Guidelines

### Architecture Decision Rules
1. **New Features**: Always use Modern Architecture (`/Recording`, `/Playback`, `/DebugMode`)
2. **Bug Fixes**: 
   - For production issues: Fix in Legacy Architecture (`/Voice`)
   - For new features: Fix in Modern Architecture
3. **Refactoring**: Gradually migrate functionality from Legacy to Modern

### Recent Implementations (Reference Examples)
- **Auto Tab Switching**: See `VoiceAppFeature` in `DebugModeFeature.swift` (Issue #72)
- **Recording Completion Flow**: `RecordingFeature` → `VoiceAppFeature` → `PlaybackFeature` delegation
- **Tab State Management**: `selectedTab` binding with TabView in `VoiceAppView`