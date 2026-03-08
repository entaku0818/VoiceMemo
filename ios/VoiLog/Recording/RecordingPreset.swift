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
        case .memo: return "メモ"
        case .meeting: return "会議"
        case .interview: return "取材"
        case .podcast: return "Pod"
        case .music: return "音楽"
        case .custom: return "カスタム"
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
