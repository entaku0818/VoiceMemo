//
//  AppEnvironment.swift
//  VoiLog
//

import ComposableArchitecture

/// アプリ全体で共有する `VoiceAppFeature` の Store。
///
/// ライブアクティビティのボタン操作(Darwin Notification経由)やApp Intents
/// (Shortcuts/Siri経由の録音開始/停止・文字起こし)は SwiftUI の View 階層を
/// 経由せずに実行されるため、同じ Store インスタンスに直接アクションを
/// 送れるようこの静的プロパティを介して公開する。
enum AppEnvironment {
    @MainActor
    static let store = Store(initialState: VoiceAppFeature.State()) {
        VoiceAppFeature()
    }
}
