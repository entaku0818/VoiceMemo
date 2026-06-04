//
//  AppIconFeatureTests.swift
//  VoiLogTests
//
//  Created by 遠藤拓弥 on 2026.05.25.
//

import XCTest
import ComposableArchitecture
@testable import VoiLog

@MainActor
final class AppIconFeatureTests: XCTestCase {

    /// テスト前に UserDefaults を既知の状態にリセット
    override func setUp() {
        super.setUp()
        UserDefaultsManager.shared.hasPurchasedProduct = false
    }

    override func tearDown() {
        super.tearDown()
        UserDefaultsManager.shared.hasPurchasedProduct = false
    }

    // MARK: - onAppear Tests

    func test_onAppear_setsDefaultIconWhenNoAlternate() async {
        // Given: 未購入状態で初期化
        UserDefaultsManager.shared.hasPurchasedProduct = false

        let store = TestStore(
            initialState: AppIconFeature.State(hasPurchasedPremium: false)
        ) {
            AppIconFeature()
        } withDependencies: {
            $0.uiApplicationIconClient = .init(
                setAlternateIconName: { _ in },
                currentAlternateIconName: { nil }
            )
        }

        // onAppear は UserDefaultsManager から hasPurchasedPremium を再読み込みする
        // false → false なら selectedIcon のみ変更 (no-op)
        // state は変わらないため exhaustivity を off にする
        store.exhaustivity = .off
        await store.send(.onAppear)
        // selectedIcon が .default であることをアサート
        XCTAssertEqual(store.state.selectedIcon, .default)
    }

    func test_onAppear_setsBlueIconWhenAlternateIsBlue() async {
        // Given: プレミアム購入済み状態
        UserDefaultsManager.shared.hasPurchasedProduct = true

        let store = TestStore(
            initialState: AppIconFeature.State(hasPurchasedPremium: true)
        ) {
            AppIconFeature()
        } withDependencies: {
            $0.uiApplicationIconClient = .init(
                setAlternateIconName: { _ in },
                currentAlternateIconName: { "AppIcon_Blue" }
            )
        }

        store.exhaustivity = .off
        await store.send(.onAppear)
        XCTAssertEqual(store.state.selectedIcon, .blue)
    }

    func test_onAppear_setsDefaultWhenUnknownAlternate() async {
        // Given: 不明なアイコン名が返ってくる場合
        UserDefaultsManager.shared.hasPurchasedProduct = true

        let store = TestStore(
            initialState: AppIconFeature.State(hasPurchasedPremium: true)
        ) {
            AppIconFeature()
        } withDependencies: {
            $0.uiApplicationIconClient = .init(
                setAlternateIconName: { _ in },
                currentAlternateIconName: { "AppIcon_Unknown" }
            )
        }

        store.exhaustivity = .off
        await store.send(.onAppear)
        XCTAssertEqual(store.state.selectedIcon, .default)
    }

    // MARK: - selectIcon Tests

    func test_selectIcon_setsLoadingAndCompletesSuccessfully() async {
        let store = TestStore(
            initialState: AppIconFeature.State(hasPurchasedPremium: true)
        ) {
            AppIconFeature()
        } withDependencies: {
            $0.uiApplicationIconClient = .init(
                setAlternateIconName: { _ in },
                currentAlternateIconName: { nil }
            )
        }

        await store.send(.selectIcon(.blue)) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        await store.receive(.iconChangeCompleted(.blue)) {
            $0.isLoading = false
            $0.selectedIcon = .blue
        }
    }

    func test_selectIcon_defaultIconSuccessfully() async {
        let store = TestStore(
            initialState: AppIconFeature.State(hasPurchasedPremium: true)
        ) {
            AppIconFeature()
        } withDependencies: {
            $0.uiApplicationIconClient = .init(
                setAlternateIconName: { name in
                    // defaultのときはnilが渡される
                    XCTAssertNil(name)
                },
                currentAlternateIconName: { nil }
            )
        }
        var state = AppIconFeature.State(hasPurchasedPremium: true)
        state.selectedIcon = .blue
        let storeWithBlue = TestStore(initialState: state) {
            AppIconFeature()
        } withDependencies: {
            $0.uiApplicationIconClient = .init(
                setAlternateIconName: { _ in },
                currentAlternateIconName: { nil }
            )
        }

        await storeWithBlue.send(.selectIcon(.default)) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        await storeWithBlue.receive(.iconChangeCompleted(.default)) {
            $0.isLoading = false
            $0.selectedIcon = .default
        }
    }

    func test_selectIcon_handlesFailure() async {
        struct TestIconError: Error, LocalizedError {
            var errorDescription: String? { "アイコン変更に失敗しました" }
        }

        let store = TestStore(
            initialState: AppIconFeature.State(hasPurchasedPremium: true)
        ) {
            AppIconFeature()
        } withDependencies: {
            $0.uiApplicationIconClient = .init(
                setAlternateIconName: { _ in throw TestIconError() },
                currentAlternateIconName: { nil }
            )
        }

        await store.send(.selectIcon(.red)) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        await store.receive(.iconChangeFailed("アイコン変更に失敗しました")) {
            $0.isLoading = false
            $0.errorMessage = "アイコン変更に失敗しました"
        }
    }

