import SwiftUI

#if DEBUG
// MARK: - Screenshot Preview Feature
struct ScreenshotPreviewView: View {
    @State private var selectedLanguage: AppLanguage?

    var body: some View {
        NavigationStack {
            List {
                ForEach(AppLanguage.allCases) { language in
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
                FullscreenScreenshotView(language: language) {
                    selectedLanguage = nil
                }
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
    @Environment(\.dismiss) var dismiss

    /// 先頭はヒーロー（nil）、続けて各画面
    private let pages: [ScreenshotScreen?] = [nil] + ScreenshotScreen.allCases.map(Optional.some)

    private var isLastTab: Bool {
        selectedTab == pages.count - 1
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, screen in
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
                    // Allow downward swipe from any tab
                    if value.translation.height > 0 {
                        dragOffset = CGSize(width: 0, height: value.translation.height)
                    }
                    // Allow rightward swipe only on last tab
                    else if isLastTab && value.translation.width > 0 {
                        dragOffset = CGSize(width: value.translation.width, height: 0)
                    }
                }
                .onEnded { value in
                    // Dismiss if swiped down more than 150 points
                    if value.translation.height > 150 {
                        onDismiss()
                    }
                    // Dismiss if swiped right more than 150 points on last tab
                    else if isLastTab && value.translation.width > 150 {
                        onDismiss()
                    } else {
                        // Reset offset with animation
                        withAnimation(.spring()) {
                            dragOffset = .zero
                        }
                    }
                }
        )
    }

    @ViewBuilder
    private func screenPreview(for screen: ScreenshotScreen?) -> some View {
        if let screen {
            PromoScreenshotPageView(screen: screen, language: language)
        } else {
            HeroRecorderPageView(language: language)
        }
    }
}

// MARK: - Screenshot Screen Enum
enum ScreenshotScreen: String, CaseIterable {
    case aiRecording
    case useCase
    case playbackList
    case backgroundRecording
    case timestampedTranscription
    case waveformEditor
    case playlist
    case shareSheet
    case premium
    case aiTranscription

    /// 各画面の中身（端末フレームの内側。iPhone は 390x844pt、iPad は 820x1180pt で描かれる）
    @ViewBuilder
    func mockView(language: AppLanguage) -> some View {
        switch self {
        case .aiRecording: MockAIRecordingView(language: language)
        case .useCase: MockUseCaseView(language: language)
        case .playbackList: MockPlaybackListView(language: language)
        case .backgroundRecording: MockBackgroundRecordingView(language: language)
        case .timestampedTranscription: MockTimestampedTranscriptionView(language: language)
        case .waveformEditor: MockWaveformEditorView(language: language)
        case .playlist: MockPlaylistView(language: language)
        case .shareSheet: MockShareSheetView(language: language)
        case .premium: MockPremiumView(language: language)
        case .aiTranscription: MockAITranscriptionView(language: language)
        }
    }
}

/// App Store に出す並び。配列の添字 + 1 がファイル名のスロット番号（0 はヒーロー）
enum ScreenshotSlots {
    static let iPhone: [ScreenshotScreen] = [
        .playbackList, .useCase, .waveformEditor, .backgroundRecording, .playlist,
        .timestampedTranscription, .aiTranscription
    ]
    /// iPad はヒーローが無いので 0 から
    static let iPad: [ScreenshotScreen] = [
        .aiRecording, .playbackList, .useCase, .waveformEditor, .backgroundRecording, .playlist,
        .timestampedTranscription
    ]
}

// MARK: - Mock Playback List View
struct MockPlaybackListView: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 0) {
            // Title
            HStack {
                Text(language.recordingFiles)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 90)
            .padding(.bottom, 12)

            Divider()

