//
//  AppEnvironment.swift
//  VoiLog
//

import ComposableArchitecture

/// アプリ全体で共有する `VoiceAppFeature` の Store。
///
/// ロック画面/コントロールセンターからの再生操作（MPRemoteCommandCenter）や
/// ライブアクティビティのボタン操作、App Intents（Shortcuts/Siri経由）は
/// SwiftUI の View 階層を経由せずに実行されるため、同じ Store インスタンスに
/// 直接アクションを送れるようこの静的プロパティを介して公開する。
enum AppEnvironment {
    @MainActor
    static let store = Store(initialState: VoiceAppFeature.State()) {
        VoiceAppFeature()
    }
}
