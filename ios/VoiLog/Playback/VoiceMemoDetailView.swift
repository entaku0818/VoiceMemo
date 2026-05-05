import SwiftUI

struct VoiceMemoDetailView: View {
  let memo: PlaybackFeature.VoiceMemo
  let onDismiss: () -> Void
  var onShowAppleTranscription: (() -> Void)?
  var onShowGeminiTranscription: (() -> Void)?

  var body: some View {
      NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          // 基本情報セクション
          detailSection(title: String(localized: "基本情報")) {
            detailRow(label: String(localized: "タイトル"), value: memo.title)
            detailRow(label: String(localized: "録音日時"), value: DateFormatter.dateTimeFormatter.string(from: memo.date))
            detailRow(label: String(localized: "再生時間"), value: formatDuration(memo.duration))

            // 文字起こしへのナビゲーション
            if memo.timestampedText != nil || !memo.text.isEmpty {
              transcriptionRow(
                icon: "text.bubble.fill",
                label: String(localized: "文字起こし（Apple）"),
                color: .blue
              ) {
                onShowAppleTranscription?()
              }
            }

            transcriptionRow(
              icon: "waveform.and.mic",
              label: String(localized: "AIで文字起こし"),
              color: .purple
            ) {
              onShowGeminiTranscription?()
            }
          }

          // ファイル情報セクション
          detailSection(title: String(localized: "ファイル情報")) {
            detailRow(label: String(localized: "ファイルサイズ"), value: formatFileSize(memo.fileSize))
            detailRow(label: String(localized: "ファイル形式"), value: formatFileFormat(memo.fileFormat))
            detailRow(label: String(localized: "ファイルパス"), value: memo.url.lastPathComponent)
          }

          // 音質設定セクション
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
      .navigationTitle(String(localized: "詳細情報"))
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

  private func transcriptionRow(
    icon: String,
    label: String,
    color: Color,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack {
        Image(systemName: icon)
          .foregroundColor(color)
          .frame(width: 24)
        Text(label)
          .font(.subheadline)
          .foregroundColor(.primary)
        Spacer()
        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
  }

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
      title: "テスト録音",
      date: Date(),
      duration: 123.45,
      url: URL(fileURLWithPath: "/test.m4a"),
      text: "これはテスト用の音声認識テキストです。",
      fileFormat: "m4a",
      samplingFrequency: 44100.0,
      quantizationBitDepth: 16,
      numberOfChannels: 2,
      fileSize: 1024576
    ),
    onDismiss: {}
  )
}
