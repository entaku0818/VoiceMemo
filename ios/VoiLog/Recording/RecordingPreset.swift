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
        case .memo: return String(localized: "メモ", table: "Recording")
        case .meeting: return String(localized: "会議", table: "Recording")
        case .interview: return String(localized: "取材", table: "Recording")
        case .podcast: return String(localized: "Pod", table: "Recording")
        case .music: return String(localized: "音楽", table: "Recording")
        case .custom: return String(localized: "カスタム", table: "Recording")
        }
    }

    var settingsTitle: String {
        switch self {
        case .memo: return String(localized: "メモ設定", table: "Recording")
        case .meeting: return String(localized: "会議設定", table: "Recording")
        case .interview: return String(localized: "取材設定", table: "Recording")
        case .podcast: return String(localized: "Pod設定", table: "Recording")
        case .music: return String(localized: "音楽設定", table: "Recording")
        case .custom: return String(localized: "カスタム設定", table: "Recording")
        }
    }

    var description: String {
        switch self {
        case .memo: return String(localized: "日常のメモや短い音声記録に最適。ファイルサイズを抑えた省エネ設定です。", table: "Recording")
        case .meeting: return String(localized: "会議や打ち合わせに最適。複数人の声を聞き取りやすいバランス設定です。", table: "Recording")
        case .interview: return String(localized: "インタビューや取材向け。声の明瞭さを重視した高品質な設定です。", table: "Recording")
        case .podcast: return String(localized: "ポッドキャスト収録向け。クリアな音声と適切なファイルサイズのバランス設定です。", table: "Recording")
        case .music: return String(localized: "楽器演奏や音楽録音向け。WAV形式で原音を忠実に記録します。", table: "Recording")
        case .custom: return String(localized: "ノイズキャンセリングや音量調整を自分でカスタマイズできます。", table: "Recording")
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
