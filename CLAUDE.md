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
- **Root State**: `VoiceMemos` is the main app reducer
- **Feature Modules**: Each major feature has its own TCA reducer (Recording, Playback, Playlists)
- **Dependencies**: Structured dependency injection for testability

### Core Features Structure
```
/VoiLog/Voice/           # Main voice recording/playback features
├── VoiceMemos.swift     # Root app state management
├── RecordingMemo.swift  # Recording state and UI
├── VoiceMemoReducer.swift # Individual memo management
└── Audio*.swift         # Audio processing components

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

### Audio Recording Flow
1. **Recording Start**: `RecordingMemo` manages recording state
2. **Completion**: Delegate pattern notifies `VoiceMemos` parent
3. **Data Persistence**: Repository saves to Core Data and Documents
4. **UI Update**: New memo automatically appears in list (reactive state)

### Current Mode Switching
- **Recording Mode**: Shows recording UI and controls
- **Playback Mode**: Shows list of recorded memos with playback controls
- **Shared State**: Both modes use same `voiceMemos` array

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
4. Add navigation from parent feature
5. Write TestStore tests

### Audio Recording Modifications
- **Core Implementation**: `AudioRecoder.swift` handles recording
- **State Management**: `RecordingMemo.swift` manages recording UI state
- **Interruption Handling**: Built-in support for calls, alarms, notifications
- **Testing**: Use comprehensive test checklist in `AUDIO_RECORDING_TESTS.md`

### Data Model Changes
1. Modify `Voice.xcdatamodeld` Core Data model
2. Update `VoiceMemoCoredataAccessor.swift` data access methods
3. Update repository methods in `VoiceMemoRepository.swift`
4. Update TCA state structs accordingly
5. Handle data migration if needed

### UI Development
- **SwiftUI + TCA**: Use `WithViewStore` for state observation
- **View Actions**: Use `@ViewAction` pattern for user interactions
- **Navigation**: Programmatic navigation via TCA state
- **Presentation**: Sheets and alerts managed by `@PresentationState`