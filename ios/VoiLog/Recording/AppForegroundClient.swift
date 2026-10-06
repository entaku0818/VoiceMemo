import UIKit
import Dependencies

/// アプリが画面に出ているか。録音中の画面更新をバックグラウンドで止めるのに使う（#225）
struct AppForegroundClient {
    var isForeground: @Sendable () async -> Bool
}

extension AppForegroundClient: DependencyKey {
    static let liveValue = Self {
            await MainActor.run { UIApplication.shared.applicationState != .background }
    }

    /// テストでは常にフォアグラウンド扱い（既存のタイマー更新のテストをそのまま通す）
    static let testValue = Self { true }
    static let previewValue = testValue
}

extension DependencyValues {
    var appForeground: AppForegroundClient {
        get { self[AppForegroundClient.self] }
        set { self[AppForegroundClient.self] = newValue }
    }
}