            // Recording rows (no List — VStack for deterministic top layout)
            VStack(spacing: 0) {
                ForEach(0..<5) { index in
                    HStack(spacing: 12) {
                        Image(systemName: index == 0 ? "pause.circle.fill" : "play.circle")
                            .font(.title2)
                            .foregroundColor(index == 0 ? .red : .blue)
                            .frame(width: 30, height: 30)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(language.sampleRecordingTitle(index))
                                    .font(.headline)
                                    .lineLimit(1)
                                Spacer()
                                Text(String(format: "%d:%02d", index + 1, (index * 15) % 60))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                            Text(language.sampleDate(index))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if index == 0 {
                                // ProgressView は ImageRenderer でアクセントカラーに引き寄せられるためカスタム描画
                                GeometryReader { g in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.secondary.opacity(0.2)).frame(height: 3)
                                        Capsule().fill(Color.blue).frame(width: g.size.width * 0.3, height: 3)
                                    }
                                }
                                .frame(height: 3)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)

                    Divider().padding(.leading, 54)
                }
            }

            Spacer()

            // Mini player — PlaybackFeature.swift 縦画面レイアウトに合わせた構造
            VStack(spacing: 0) {
                Divider()
                VStack(spacing: 8) {
                    // 1. タイトル行
                    HStack {
                        VStack(alignment: .leading) {
                            Text(language.sampleRecordingTitle(0))
                                .font(.headline).lineLimit(1)
                            Text(language.sampleDate(0))
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2).foregroundColor(.secondary)
                    }

                    // 2. Slider + 時間表示（Slider は ImageRenderer 非対応のためカスタム描画）
                    VStack(spacing: 4) {
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.25))
                                    .frame(height: 4)
                                Capsule()
                                    .fill(Color.accentColor)
                                    .frame(width: g.size.width * 0.3, height: 4)
                                Circle()
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.2), radius: 2)
                                    .frame(width: 20, height: 20)
                                    .offset(x: g.size.width * 0.3 - 10)
                            }
                            .frame(maxHeight: .infinity)
                        }
                        .frame(height: 20)
                        HStack {
                            Text("0:18").font(.caption).monospacedDigit()
                            Spacer()
                            Text("1:17").font(.caption).monospacedDigit()
                        }
                        .foregroundColor(.secondary)
                    }

                    // 3. コントロール行（速度 | A | B | repeat | pause — Spacer なし）
                    HStack(spacing: 16) {
                        Text("1x")
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Capsule())
                        Text("A")
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Capsule())
                        Text("B")
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Capsule())
                        Image(systemName: "repeat")
                            .font(.body).foregroundColor(.secondary)
                        Image(systemName: "pause.circle.fill")
                            .font(.largeTitle).foregroundColor(.accentColor)
                    }
                }
                .padding()
                .padding(.bottom, 20)
                .background(Color(.systemBackground))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Mock Background Recording View
struct MockBackgroundRecordingView: View {
    let language: AppLanguage

    var body: some View {
        ZStack {
            // Dark lock screen gradient — fills full PhoneFrame content area
            LinearGradient(
                colors: [
                    Color(red: 0.20, green: 0.26, blue: 0.50),
                    Color(red: 0.10, green: 0.14, blue: 0.32),
                    Color(red: 0.06, green: 0.10, blue: 0.22)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .center, spacing: 0) {
                // Space for PhoneFrame's built-in status bar + Dynamic Island overlay
                Spacer().frame(height: 80)

                // Localized date
                Text(language.lockScreenDate)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.top, 16)

                // Large clock
                Text("13:39")
                    .font(.system(size: 92, weight: .thin))
                    .foregroundColor(.white)
                    .padding(.top, 2)

                Spacer()

                // Live Activity / Recording banner
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.2))
                            .frame(width: 36, height: 36)
                        Image(systemName: "mic.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(language.recordingText)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                            Text(language.appTitle)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("02:47")
                            .font(.system(size: 22, weight: .semibold, design: .monospaced))
                            .foregroundColor(.orange)
                        Text(language.recordingText)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial.opacity(0.8))
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 40)

            }
        }
    }
}

// MARK: - Mock Waveform Editor View
struct MockWaveformEditorView: View {
    let language: AppLanguage

