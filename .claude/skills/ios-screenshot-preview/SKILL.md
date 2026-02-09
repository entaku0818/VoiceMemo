---
name: ios-screenshot-preview
description: Add screenshot preview feature to iOS debug menu for App Store screenshots. Use when adding multi-language screenshot preview functionality, testing localization, or preparing App Store submissions.
metadata:
  author: VoiLog Team
  version: 1.0.0
  category: ui-development
  tags: [ios, swiftui, screenshots, localization, debug]
---

# iOS Screenshot Preview Feature

Add a screenshot preview feature to your iOS app's debug menu. This allows you to preview app screens in different languages before taking App Store screenshots.

## When to Use

- Preparing App Store screenshots in multiple languages
- Testing localization across different screens
- Quickly previewing UI in all supported languages
- Creating marketing materials with consistent UI

## Quick Start

### 1. Create ScreenshotPreviewView.swift

Create a new file in your project's debug directory (e.g., `ios/YourApp/DebugMode/ScreenshotPreviewView.swift`):

```swift
import SwiftUI

#if DEBUG
// MARK: - Screenshot Preview Feature
struct ScreenshotPreviewView: View {
    @State private var selectedLanguage: AppLanguage?

    var body: some View {
        NavigationStack {
            List {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    Button(action: {
                        selectedLanguage = language
                    }) {
                        HStack {
                            Text(language.displayName)
                                .font(.headline)
                            Spacer()
                            Text(language.appTitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Select Language")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(item: $selectedLanguage) { language in
                FullscreenScreenshotView(language: language, onDismiss: {
                    selectedLanguage = nil
                })
            }
        }
    }
}

// MARK: - Fullscreen Screenshot View
struct FullscreenScreenshotView: View {
    let language: AppLanguage
    let onDismiss: () -> Void
    @State private var selectedTab = 0
    @State private var dragOffset: CGSize = .zero

    private var isLastTab: Bool {
        selectedTab == ScreenshotScreen.allCases.count - 1
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Array(ScreenshotScreen.allCases.enumerated()), id: \.element) { index, screen in
                screenPreview(for: screen)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(edges: [])
        .offset(x: isLastTab ? dragOffset.width : 0, y: dragOffset.height)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = CGSize(width: 0, height: value.translation.height)
                    } else if isLastTab && value.translation.width > 0 {
                        dragOffset = CGSize(width: value.translation.width, height: 0)
                    }
                }
                .onEnded { value in
                    if value.translation.height > 150 {
                        onDismiss()
                    } else if isLastTab && value.translation.width > 150 {
                        onDismiss()
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = .zero
                        }
                    }
                }
        )
    }

    @ViewBuilder
    private func screenPreview(for screen: ScreenshotScreen) -> some View {
        switch screen {
        case .mainScreen:
            MockMainScreenView(language: language)
        case .listScreen:
            MockListScreenView(language: language)
        // Add more screens as needed
        }
    }
}

// MARK: - Language Enum
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case japanese = "ja"
    // Add more languages

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "EN"
        case .japanese: return "JA"
        }
    }

    var appTitle: String {
        switch self {
        case .english: return "Your App Name"
        case .japanese: return "あなたのアプリ名"
        }
    }
}

// MARK: - Screenshot Screen Enum
enum ScreenshotScreen: String, CaseIterable {
    case mainScreen
    case listScreen
    // Add more screen types
}

// MARK: - Mock Views
struct MockMainScreenView: View {
    let language: AppLanguage

    var body: some View {
        VStack {
            Text("Main Screen")
            Text(language.displayName)
        }
    }
}

struct MockListScreenView: View {
    let language: AppLanguage

    var body: some View {
        List {
            ForEach(0..<5) { index in
                Text("Item \(index)")
            }
        }
    }
}

#Preview {
    ScreenshotPreviewView()
}
#endif
```

### 2. Add to Settings/Debug Menu

In your SettingsView or debug menu:

```swift
#if DEBUG
Section(header: Text("デバッグ")) {
    NavigationLink(destination: ScreenshotPreviewView()) {
        Text("スクリーンショットプレビュー")
    }
}
#endif
```

## Customization Guide

### Adding Languages

1. Add cases to `AppLanguage` enum:
```swift
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case japanese = "ja"
    case german = "de"     // New
    case spanish = "es"    // New

    var displayName: String {
        switch self {
        case .english: return "EN"
        case .japanese: return "JA"
        case .german: return "DE"
        case .spanish: return "ES"
        }
    }
}
```

