//
//  AppTrackingClient.swift
//  VoiLog
//
//  App Tracking Transparency (ATT) の許諾リクエストを扱う dependency。
//
//  経緯: ATTは2023-06に `VoiceMemosView.init` から呼ばれていたが（147b417e「ATTを追加」）、
//  2025-01-09の fdd03382 でレガシーの `VoiLog/Voice/VoiceList.swift` が削除された際に
//  一緒に失われ、約19ヶ月間プロンプトが表示されていなかった。
//  許諾が取れないとIDFAが使えず、全iOSインプレッションが非パーソナライズ配信になるため
//  広告eCPMに直接効く（詳細は docs/ad_mediation_plan.md §2-2）。
//  再発防止のため、Viewのinitではなく VoiceAppFeature の reducer 経由で呼び、テストで固定する。
//

import AppTrackingTransparency
import ComposableArchitecture
import Foundation

/// ATTの許諾状態。`ATTrackingManager.AuthorizationStatus` をテスト可能な形に写したもの。
enum AppTrackingAuthorization: Equatable, Sendable {
    case notDetermined
    case restricted
    case denied
    case authorized
    /// 将来OSに追加された未知の状態
    case unknown
}

struct AppTrackingClient {
    /// 現在の許諾状態を返す
    var authorizationStatus: @Sendable () -> AppTrackingAuthorization
    /// 未決定(.notDetermined)ならシステムのATTプロンプトを表示し、結果を返す。
    /// すでに決定済みならプロンプトは出さず現在の状態をそのまま返す。
    var requestAuthorization: @Sendable () async -> AppTrackingAuthorization
}

extension AppTrackingClient: DependencyKey {
    static let liveValue = AppTrackingClient(
        authorizationStatus: {
            AppTrackingAuthorization(ATTrackingManager.trackingAuthorizationStatus)
        },
        requestAuthorization: {
            // 決定済みの場合にrequestを呼んでもプロンプトは出ないが、
            // 無駄な呼び出しを避けるため明示的に早期リターンする
            let current = AppTrackingAuthorization(ATTrackingManager.trackingAuthorizationStatus)
            guard current == .notDetermined else { return current }

            let status = await ATTrackingManager.requestTrackingAuthorization()
            let result = AppTrackingAuthorization(status)
            AppLogger.general.info("ATT authorization result: \(String(describing: result))")
            return result
        }
    )

    /// テストでは絶対にプロンプトを出さない（出すとテストがハングする）
    static let testValue = AppTrackingClient(
        authorizationStatus: { .notDetermined },
        requestAuthorization: { .notDetermined }
    )

    static let previewValue = testValue
}

extension DependencyValues {
    var appTracking: AppTrackingClient {
        get { self[AppTrackingClient.self] }
        set { self[AppTrackingClient.self] = newValue }
    }
}

private extension AppTrackingAuthorization {
    init(_ status: ATTrackingManager.AuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .restricted: self = .restricted
        case .denied: self = .denied
        case .authorized: self = .authorized
        @unknown default: self = .unknown
        }
    }
}