    private let heights: [CGFloat] = [20, 35, 50, 70, 45, 80, 55, 40, 65, 90,
                                       75, 50, 85, 60, 45, 70, 55, 80, 65, 40,
                                       55, 75, 90, 60, 45, 35, 50, 70, 85, 55,
                                       40, 65, 80, 50, 35, 60, 75, 45, 70, 55,
                                       85, 60, 40, 75, 50, 65, 80, 45, 55, 35]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(language.cancel) {}
                    .foregroundColor(.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: 96, alignment: .leading)
                Spacer()
                Text(language.audioEdit)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Button(language.save) {}
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: 96, alignment: .trailing)
            }
            .padding()
            .padding(.top, 50)
            .background(Color(.systemBackground))

            // ScrollView を使わず VStack で直接展開（ImageRenderer 対応）
            VStack(spacing: 16) {
                // Waveform + trim selection overlay
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )

                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height
                        // trim: 25%〜75% の範囲を選択中として表示
                        let trimStart = w * 0.25
                        let trimEnd   = w * 0.75
                        let playPos   = w * 0.40

                        ZStack(alignment: .leading) {
                            // 波形バー（全て同色）
                            HStack(alignment: .center, spacing: 1) {
                                ForEach(0..<80, id: \.self) { i in
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(Color.blue)
                                        .frame(width: 2, height: heights[i % heights.count])
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                            // 選択範囲オーバーレイ（青い半透明矩形）
                            Rectangle()
                                .fill(Color.blue.opacity(0.25))
                                .frame(width: trimEnd - trimStart, height: h)
                                .offset(x: trimStart)

                            // トリム左ハンドル
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: 3, height: h)
                                .offset(x: trimStart)

                            // トリム右ハンドル
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: 3, height: h)
                                .offset(x: trimEnd - 3)

                            // 再生位置（赤いライン）
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 2, height: h)
                                .offset(x: playPos)
                        }
                    }
                    .padding(10)
                }
                .frame(height: 150)
                .padding(.horizontal)

                // 時間表示 + プログレスバー
                HStack {
                    ZStack {
                        Capsule().fill(Color.blue.opacity(0.1)).frame(height: 30)
                        Text("00:31").font(.system(size: 14, weight: .semibold).monospacedDigit()).foregroundColor(.blue)
                    }.frame(width: 70)
                    Spacer()
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.2)).frame(height: 4)
                            Capsule().fill(Color.blue).frame(width: g.size.width * 0.4, height: 4)
                        }.frame(maxHeight: .infinity)
                    }
                    .frame(height: 4)
                    Spacer()
                    ZStack {
                        Capsule().fill(Color.blue.opacity(0.1)).frame(height: 30)
                        Text("01:17").font(.system(size: 14, weight: .semibold).monospacedDigit()).foregroundColor(.blue)
                    }.frame(width: 70)
                }.padding(.horizontal)

                // 再生コントロール
                HStack(spacing: 30) {
                    Button(action: {}) {
                        Image(systemName: "gobackward.5").font(.title2).foregroundColor(.blue)
                    }
                    Button(action: {}) {
                        Image(systemName: "play.circle.fill").font(.system(size: 50)).foregroundColor(.blue)
                    }
                    Button(action: {}) {
                        Image(systemName: "goforward.5").font(.title2).foregroundColor(.blue)
                    }
                }

                Divider()

                // 編集ツールバー（分割ボタン）
                HStack {
                    VStack(spacing: 4) {
                        Image(systemName: "scissors.badge.ellipsis").font(.title2)
                        Text(language.split).font(.caption)
                    }
                    .frame(width: 70, height: 70)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    .foregroundColor(.blue)
                }

                // 選択範囲の情報テキスト
                Text("00:19 - 00:57")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.top, 12)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Mock Playlist View
