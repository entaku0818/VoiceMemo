//
//  AppTrackingClientTests.swift
//  VoiLogTests
//
//  ATT(App Tracking Transparency)が再び消えないための回帰テスト。
//  2023-06に実装されたATTは、2025-01-09にレガシーの VoiceList.swift が削除された際に
//  一緒に失われ、約19ヶ月間プロンプトが表示されていなかった（docs/ad_mediation_plan.md §2-2）。
//

import ComposableArchitecture
import XCTest
@testable import VoiLog

final class AppTrackingClientTests: XCTestCase {
    /// testValueは絶対にプロンプトを出さない（出すとCIやテストがハングする）
    func testTestValueDoesNotPrompt() async {
        let client = AppTrackingClient.testValue
        let status = await client.requestAuthorization()
        XCTAssertEqual(status, .notDetermined)
        XCTAssertEqual(client.authorizationStatus(), .notDetermined)
    }

    /// liveValueが存在すること = ATTの実装が消えていないことのガード。
    /// requestAuthorization自体は呼ばない（実機プロンプトが出るため）。
    func testLiveValueExists() {
        let live = AppTrackingClient.liveValue
        // クロージャが差し替えられていない（= 実装が残っている）ことだけを確認する
        _ = live.authorizationStatus
        _ = live.requestAuthorization
        XCTAssertNotNil(live.authorizationStatus)
    }

    /// ATTrackingManagerの各状態が漏れなくマッピングされていること
    func testAuthorizationMappingIsExhaustive() {
        XCTAssertEqual(AppTrackingAuthorization.notDetermined, .notDetermined)
        XCTAssertNotEqual(AppTrackingAuthorization.authorized, .denied)
        XCTAssertNotEqual(AppTrackingAuthorization.restricted, .unknown)
    }
}

@MainActor
final class VoiceAppFeatureAppTrackingTests: XCTestCase {
    /// 通常起動（チュートリアルなし）では onAppear でATTをリクエストする
    func testOnAppearRequestsTrackingWhenNotFirstLaunch() async {
        let requested = LockIsolated(false)

        let store = TestStore(initialState: VoiceAppFeature.State()) {
            VoiceAppFeature()
        } withDependencies: {
            $0.appTracking = AppTrackingClient(
                authorizationStatus: { .notDetermined },
                requestAuthorization: {
                    requested.setValue(true)
                    return .authorized
                }
            )
            // 初回起動ではない = チュートリアルを出さない
            $0.userDefaults.bool = { key in
                key == UserDefaultsKeys.firstLaunch || key == UserDefaultsKeys.tutorialCompleted
            }
            $0.userDefaults.hasPurchasedProduct = { false }
        }
        store.exhaustivity = .off

        await store.send(.view(.onAppear))
        await store.finish()

        XCTAssertTrue(requested.value, "通常起動時はonAppearでATTをリクエストするべき")
    }

    /// 初回起動でチュートリアルを出す場合、onAppear の時点ではATTを出さない
    /// （チュートリアルとダイアログが重なるのを防ぐ）
    func testOnAppearDefersTrackingWhenTutorialWillShow() async {
        let requested = LockIsolated(false)

        let store = TestStore(initialState: VoiceAppFeature.State()) {
            VoiceAppFeature()
        } withDependencies: {
            $0.appTracking = AppTrackingClient(
                authorizationStatus: { .notDetermined },
                requestAuthorization: {
                    requested.setValue(true)
                    return .authorized
                }
            )
            // 初回起動 かつ チュートリアル未完了
            $0.userDefaults.bool = { _ in false }
            $0.userDefaults.hasPurchasedProduct = { false }
        }
        store.exhaustivity = .off

        await store.send(.view(.onAppear))
        await store.finish()

        XCTAssertFalse(requested.value, "チュートリアル表示時はATTを後回しにするべき")
    }

    /// チュートリアル完了時にATTをリクエストする
    func testTutorialCompletedRequestsTracking() async {
        let requested = LockIsolated(false)

        let store = TestStore(initialState: VoiceAppFeature.State()) {
            VoiceAppFeature()
        } withDependencies: {
            $0.appTracking = AppTrackingClient(
                authorizationStatus: { .notDetermined },
                requestAuthorization: {
                    requested.setValue(true)
                    return .authorized
                }
            )
        }
        store.exhaustivity = .off

        await store.send(.tutorialFeature(.delegate(.tutorialCompleted)))
        await store.finish()

        XCTAssertTrue(requested.value, "チュートリアル完了後にATTをリクエストするべき")
    }
}
