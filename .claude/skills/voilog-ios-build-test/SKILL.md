---
name: voilog-ios-build-test
description: Automate VoiLog iOS build and test workflows using xcodebuild, SwiftLint, and bundle commands. Use when building iOS app, running tests, performing code quality checks, or asking about xcodebuild commands.
metadata:
  author: VoiLog Team
  version: 1.0.0
  category: development
  tags: [ios, xcodebuild, swiftlint, testing]
---

# VoiLog iOS Build & Test

## Quick Commands Reference

### Setup Dependencies
```bash
bundle install
```

### Build for Development
```bash
xcodebuild -project ios/VoiLog.xcodeproj \
  -scheme VoiLogDevelop \
  -configuration Debug
```

### Build for Production
```bash
xcodebuild -project ios/VoiLog.xcodeproj \
  -scheme VoiLog \
  -configuration Release
```

### Run All Tests
```bash
xcodebuild test \
  -project ios/VoiLog.xcodeproj \
  -scheme VoiLogTests \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Run Specific Test Class
```bash
xcodebuild test \
  -project ios/VoiLog.xcodeproj \
  -scheme VoiLogTests \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:VoiLogTests/PlaylistListFeatureTests
```

### Code Quality Checks
```bash
cd ios
swiftlint --fix  # Auto-fix issues
swiftlint        # Check for violations
```

## Workflow: Pre-Commit Checks

Run these commands before committing code:

```
Pre-Commit Checklist:
- [ ] Run SwiftLint fix
- [ ] Run SwiftLint check
- [ ] Run relevant tests
- [ ] Verify build succeeds
```

### Step 1: Auto-fix SwiftLint Issues
```bash
cd ios && swiftlint --fix
```

### Step 2: Check for Remaining Violations
```bash
cd ios && swiftlint
```

### Step 3: Run Relevant Tests
```bash
# For feature changes, run specific test class
xcodebuild test \
  -project ios/VoiLog.xcodeproj \
  -scheme VoiLogTests \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:VoiLogTests/YourFeatureTests
```

### Step 4: Verify Build
```bash
xcodebuild -project ios/VoiLog.xcodeproj \
  -scheme VoiLogDevelop \
  -configuration Debug
```

## Common Test Patterns

### TCA TestStore Pattern
```swift
@Test
func testFeature() async {
  let store = TestStore(initialState: Feature.State()) {
    Feature()
  }

  await store.send(.view(.buttonTapped)) {
    $0.isLoading = true
  }

  await store.receive(.delegate(.completed))
}
```

### Testing with Dependencies
```swift
@Test
func testWithRepository() async {
  let store = TestStore(initialState: Feature.State()) {
    Feature()
  } withDependencies: {
    $0.voiceMemoRepository = .mock
  }

  await store.send(.view(.loadData))
  await store.receive(.dataLoaded(mockData))
}
```

## Update Swift Packages

```bash
xcodebuild -resolvePackageDependencies -project ios/VoiLog.xcodeproj
```

## Troubleshooting

### Error: Build fails with package resolution error
**Cause**: Corrupted Swift package cache
**Solution**:
```bash
rm -rf ~/Library/Caches/org.swift.swiftpm
xcodebuild -resolvePackageDependencies -project ios/VoiLog.xcodeproj
```

### Error: Tests fail to start simulator
**Cause**: Simulator not available or corrupted state
**Solution**:
```bash
# List available simulators
xcrun simctl list devices

# Reset simulator (in iOS Simulator app)
# Settings → Erase All Content and Settings
```

### Error: SwiftLint not found
**Cause**: SwiftLint not installed or not in PATH
**Solution**:
```bash
# Install via Homebrew
brew install swiftlint

# Or add to PATH if already installed
export PATH="/opt/homebrew/bin:$PATH"
```

### Error: xcodebuild command not found
**Cause**: Xcode Command Line Tools not installed
**Solution**:
```bash
xcode-select --install
```

### Error: "No scheme named 'VoiLogTests'"
**Cause**: Test scheme not properly configured
**Solution**:
1. Open Xcode
2. Product → Scheme → Manage Schemes
3. Verify "VoiLogTests" is checked

## Available Test Schemes

- **VoiLogTests**: All unit tests
- **VoiLogUITests**: UI tests (if available)

## Test Organization

Tests are located in:
- `ios/VoiLogTests/` - Unit tests
- `ios/VoiLogUITests/` - UI tests

Common test files:
- `PlaylistListFeatureTests.swift` - Playlist feature tests
- Add more as needed

## Performance Tips

### Speed up test runs
```bash
# Run tests without code coverage (faster)
xcodebuild test \
  -project ios/VoiLog.xcodeproj \
  -scheme VoiLogTests \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -enableCodeCoverage NO
```

### Parallel testing
```bash
# Enable parallel testing
xcodebuild test \
  -project ios/VoiLog.xcodeproj \
  -scheme VoiLogTests \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -parallel-testing-enabled YES
```

## References

See `CLAUDE.md` for:
- Full xcodebuild command reference
- Available schemes
- SwiftLint configuration
