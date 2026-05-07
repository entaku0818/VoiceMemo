import SwiftUI
import ComposableArchitecture

struct VoiceMemoDetailView: View {
  let memo: PlaybackFeature.VoiceMemo
  let onDismiss: () -> Void
  var onAISaved: ((String) -> Void)?

  @State private var selectedTab = 0

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
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
      .navigationTitle(memo.title.isEmpty ? String(localized: "詳細情報") : memo.title)
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

  private var detailTab: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        detailSection(title: String(localized: "基本情報")) {
          detailRow(label: String(localized: "タイトル"), value: memo.title)
          detailRow(label: String(localized: "録音日時"), value: DateFormatter.dateTimeFormatter.string(from: memo.date))
          detailRow(label: String(localized: "再生時間"), value: formatDuration(memo.duration))
        }

        detailSection(title: String(localized: "ファイル情報")) {
          detailRow(label: String(localized: "ファイルサイズ"), value: formatFileSize(memo.fileSize))
          detailRow(label: String(localized: "ファイル形式"), value: formatFileFormat(memo.fileFormat))
          detailRow(label: String(localized: "ファイルパス"), value: memo.url.lastPathComponent)
        }

        detailSection(title: String(localized: "音質設定")) {
          detailRow(label: String(localized: "サンプリング周波数"), value: "\(Int(memo.samplingFrequency)) Hz")
          detailRow(label: String(localized: "ビット深度"), value: "\(memo.quantizationBitDepth) bit")
          detailRow(
            label: String(localized: "チャンネル数"),
            value: memo.numberOfChannels == 1
              ? String(localized: "モノラル")
              : String(localized: "ステレオ")
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
    ),
    onDismiss: {}
  )
}
