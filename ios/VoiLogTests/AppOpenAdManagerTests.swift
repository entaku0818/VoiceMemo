//
//  AppOpenAdManagerTests.swift
//  VoiLogTests
//

import XCTest
@testable import VoiLog

final class AppOpenAdManagerTests: XCTestCase {
    /// SplashViewとAppOpenAdManagerが別々の間隔値を持っていた過去のバグの再発防止。
    /// 両方のゲートを通過する必要があるため、実際の表示は間隔の二乗まで落ちていた。
    /// 間隔はAppOpenAdManagerが唯一の情報源であるべき。
    /// 2026-09: 収益増のため 5→3 に短縮（issue #216）。
    func testDisplayIntervalIsSingleSourceOfTruth() {
        XCTAssertEqual(AppOpenAdManager.shared.displayInterval, 3)
    }

    /// 間隔が0以下だと剰余演算がクラッシュする、または毎起動表示になる
    func testDisplayIntervalIsPositive() {
        XCTAssertGreaterThan(AppOpenAdManager.shared.displayInterval, 0)
    }

    /// 広告を表示していない状態では、スプラッシュのタイムアウトを待たせてはいけない
    func testIsNotPresentingAdInitially() {
        XCTAssertFalse(AppOpenAdManager.shared.isPresentingAd)
    }
}
