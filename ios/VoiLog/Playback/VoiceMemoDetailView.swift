import SwiftUI
import ComposableArchitecture

struct VoiceMemoDetailView: View {
  let memo: PlaybackFeature.VoiceMemo
  let onDismiss: () -> Void
  var onAISaved: ((String) -> Void)?

  var isActive = false
  var isPlaying = false
  var currentTime: TimeInterval = 0
  var playSpeed: AudioPlayerClient.PlaybackSpeed = .normal
  var onPlayPause: () -> Void = {}
  var onSeek: (TimeInterval) -> Void = { _ in }
  var onSpeedChange: (AudioPlayerClient.PlaybackSpeed) -> Void = { _ in }
  @State private var scrubPosition: TimeInterval?
  @State private var selectedTab = 0

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        playbackControls

        Picker("", selection: $selectedTab) {
          Label(String(localized: "詳細"), systemImage: "info.circle")
            .tag(0)
          Label(String(localized: "文字起こし"), systemImage: "text.bubble.fill")
            .tag(1)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)

        Divider()

        TabView(selection: $selectedTab) {
          detailTab.tag(0)
          TranscriptionTabsView(memo: memo, onAISaved: onAISaved).tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
      }
      .navigationTitle(memo.title.isEmpty ? String(localized: "詳細情報", table: "Playback") : memo.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          ShareLink(item: memo.url) {
            Image(systemName: "square.and.arrow.up")
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button(String(localized: "閉じる")) {
            onDismiss()
          }
        }
      }
    }
  }

  // MARK: - 詳細タブ

  private var playbackControls: some View {
    VStack(spacing: 12) {
      Slider(
        value: Binding(get: { scrubPosition ?? min(currentTime, max(memo.duration, 0)) },
                       set: { scrubPosition = $0 }),
        in: 0...max(memo.duration, 0.001)
      )        { editing in
          if !editing, let position = scrubPosition {
            onSeek(position)
            scrubPosition = nil
          }
        }
      .disabled(!isActive)
      .accessibilityLabel(String(localized: "再生時間", table: "Playback"))
      HStack {
        Text(formatDuration(scrubPosition ?? currentTime))
        Spacer()
        Text(formatDuration(memo.duration))
      }
      .font(.caption.monospacedDigit())
      .foregroundStyle(.secondary)
      HStack(spacing: 32) {
        Button { onSeek(currentTime - 10) } label: {
          Image(systemName: "gobackward.10").font(.title)
        }.disabled(!isActive)
        Button(action: onPlayPause) {
          Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
            .font(.system(size: 60))
        }
        .accessibilityLabel(isPlaying ? String(localized: "一時停止") : String(localized: "再生"))
        Button { onSeek(currentTime + 10) } label: {
          Image(systemName: "goforward.10").font(.title)
        }.disabled(!isActive)
      }
      Picker(selection: Binding(get: { playSpeed }, set: onSpeedChange)) {
        ForEach(AudioPlayerClient.PlaybackSpeed.allCases, id: \.self) { speed in
          Text(speed.description).tag(speed)
        }
      } label: {
        Label(playSpeed.description, systemImage: "speedometer")
      }
      .pickerStyle(.menu)
    }
    .padding()
  }

  private var detailTab: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        detailSection(title: String(localized: "基本情報", table: "Playback")) {
          detailRow(label: String(localized: "タイトル"), value: memo.title)
          detailRow(label: String(localized: "録音日時", table: "Playback"), value: DateFormatter.dateTimeFormatter.string(from: memo.date))
          detailRow(label: String(localized: "再生時間", table: "Playback"), value: formatDuration(memo.duration))
        }

        detailSection(title: String(localized: "ファイル情報", table: "Playback")) {
          detailRow(label: String(localized: "ファイルサイズ", table: "Playback"), value: formatFileSize(memo.fileSize))
          detailRow(label: String(localized: "ファイル形式"), value: formatFileFormat(memo.fileFormat))
          detailRow(label: String(localized: "ファイルパス", table: "Playback"), value: memo.url.lastPathComponent)
        }

        detailSection(title: String(localized: "音質設定", table: "Playback")) {
          detailRow(label: String(localized: "サンプリング周波数"), value: "\(Int(memo.samplingFrequency)) Hz")
          detailRow(label: String(localized: "ビット深度", table: "Playback"), value: "\(memo.quantizationBitDepth) bit")
          detailRow(
            label: String(localized: "チャンネル数", table: "Playback"),
            value: memo.numberOfChannels == 1
              ? String(localized: "モノラル", table: "Playback")
              : String(localized: "ステレオ", table: "Playback")
          )
        }
      }
      .padding()
    }
  }

  // MARK: - Helpers

  @ViewBuilder
  private func detailSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.headline)
        .fontWeight(.semibold)

      VStack(alignment: .leading, spacing: 8) {
        content()
      }
      .padding()
      .background(Color(.systemBackground))
      .cornerRadius(12)
      .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
  }

  private func detailRow(label: String, value: String) -> some View {
    HStack {
      Text(label)
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundColor(.secondary)
        .frame(width: 120, alignment: .leading)

      Text(value)
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func formatDuration(_ duration: TimeInterval) -> String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    return String(format: "%02d:%02d", minutes, seconds)
  }

  private func formatFileSize(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
  }

  private func formatFileFormat(_ format: String) -> String {
    switch format.lowercased() {
    case "m4a", "aac", "mpeg4aac":
      return "AAC"
    case "wav", "linearpcm":
      return "WAV"
    case "":
      return "AAC"
    default:
      return format.uppercased()
    }
  }
}

extension DateFormatter {
  static let dateTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    formatter.locale = Locale(identifier: "ja_JP")
    return formatter
  }()
}

#Preview {
  VoiceMemoDetailView(
    memo: PlaybackFeature.VoiceMemo(
      title: "Test Recording",
      date: Date(),
      duration: 123.45,
      url: URL(fileURLWithPath: "/test.m4a"),
      text: "Sample transcription text.",
      fileFormat: "m4a",
      samplingFrequency: 44100.0,
      quantizationBitDepth: 16,
      numberOfChannels: 2,
      fileSize: 1024576
    )
  ) {}
}