struct MockPlaylistView: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 0) {
            // Title and Toolbar
            HStack {
                Text(language.playlist)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.title3)
                }
            }
            .padding(.horizontal)
            .padding(.top, 90)
            .padding(.bottom, 20)

            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { index in
                    VStack(spacing: 0) {
                        HStack(alignment: .top, spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [playlistGradientColors(for: index).0, playlistGradientColors(for: index).1],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 64, height: 64)

                                Image(systemName: "music.note.list")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(language.playlistName(index))
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text(language.recordingCount(3 + index * 2))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text(language.createdDate(index))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if index < 2 {
                            Divider().padding(.leading, 96)
                        }
                    }
                    .background(Color(uiColor: .systemBackground))
                }
            }
            .background(Color(uiColor: .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground))
    }

    private func playlistGradientColors(for index: Int) -> (Color, Color) {
        let gradients: [(Color, Color)] = [
            (Color.blue, Color.purple),
            (Color.green, Color.teal),
            (Color.orange, Color.pink)
        ]
        return gradients[index % gradients.count]
    }

}

// MARK: - Mock Share Sheet View
struct MockShareSheetView: View {
    let language: AppLanguage

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background Dim
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Share Sheet Header
                VStack(spacing: 16) {
                    // File preview
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Image(systemName: "waveform")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        .frame(width: 60, height: 60)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(language.sampleRecordingTitle(0))
                                .font(.headline)
                                .lineLimit(1)
                            Text("\(language.audioRecording) • 2.1 MB")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding()

                    Divider()

                    // Share Options Row 1
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            shareOption(icon: "message.fill", title: language.string("share_message"), color: .green)
                            shareOption(icon: "envelope.fill", title: language.string("share_mail"), color: .blue)
                            shareOption(icon: "link", title: language.string("share_link"), color: .gray)
                            shareOption(icon: "square.and.arrow.up", title: language.string("share_more"), color: .gray)
                        }
                        .padding(.horizontal)
                    }

                    Divider()
                }
                .background(Color(.systemBackground))
                .cornerRadius(radius: 16, corners: [.topLeft, .topRight])

                // Action List
                VStack(spacing: 0) {
                    actionRow(icon: "doc.on.doc", title: language.copy)
                    Divider().padding(.leading, 56)
                    actionRow(icon: "folder", title: language.saveToFiles)
                    Divider().padding(.leading, 56)
                    actionRow(icon: "trash", title: language.delete, color: .red)
                }
                .background(Color(.systemBackground))
                .padding(.top, 8)

                // Cancel Button
                Button(action: {}) {
                    Text(language.cancel)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                }
                .padding(.top, 8)
                .padding(.horizontal)
                .padding(.bottom, 34)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func shareOption(icon: String, title: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 60, height: 60)
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }

    private func actionRow(icon: String, title: String, color: Color = .primary) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)

            Text(title)
                .foregroundColor(color)

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Mock AI Recording View
struct MockAIRecordingView: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 0) {
            // Title
            HStack {
                Text(language.recordingTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 90)
            .padding(.bottom, 20)

            VStack(spacing: 20) {
                // Recording Status and Timer
                VStack(spacing: 8) {
                    Text(language.recordingText)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    Text("00:02:45")
                        .font(.title.monospacedDigit())
                        .fontWeight(.bold)
                }

                // Audio Level Meter
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.green, .yellow, .orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * 0.65)
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                    }
                }
                .frame(height: 20)
                .cornerRadius(10)
                .padding(.horizontal)

                Spacer()

                // Control Buttons
                HStack(spacing: 32) {
                    Button(action: {}) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray))
                                .frame(width: 70, height: 70)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.red)
                                .frame(width: 25, height: 25)
                        }
                    }
                    Button(action: {}) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray2))
                                .frame(width: 60, height: 60)
                            Image(systemName: "pause.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .padding()
        }
    }
}

// MARK: - Mock Use Case View
struct MockUseCaseView: View {
    let language: AppLanguage

    private let tagColors: [Color] = [.orange, .purple, .blue, .green, .red]
    private let useCaseDurations = ["45:23", "1:23:45", "15:42", "3:21", "8:05"]