    func test_selectIcon_ignoresWhenAlreadyLoading() async {
        var state = AppIconFeature.State(hasPurchasedPremium: true)
        state.isLoading = true

        let store = TestStore(initialState: state) {
            AppIconFeature()
        } withDependencies: {
            $0.uiApplicationIconClient = .init(
                setAlternateIconName: { _ in XCTFail("Should not be called when already loading") },
                currentAlternateIconName: { nil }
            )
        }

        // ローディング中は selectIcon を無視する
        await store.send(.selectIcon(.blue))
        // 追加のアクションなし → テスト終了で確認
    }

    func test_selectIcon_alternateIconNameIsNilForDefault() async {
        var setAlternateIconNameCalled: String? = "NOT_CALLED"

        let store = TestStore(
            initialState: AppIconFeature.State(hasPurchasedPremium: true)
        ) {
            AppIconFeature()
        } withDependencies: {
            $0.uiApplicationIconClient = .init(
                setAlternateIconName: { name in
                    setAlternateIconNameCalled = name
                },
                currentAlternateIconName: { nil }
            )
        }

        await store.send(.selectIcon(.default)) {
            $0.isLoading = true
        }
        await store.receive(.iconChangeCompleted(.default)) {
            $0.isLoading = false
            $0.selectedIcon = .default
        }

        XCTAssertNil(setAlternateIconNameCalled, "デフォルトアイコンへの変更はnilを渡す必要があります")
    }

    func test_selectIcon_alternateIconNameIsSetForColoredIcon() async {
        var capturedIconName: String? = nil

        let store = TestStore(
            initialState: AppIconFeature.State(hasPurchasedPremium: true)
        ) {
            AppIconFeature()
        } withDependencies: {
            $0.uiApplicationIconClient = .init(
                setAlternateIconName: { name in
                    capturedIconName = name
                },
                currentAlternateIconName: { nil }
            )
        }

        await store.send(.selectIcon(.green)) {
            $0.isLoading = true
        }
        await store.receive(.iconChangeCompleted(.green)) {
            $0.isLoading = false
            $0.selectedIcon = .green
        }

        XCTAssertEqual(capturedIconName, "AppIcon_Green")
    }

    // MARK: - PurchaseManager Dependency Tests

    /// Issue #144: AppIconSettingView が `PurchaseManager.shared` を直接参照する代わりに
    /// TCA Dependency 経由で課金処理を取得できる（=モック化できる）ことを検証する。
    func test_purchaseManagerDependency_canBeOverriddenWithMock() {
        let mock = MockPurchaseManager(productName: "Test Plan", productPrice: "¥980")
        withDependencies {
            $0.purchaseManager = mock
        } operation: {
            @Dependency(\.purchaseManager) var purchaseManager
            XCTAssertTrue(
                purchaseManager is MockPurchaseManager,
                "テスト/Preview ではモックに差し替えられる必要がある"
            )
        }
    }

    /// テストコンテキストでは既定値（testValue = MockPurchaseManager）が解決され、
    /// 本物の `PurchaseManager.shared` が初期化されないことを検証する。
    func test_purchaseManagerDependency_defaultsToMockInTestContext() {
        withDependencies { _ in
            // 既定値を上書きせず testValue を解決させる
        } operation: {
            @Dependency(\.purchaseManager) var purchaseManager
            XCTAssertTrue(purchaseManager is MockPurchaseManager)
        }
    }

    // MARK: - AppIcon Enum Tests

    func test_appIcon_isPremiumReturnsFalseForDefault() {
        XCTAssertFalse(AppIconFeature.AppIcon.default.isPremium)
    }

    func test_appIcon_isPremiumReturnsTrueForColoredIcons() {
        let premiumIcons: [AppIconFeature.AppIcon] = [.blue, .red, .green, .purple, .orange, .pink]
        for icon in premiumIcons {
            XCTAssertTrue(icon.isPremium, "\(icon.rawValue) はプレミアムアイコンのはず")
        }
    }

    func test_appIcon_alternateIconNameIsNilForDefault() {
        XCTAssertNil(AppIconFeature.AppIcon.default.alternateIconName)
    }

    func test_appIcon_alternateIconNameMatchesRawValue() {
        XCTAssertEqual(AppIconFeature.AppIcon.blue.alternateIconName, "AppIcon_Blue")
        XCTAssertEqual(AppIconFeature.AppIcon.red.alternateIconName, "AppIcon_Red")
        XCTAssertEqual(AppIconFeature.AppIcon.green.alternateIconName, "AppIcon_Green")
        XCTAssertEqual(AppIconFeature.AppIcon.purple.alternateIconName, "AppIcon_Purple")
        XCTAssertEqual(AppIconFeature.AppIcon.orange.alternateIconName, "AppIcon_Orange")
        XCTAssertEqual(AppIconFeature.AppIcon.pink.alternateIconName, "AppIcon_Pink")
    }

    func test_appIcon_totalCountIs7() {
        XCTAssertEqual(AppIconFeature.AppIcon.allCases.count, 7)
    }

    func test_appIcon_defaultIsFirstCase() {
        XCTAssertEqual(AppIconFeature.AppIcon.allCases.first, .default)
    }
}
