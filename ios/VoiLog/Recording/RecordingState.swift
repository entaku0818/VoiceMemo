import Foundation

enum RecordingState: Equatable {
    case idle
    case preparing
    case recording(startTime: Date)
    case paused(startTime: Date, pausedTime: Date, duration: TimeInterval)
    case completed(duration: TimeInterval)
    case error(RecordingError)
}

enum RecordingError: Error, Equatable {
    case permissionDenied
    case fileCreationFailed
    case audioSessionFailed
    case recordingFailed(String)
    case diskSpaceInsufficient

    var localizedDescription: String {
        switch self {
        case .permissionDenied:
            return "マイクへのアクセス許可が必要です"
        case .fileCreationFailed:
            return "録音ファイルの作成に失敗しました"
        case .audioSessionFailed:
            return "オーディオセッションの設定に失敗しました"
        case .recordingFailed(let message):
            return "録音エラー: \(message)"
        case .diskSpaceInsufficient:
            return "ストレージ容量が不足しています"
        }
    }
}