    var body: some View {
        VStack(spacing: 0) {
            // Title
            HStack {
                Text(language.recordingFiles)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 90)
            .padding(.bottom, 12)

            Divider()

            // Recording rows
            VStack(spacing: 0) {
                ForEach(0..<5) { index in
                    HStack(spacing: 10) {
                        // Play button
                        Image(systemName: index == 0 ? "pause.circle.fill" : "play.circle")
                            .font(.title2)
                            .foregroundColor(index == 0 ? .red : .blue)
                            .frame(width: 30, height: 30)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(language.useCaseSampleTitle(index))
                                    .font(.headline)
                                    .lineLimit(1)
                                Spacer()
                                Text(useCaseDurations[index])
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                            HStack(spacing: 6) {
                                // Tag badge
                                Text(language.useCaseTag(index))
                                    .font(.caption2.bold())
                                    .foregroundColor(tagColors[index])
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(tagColors[index].opacity(0.12))
                                    .clipShape(Capsule())
                                Text(language.sampleDate(index))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Image(systemName: "ellipsis.circle")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)

                    Divider().padding(.leading, 52)
                }
            }

            Spacer()

            // Mini player
            VStack(spacing: 0) {
                Divider()
                VStack(spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(language.useCaseSampleTitle(0))
                                .font(.headline).lineLimit(1)
                            Text(language.sampleDate(0))
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "pause.circle.fill")
                            .font(.largeTitle).foregroundColor(.blue)
                    }
                    .padding(.horizontal)

                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.2)).frame(height: 4)
                            Capsule().fill(Color.blue).frame(width: g.size.width * 0.25, height: 4)
                        }.frame(maxHeight: .infinity)
                    }
                    .frame(height: 4)
                    .padding(.horizontal)

                    HStack {
                        Text("11:21").font(.caption).monospacedDigit()
                        Spacer()
                        Text("45:23").font(.caption).monospacedDigit()
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 34)
                }
                .padding(.top, 8)
                .background(Color(.systemBackground))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Mock Timestamped Transcription View
struct MockTimestampedTranscriptionView: View {
    let language: AppLanguage

    private let timestamps = ["00:00", "00:18", "00:42", "01:23"]

    var body: some View {
        VStack(spacing: 0) {
            // Title and Export button
            HStack {
                Text(language.transcriptionTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                }
            }
            .padding(.horizontal)
            .padding(.top, 90)
            .padding(.bottom, 20)

            // ImageRenderer非対応のScrollViewを使わず静的VStackで描画
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(timestamps.enumerated()), id: \.offset) { index, ts in
                    HStack(alignment: .top, spacing: 12) {
                        Text(ts)
                            .font(.subheadline.monospacedDigit())
                            .foregroundColor(.blue)
                            .frame(width: 44, alignment: .leading)
                            .padding(.top, 2)

                        Text(language.transcriptionSampleText(index))
                            .font(.body)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                    if index < timestamps.count - 1 {
                        Divider()
                            .padding(.leading, 68)
                    }
                }
            }

            Spacer()

            // Mini player
            VStack(spacing: 0) {
                Divider()
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(language.useCaseSampleTitle(0))
                                .font(.headline)
                                .lineLimit(1)
                            Text(language.sampleDate(0))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {}) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    VStack(spacing: 4) {
                        // ProgressView は ImageRenderer で tint が効かず黄色になるためカスタム描画
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.secondary.opacity(0.2)).frame(height: 4)
                                Capsule().fill(Color.blue).frame(width: g.size.width * 0.38, height: 4)
                            }
                            .frame(maxHeight: .infinity)
                        }
                        .frame(height: 4)
                        HStack {
                            Text("00:18")
                                .font(.caption)
                                .monospacedDigit()
                            Spacer()
                            Text("45:23")
                                .font(.caption)
                                .monospacedDigit()
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    Button(action: {}) {
                        Image(systemName: "pause.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                    }
                    .padding(.bottom, 8)
                }
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Mock Premium View
struct MockPremiumView: View {
    let language: AppLanguage

    private let cyanTop = Color(red: 0, green: 200 / 255, blue: 224 / 255)
    private let cyanBottom = Color(red: 0, green: 110 / 255, blue: 160 / 255)
    private let gold = Color(red: 1, green: 215 / 255, blue: 0)

    private let features: [(iconName: String, keyPath: KeyPath<AppLanguage, String>) ] = [
        ("nosign", \.premiumNoAds),
        ("wifi.slash", \.premiumOffline),
        ("waveform.badge.plus", \.premiumUnlimited),
        ("icloud.fill", \.premiumICloud)
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [cyanTop, cyanBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 72)

                // Crown badge
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(gold.opacity(0.2))
                            .frame(width: 84, height: 84)
                        Circle()
                            .strokeBorder(gold.opacity(0.6), lineWidth: 2)
                            .frame(width: 84, height: 84)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 38))
                            .foregroundColor(gold)
                    }

                    Text(language.string("premium_badge"))
                        .font(.caption)
                        .fontWeight(.bold)
                        .tracking(3)
                        .foregroundColor(gold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(gold.opacity(0.18))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder(gold.opacity(0.5), lineWidth: 1)
                        )
                }

                Spacer().frame(height: 36)

                // Headline
                Text(language.premiumScreenHeadline)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 44)

                // Feature cards
                VStack(spacing: 16) {
                    ForEach(features, id: \.iconName) { feature in
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.18))
                                    .frame(width: 44, height: 44)
                                Image(systemName: feature.iconName)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Text(language[keyPath: feature.keyPath])
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(gold)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // CTA Button
                Text(language.premiumCTAButton)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(cyanBottom)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 52)
            }
        }
    }
}

