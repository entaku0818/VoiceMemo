---
name: voilog-tca-development
description: Guide TCA (The Composable Architecture) development for VoiLog iOS app including @ObservableState, @ViewAction, delegate patterns, and TestStore testing. Use when implementing new features, modifying TCA reducers, writing tests, or asking about VoiLog architecture patterns.
metadata:
  author: VoiLog Team
  version: 1.0.0
  category: development
  tags: [tca, swiftui, ios, voilog]
---

# VoiLog TCA Development

## Quick Start

VoiLog uses modern TCA patterns with `@ObservableState` and `@ViewAction`.

### Feature Template Location
Start with: `/ios/VoiLog/Template/FeatureTemplate.swift`

### Modern Architecture Files
**Primary locations** (PREFERRED for modifications):
- Recording: `/ios/VoiLog/Recording/RecordingFeature.swift`
- Playback: `/ios/VoiLog/Playback/PlaybackFeature.swift`
- App Coordinator: `/ios/VoiLog/DebugMode/DebugModeFeature.swift` (VoiceAppFeature)

**Legacy location** (AVOID modifications):
- `/ios/VoiLog/Voice/` - Legacy production code

## Instructions

### Step 1: Choose the Right Architecture

**For new features or modifications:**
1. Use Modern Architecture (`/ios/VoiLog/Recording`, `/Playback`, `/DebugMode`)
2. Follow the tab-based pattern with `VoiceAppFeature`
3. Implement delegate pattern for inter-feature communication

**Never modify:**
- Files in `/ios/VoiLog/Voice/` directory (Legacy)

### Step 2: Create New Feature

```swift
@Reducer
struct MyFeature {
  @ObservableState
  struct State: Equatable {
    var isLoading = false
    // Add your state properties
  }

  enum Action: ViewAction {
    case view(View)
    case delegate(Delegate)

    enum View {
      case onAppear
      case buttonTapped
    }

    enum Delegate {
      case completed(Result)
    }
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(.onAppear):
        // Implementation
        return .none

      case .view(.buttonTapped):
        // Send delegate action to parent
        return .send(.delegate(.completed(.success)))

      case .delegate:
        return .none
      }
    }
  }
}
```

### Step 3: Integrate with VoiceAppFeature

For features that need tab switching:

```swift
// In VoiceAppFeature
case .recording(.delegate(.recordingCompleted)):
  state.selectedTab = 1 // Switch to playback tab
  return .send(.playback(.reloadData))
```

### Step 4: Write Tests

```swift
@Test
func testRecordingCompletion() async {
  let store = TestStore(initialState: MyFeature.State()) {
    MyFeature()
  }

  await store.send(.view(.buttonTapped)) {
    $0.isLoading = true
  }

  await store.receive(.delegate(.completed(.success)))
}
```

## Common Patterns

### Pattern 1: Repository Integration

```swift
@Dependency(\.voiceMemoRepository) var repository

// In reducer
case .view(.saveData):
  return .run { [data = state.data] send in
    try await repository.save(data)
    await send(.delegate(.saved))
  }
```

### Pattern 2: Auto Tab Switching

See `/ios/VoiLog/DebugMode/DebugModeFeature.swift` for reference:
- Recording completion → Auto switch to playback tab
- Use `selectedTab` state
- Send `reloadData` action to target tab

## Troubleshooting

### Error: State not updating in View
**Cause**: Forgot `@ObservableState` macro
**Solution**: Add `@ObservableState` to State struct

### Error: Action not recognized
**Cause**: Using old `WithViewStore` pattern
**Solution**: Use `@ViewAction` pattern instead

## References

For detailed examples:
- Recording Feature: `/ios/VoiLog/Recording/RecordingFeature.swift`
- Playback Feature: `/ios/VoiLog/Playback/PlaybackFeature.swift`
- App Coordinator: `/ios/VoiLog/DebugMode/DebugModeFeature.swift`
- Official TCA Docs: https://github.com/pointfreeco/swift-composable-architecture
