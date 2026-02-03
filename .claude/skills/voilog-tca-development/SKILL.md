---
name: voilog-tca-development
description: Guide TCA (The Composable Architecture) development for VoiLog iOS app including @ObservableState, @ViewAction, delegate patterns, and TestStore testing. Use when implementing new features, modifying TCA reducers, writing tests, or asking about VoiLog architecture patterns.
metadata:
  author: VoiLog Team
  version: 1.1.0
  category: development
  tags: [tca, swiftui, ios, voilog, testing]
  updated: 2026-02-01
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

See "Testing Patterns" section below for comprehensive test examples.

## Testing Patterns

### Basic TestStore Structure

```swift
import ComposableArchitecture
import Testing

@Test
func testBasicAction() async {
  let store = TestStore(initialState: MyFeature.State()) {
    MyFeature()
  }

  // Send action and verify state changes
  await store.send(.view(.buttonTapped)) {
    $0.isLoading = true
  }

  // Verify delegate action received
  await store.receive(.delegate(.completed))
}
```

### Pattern 1: ViewAction → State Change

```swift
@Test
func testStateChange() async {
  let store = TestStore(initialState: RecordingFeature.State()) {
    RecordingFeature()
  }

  await store.send(.view(.recordButtonTapped)) {
    $0.recordingState = .recording
    $0.isRecordButtonEnabled = false
  }
}
```

### Pattern 2: ViewAction → Delegate Notification

```swift
@Test
func testDelegateNotification() async {
  let store = TestStore(
    initialState: RecordingFeature.State(recordingState: .recording)
  ) {
    RecordingFeature()
  }

  await store.send(.view(.stopButtonTapped)) {
    $0.recordingState = .stopped
  }

  await store.receive(.delegate(.recordingCompleted))
}
```

### Pattern 3: Testing with Dependencies

```swift
@Test
func testWithRepository() async {
  let mockMemo = VoiceMemo(
    id: UUID(),
    title: "Test Memo",
    duration: 60.0
  )

  let store = TestStore(initialState: PlaybackFeature.State()) {
    PlaybackFeature()
  } withDependencies: {
    $0.voiceMemoRepository = .mock(
      fetchAll: { [mockMemo] }
    )
  }

  await store.send(.view(.onAppear))
  await store.receive(.memosLoaded([mockMemo])) {
    $0.memos = [mockMemo]
  }
}
```

### Pattern 4: Async Operations

```swift
@Test
func testAsyncOperation() async {
  let store = TestStore(initialState: MyFeature.State()) {
    MyFeature()
  }

  await store.send(.view(.loadData)) {
    $0.isLoading = true
  }

  await store.receive(.dataLoadComplete(result: .success(data))) {
    $0.isLoading = false
    $0.data = data
  }
}
```

### Pattern 5: Timer and Debounce

```swift
@Test
func testWithTimer() async {
  let clock = TestClock()

  let store = TestStore(initialState: MyFeature.State()) {
    MyFeature()
  } withDependencies: {
    $0.continuousClock = clock
  }

  await store.send(.view(.startTimer)) {
    $0.isTimerRunning = true
  }

  await clock.advance(by: .seconds(1))
  await store.receive(.timerTicked) {
    $0.elapsedTime = 1
  }
}
```

### Pattern 6: Error Handling

```swift
@Test
func testErrorHandling() async {
  let store = TestStore(initialState: MyFeature.State()) {
    MyFeature()
  } withDependencies: {
    $0.voiceMemoRepository = .mock(
      fetchAll: { throw TestError.networkError }
    )
  }

  await store.send(.view(.loadData))
  await store.receive(.loadFailed(TestError.networkError)) {
    $0.errorMessage = "Network error"
  }
}
```

## Test Execution Commands

### Run all tests
```bash
xcodebuild test \
  -project ios/VoiLog.xcodeproj \
  -scheme VoiLogTests \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Run specific test class
```bash
xcodebuild test \
  -project ios/VoiLog.xcodeproj \
  -scheme VoiLogTests \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:VoiLogTests/PlaylistListFeatureTests
```

## Common Test Mistakes

### Mistake 1: Missing State Verification
```swift
// ❌ Bad: State changes but not verified
await store.send(.view(.buttonTapped))

// ✅ Good: All state changes verified
await store.send(.view(.buttonTapped)) {
  $0.isLoading = true
  $0.buttonTitle = "Loading..."
}
```

### Mistake 2: Missing Action Reception
```swift
// ❌ Bad: Delegate action sent but not verified
await store.send(.view(.complete))

// ✅ Good: All received actions verified
await store.send(.view(.complete))
await store.receive(.delegate(.completed))
```

### Mistake 3: Wrong Order
```swift
// ❌ Bad: Wrong reception order
await store.receive(.second)
await store.receive(.first)

// ✅ Good: Correct order
await store.receive(.first)
await store.receive(.second)
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

### Test Error: "Expected state to change but it did not"
**Cause**: State mutation block provided but state didn't change
**Solution**: Either remove the mutation block or ensure state actually changes

```swift
// ❌ Bad: Expects state change but none occurs
await store.send(.view(.noOp)) {
  $0.value = newValue  // But reducer doesn't change this
}

// ✅ Good: No mutation block if no state change
await store.send(.view(.noOp))
```

### Test Error: "Received unexpected action"
**Cause**: Reducer sent an action that wasn't verified in test
**Solution**: Add `await store.receive()` for all emitted actions

```swift
// ❌ Bad: Missing receive
await store.send(.view(.load))
// Test fails: Unexpected .loadComplete action

// ✅ Good: Verify all received actions
await store.send(.view(.load))
await store.receive(.loadComplete)
```

### Test Error: "TestStore skipped receiving actions"
**Cause**: Actions received in wrong order or not at all
**Solution**: Verify actions in the exact order they're emitted

```swift
// ❌ Bad: Wrong order
await store.receive(.second)
await store.receive(.first)

// ✅ Good: Correct order
await store.receive(.first)
await store.receive(.second)
```

### Test hangs or times out
**Cause**: Waiting for an action that never comes
**Solution**:
1. Verify the reducer actually sends the expected action
2. Check if async operations completed
3. Use `store.exhaustivity = .off` for debugging (not recommended for final tests)

## References

For detailed examples:
- Recording Feature: `/ios/VoiLog/Recording/RecordingFeature.swift`
- Playback Feature: `/ios/VoiLog/Playback/PlaybackFeature.swift`
- App Coordinator: `/ios/VoiLog/DebugMode/DebugModeFeature.swift`
- Official TCA Docs: https://github.com/pointfreeco/swift-composable-architecture