// MARK: - Mock AI Transcription View
struct MockAITranscriptionView: View {
    let language: AppLanguage

    private struct Segment {
        let time: String
        let speaker: String
        let text: String
    }

    private static let segmentTimes = ["0:00", "0:18", "0:42", "1:10"]
    private static let segmentSpeakers = ["A", "B", "A", "B"]

    private func segments() -> [Segment] {
        language.strings("ai_segments").enumerated().map { index, text in
            Segment(
                time: Self.segmentTimes[index % Self.segmentTimes.count],
                speaker: Self.segmentSpeakers[index % Self.segmentSpeakers.count],
                text: text
            )
        }
    }

    private let speakerColors: [Color] = [.blue, .orange, .green, .pink]

    private func speakerColor(_ speaker: String) -> Color {
        let idx = (speaker.unicodeScalars.first?.value ?? 0) % UInt32(speakerColors.count)
        return speakerColors[Int(idx)]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Navigation bar
            HStack {
                Text(language.transcriptionTitle)
                    .font(.title3.bold())
                Spacer()
                Image(systemName: "square.and.arrow.up")
                    .font(.body)
                    .foregroundStyle(.blue)
            }
            .padding(.horizontal)
            .padding(.top, 90)
            .padding(.bottom, 8)

            // Tab picker
            HStack(spacing: 0) {
                Text(language.string("ai_tab_apple"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color(.systemBackground))
                Text(language.string("ai_tab_ai"))
                    .font(.subheadline.bold())
                    .foregroundStyle(.purple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.1))
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.purple)
                    .frame(width: UIScreen.main.bounds.width / 2, height: 2)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal)
            .padding(.bottom, 4)

            Divider()

            // Summary section
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles").foregroundStyle(.purple)
                    Text(language.string("ai_summary_label"))
                        .font(.caption.bold())
                        .foregroundStyle(.purple)
                }
                Text(language.string("ai_summary_text"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.purple.opacity(0.06))

            Divider()

            // Transcript segments
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(segments().enumerated()), id: \.offset) { index, seg in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(seg.time)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.purple)
                                .frame(width: 36, alignment: .leading)
                            Text(seg.speaker)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(speakerColor(seg.speaker))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(speakerColor(seg.speaker).opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .padding(.top, 2)
                        Text(seg.text)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    if index < segments().count - 1 {
                        Divider().padding(.leading, 58)
                    }
                }
            }

            Spacer()

            // Save button
            Text(language.save)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.purple)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.bottom, 20)
        }
    }
}

// MARK: - Preview
#Preview("Language picker") {
    ScreenshotPreviewView()
}

#Preview("Hero (JA)") {
    HeroRecorderPageView(language: .japanese)
}

#Preview("Hero (EN)") {
    HeroRecorderPageView(language: .english)
}

#Preview("All screens (DE)") {
    FullscreenScreenshotView(language: .german) {}
}
#endif
