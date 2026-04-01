import Foundation

enum RecordingPreset: String, CaseIterable, Equatable {
    case memo = "memo"
    case meeting = "meeting"
    case interview = "interview"
    case podcast = "podcast"
    case music = "music"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .memo: return String(localized: "メモ")
        case .meeting: return String(localized: "会議")
        case .interview: return String(localized: "取材")
        case .podcast: return String(localized: "Pod")
        case .music: return String(localized: "音楽")
        case .custom: return String(localized: "カスタム")
        }
    }

    var settingsTitle: String {
        switch self {
        case .memo: return String(localized: "メモ設定")
        case .meeting: return String(localized: "会議設定")
        case .interview: return String(localized: "取材設定")
        case .podcast: return String(localized: "Pod設定")
        case .music: return String(localized: "音楽設定")
        case .custom: return String(localized: "カスタム設定")
        }
    }

    var description: String {
        switch self {
        case .memo: return String(localized: "日常のメモや短い音声記録に最適。ファイルサイズを抑えた省エネ設定です。")
        case .meeting: return String(localized: "会議や打ち合わせに最適。複数人の声を聞き取りやすいバランス設定です。")
        case .interview: return String(localized: "インタビューや取材向け。声の明瞭さを重視した高品質な設定です。")
        case .podcast: return String(localized: "ポッドキャスト収録向け。クリアな音声と適切なファイルサイズのバランス設定です。")
        case .music: return String(localized: "楽器演奏や音楽録音向け。WAV形式で原音を忠実に記録します。")
        case .custom: return String(localized: "ノイズキャンセリングや音量調整を自分でカスタマイズできます。")
        }
    }

    var icon: String {
        switch self {
        case .memo: return "🗒"
        case .meeting: return "🤝"
        case .interview: return "🎙"
        case .podcast: return "🎧"
        case .music: return "🎵"
        case .custom: return "⚙️"
        }
    }

    var noiseCancellationEnabled: Bool {
        switch self {
        case .music, .custom: return false
        default: return true
        }
    }

    var autoGainControlEnabled: Bool {
        switch self {
        case .music, .custom: return false
        default: return true
        }
    }

    var fileFormat: String {
        switch self {
        case .music: return "WAV"
        default: return "m4a"
        }
    }

    var sampleRate: Double {
        switch self {
        case .memo: return 22050
        case .music: return 48000
        default: return 44100
        }
    }
}