2. Add localized strings for each language:
```swift
var welcomeMessage: String {
    switch self {
    case .english: return "Welcome"
    case .japanese: return "ようこそ"
    case .german: return "Willkommen"
    case .spanish: return "Bienvenido"
    }
}
```

### Adding Screens

1. Add screen type to enum:
```swift
enum ScreenshotScreen: String, CaseIterable {
    case mainScreen
    case listScreen
    case settingsScreen  // New
}
```

2. Create mock view:
```swift
struct MockSettingsScreenView: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(language.settingsTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()

            // Settings items
            List {
                Section(header: Text(language.generalSection)) {
                    ForEach(0..<3) { index in
                        HStack {
                            Text(language.settingItem(index))
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                    }
                }
            }
        }
    }
}
```

3. Add to switch in `screenPreview`:
```swift
@ViewBuilder
private func screenPreview(for screen: ScreenshotScreen) -> some View {
    switch screen {
    case .mainScreen:
        MockMainScreenView(language: language)
    case .listScreen:
        MockListScreenView(language: language)
    case .settingsScreen:
        MockSettingsScreenView(language: language)  // Add this
    }
}
```

### Creating Realistic Mock Views

Use VoiLog's implementation as reference (`ios/VoiLog/DebugMode/ScreenshotPreviewView.swift`):

**List View Example:**
```swift
struct MockListView: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 0) {
            // Title Bar
            HStack {
                Text(language.screenTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.title3)
                }
            }
            .padding(.horizontal)
            .padding(.top, 60)
            .padding(.bottom, 20)

            // List Content
            List {
                ForEach(0..<5) { index in
                    HStack(spacing: 12) {
                        // Icon
                        Image(systemName: "doc.text")
                            .font(.title2)
                            .foregroundColor(.blue)

                        // Info
                        VStack(alignment: .leading, spacing: 4) {
                            Text(language.itemTitle(index))
                                .font(.headline)
                            Text(language.itemDate(index))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text("1:\(15 + index)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
        }
    }
}
```

## Taking Screenshots

1. Run app in Simulator (iPhone size for App Store)
2. Navigate to Debug → Screenshot Preview
3. Select language
4. Swipe through screens
5. Press `Cmd + S` to save screenshot
6. Screenshots saved to Desktop

## Advanced Features

### Custom Gestures

The default implementation supports:
- **Swipe down**: Dismiss from any screen
- **Swipe right**: Dismiss from last screen only

Customize thresholds:
```swift
.onEnded { value in
    if value.translation.height > 200 {  // Adjust threshold
        onDismiss()
    }
    // ...
}
```

### Animations

Add transition animations:
```swift
.offset(x: isLastTab ? dragOffset.width : 0, y: dragOffset.height)
.animation(.spring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
```

### Dynamic Content

Use state for interactive previews:
```swift
struct MockRecordingView: View {
    let language: AppLanguage
    @State private var isRecording = true
    @State private var timer = "00:05:23"

    var body: some View {
        // Recording UI with timer animation
    }
}
```

## Real-World Example

See VoiLog implementation for:
- 12 languages (English, Japanese, German, Spanish, etc.)
- 6 screens (Recording, Playback, Background, Waveform, Playlist, Share)
- Complex layouts with gradients, animations
- Lock screen simulation
- Share sheet mockup

Location: `ios/VoiLog/DebugMode/ScreenshotPreviewView.swift`

## Best Practices

1. **Wrap in #if DEBUG**: Prevents inclusion in release builds
2. **Realistic Mock Data**: Use actual use case examples
3. **Match Real UI**: Keep layouts identical to production
4. **Complete Localization**: Provide all language strings
5. **Test on Device Sizes**: Verify on all target iPhone models

## Troubleshooting

### Build Error: ScreenshotPreviewView not available in Release

**Solution**: Ensure all references are wrapped in `#if DEBUG`:
```swift
#if DEBUG
NavigationLink(destination: ScreenshotPreviewView()) {
    Text("スクリーンショットプレビュー")
}
#endif
```

### Mock View Doesn't Match Real UI

**Solution**:
1. Compare with actual view code
2. Use same fonts, colors, spacing
3. Check safe area insets
4. Verify navigation bar styling

### Language Text Not Showing

**Solution**:
1. Verify all AppLanguage cases return non-empty strings
2. Check switch statement covers all cases
3. Add default fallback: `default: return "Default Text"`

## References

- VoiLog Implementation: `ios/VoiLog/DebugMode/ScreenshotPreviewView.swift`
- Apple HIG: https://developer.apple.com/design/human-interface-guidelines/app-store
- App Store Screenshot Specs: https://help.apple.com/app-store-connect/#/devd274dd925
