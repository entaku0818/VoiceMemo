import XCTest
import ComposableArchitecture
@testable import VoiLog

/// 月1課金案内（issue #228）の間隔判定と、VoiceAppFeature での出し方のテスト
@MainActor
final class MonthlyPaywallPolicyTests: XCTestCase {
    private let day: TimeInterval = 24 * 60 * 60
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func shouldShow(
        isPremium: Bool = false,
        firstSeenDaysAgo: Double? = 10,
        lastShownDaysAgo: Double? = nil,
        isBusy: Bool = false,
        hasCompetingPrompt: Bool = false
    ) -> Bool {
        MonthlyPaywallPolicy.shouldShow(
            now: now,
            isPremium: isPremium,
            firstSeenAt: firstSeenDaysAgo.map { now.addingTimeInterval(-$0 * day) },
            lastShownAt: lastShownDaysAgo.map { now.addingTimeInterval(-$0 * day) },
            isBusy: isBusy,
            hasCompetingPrompt: hasCompetingPrompt
        )
    }

    // MARK: - 間隔判定

    func testShows_WhenNeverShownAndPastGracePeriod() {
        XCTAssertTrue(shouldShow(firstSeenDaysAgo: 3, lastShownDaysAgo: nil))
    }

    func testDoesNotShow_WithinGracePeriodAfterInstall() {
        XCTAssertFalse(shouldShow(firstSeenDaysAgo: 0))
        XCTAssertFalse(shouldShow(firstSeenDaysAgo: 2.99))
    }

    func testDoesNotShow_WhenFirstSeenUnknown() {
        XCTAssertFalse(shouldShow(firstSeenDaysAgo: nil))
    }

    func testDoesNotShow_Within30DaysOfLastShown() {
        XCTAssertFalse(shouldShow(firstSeenDaysAgo: 100, lastShownDaysAgo: 0))
        XCTAssertFalse(shouldShow(firstSeenDaysAgo: 100, lastShownDaysAgo: 29.99))
    }

    func testShows_After30DaysOfLastShown() {
        XCTAssertTrue(shouldShow(firstSeenDaysAgo: 100, lastShownDaysAgo: 30))
        XCTAssertTrue(shouldShow(firstSeenDaysAgo: 100, lastShownDaysAgo: 365))
    }

    func testDoesNotShow_ForPremium() {
        XCTAssertFalse(shouldShow(isPremium: true))
    }

    func testDoesNotShow_WhileBusyOrCompetingPrompt() {
        XCTAssertFalse(shouldShow(isBusy: true))
        XCTAssertFalse(shouldShow(hasCompetingPrompt: true))
    }

    func testIsAppOpenAdLaunch_MatchesAdInterval() {
        XCTAssertFalse(MonthlyPaywallPolicy.isAppOpenAdLaunch(appUsageCount: 0, displayInterval: 3))
        XCTAssertFalse(MonthlyPaywallPolicy.isAppOpenAdLaunch(appUsageCount: 2, displayInterval: 3))
        XCTAssertTrue(MonthlyPaywallPolicy.isAppOpenAdLaunch(appUsageCount: 3, displayInterval: 3))
        XCTAssertTrue(MonthlyPaywallPolicy.isAppOpenAdLaunch(appUsageCount: 6, displayInterval: 3))
    }

    // MARK: - VoiceAppFeature（録音保存直後）

    /// UserDefaults の日付とフラグをメモリ上で持つテスト用 client
    private func userDefaults(
        dates: LockIsolated<[String: Date]>,
        bools: [String: Bool] = [:]
    ) -> UserDefaultsClient {
        var client = UserDefaultsClient.testValue
        client.date = { key in dates.value[key] }
        client.setDate = { value, key in dates.withValue { $0[key] = value } }
        client.bool = { key in bools[key] ?? false }
        return client
    }

    private let recordingResult = RecordingFeature.RecordingResult(
        url: URL(fileURLWithPath: "/test.m4a"),
        duration: 10.0,
        title: "Test Recording",
        date: Date()
    )

    /// recordingCompleted は録音回数を UserDefaults.standard で数えるので、10回目（トライアル訴求）にならないよう固定する
    private func withRecordingCount(_ count: Int, _ body: () async -> Void) async {
        let key = UserDefaultsKeys.recordingCompletedCount
        let original = UserDefaults.standard.object(forKey: key)
        UserDefaults.standard.set(count, forKey: key)
        await body()
        UserDefaults.standard.set(original, forKey: key)
    }

    func testRecordingCompleted_ShowsMonthlyPaywallAndRecordsShownDate() async {
        let dates = LockIsolated<[String: Date]>([
            UserDefaultsKeys.monthlyPaywallFirstSeenAt: now.addingTimeInterval(-10 * day)
        ])
        let loggedEvents = LockIsolated<[String]>([])
        await withRecordingCount(3) {
            await withMainSerialExecutor {
                let store = TestStore(initialState: VoiceAppFeature.State()) {
                    VoiceAppFeature()
                } withDependencies: {
                    $0.date.now = now
                    $0.userDefaults = userDefaults(
                        dates: dates,
                        bools: [UserDefaultsKeys.firstRecordingCompleted: true]
                    )
                    $0.firebaseAnalytics = FirebaseAnalyticsClient(
                        logEvent: { name, _ in loggedEvents.withValue { $0.append(name) } },
                        setUserProperty: { _, _ in },
                        setUserId: { _ in }
                    )
                }
                store.exhaustivity = .off

                await store.send(.recordingFeature(.delegate(.recordingCompleted(recordingResult)))) {
                    $0.selectedTab = 1
                    $0.showPaywall = true
                    $0.paywallSource = .monthlyAfterRecording
                }
            }
        }
        XCTAssertEqual(dates.value[UserDefaultsKeys.autoPaywallLastShownAt], now)
        XCTAssertEqual(loggedEvents.value, [FirebaseAnalyticsClient.PaywallEvent.monthlyPaywallShown])
    }

    func testRecordingCompleted_DoesNotShowWithin30Days() async {
        let dates = LockIsolated<[String: Date]>([
            UserDefaultsKeys.monthlyPaywallFirstSeenAt: now.addingTimeInterval(-100 * day),
            UserDefaultsKeys.autoPaywallLastShownAt: now.addingTimeInterval(-10 * day)
        ])
        await withRecordingCount(3) {
            await withMainSerialExecutor {
                let store = TestStore(initialState: VoiceAppFeature.State()) {
                    VoiceAppFeature()
                } withDependencies: {
                    $0.date.now = now
                    $0.userDefaults = userDefaults(
                        dates: dates,
                        bools: [UserDefaultsKeys.firstRecordingCompleted: true]
                    )
                }
                store.exhaustivity = .off

                await store.send(.recordingFeature(.delegate(.recordingCompleted(recordingResult)))) {
                    $0.selectedTab = 1
                }
                XCTAssertFalse(store.state.showPaywall)
            }
        }
    }

    func testRecordingCompleted_DoesNotShowOnFirstRecording() async {
        let notificationCancellations = LockIsolated(0)
        let dates = LockIsolated<[String: Date]>([
            UserDefaultsKeys.monthlyPaywallFirstSeenAt: now.addingTimeInterval(-10 * day)
        ])
        await withRecordingCount(0) {
            await withMainSerialExecutor {
                let store = TestStore(initialState: VoiceAppFeature.State()) {
                    VoiceAppFeature()
                } withDependencies: {
                    $0.date.now = now
                    $0.notificationScheduler.cancelRetentionNotifications = { notificationCancellations.withValue { $0 += 1 } }
                    // firstRecordingCompleted が false = 初回録音（お祝いモーダルが出る）
                    $0.userDefaults = userDefaults(dates: dates)
                }
                store.exhaustivity = .off

                await store.send(.recordingFeature(.delegate(.recordingCompleted(recordingResult)))) {
                    $0.selectedTab = 1
                    $0.showFirstRecordingCelebration = true
                }
                XCTAssertFalse(store.state.showPaywall)
                await store.finish()
                XCTAssertEqual(notificationCancellations.value, 1)
            }
        }
        XCTAssertNil(dates.value[UserDefaultsKeys.autoPaywallLastShownAt])
    }

    func testRecordingCompleted_TrialPromotionCountsAsAutoPaywall() async {
        let dates = LockIsolated<[String: Date]>([
            UserDefaultsKeys.monthlyPaywallFirstSeenAt: now.addingTimeInterval(-10 * day)
        ])
        // 次が10回目の録音 → トライアル訴求が出る
        await withRecordingCount(9) {
            await withMainSerialExecutor {
                let store = TestStore(initialState: VoiceAppFeature.State()) {
                    VoiceAppFeature()
                } withDependencies: {
                    $0.date.now = now
                    $0.userDefaults = userDefaults(
                        dates: dates,
                        bools: [UserDefaultsKeys.firstRecordingCompleted: true]
                    )
                }
                store.exhaustivity = .off

                await store.send(.recordingFeature(.delegate(.recordingCompleted(recordingResult)))) {
                    $0.selectedTab = 1
                    $0.showTrialPromotion = true
                }
                XCTAssertFalse(store.state.showPaywall)
            }
        }
        XCTAssertEqual(dates.value[UserDefaultsKeys.autoPaywallLastShownAt], now)
    }

    func testRecordingCompleted_DoesNotShowForPremium() async {
        let dates = LockIsolated<[String: Date]>([
            UserDefaultsKeys.monthlyPaywallFirstSeenAt: now.addingTimeInterval(-10 * day)
        ])
        var state = VoiceAppFeature.State()
        state.settingFeature.hasPurchasedPremium = true
        let initialState = state
        await withRecordingCount(3) {
            await withMainSerialExecutor {
                let store = TestStore(initialState: initialState) {
                    VoiceAppFeature()
                } withDependencies: {
                    $0.date.now = now
                    $0.userDefaults = userDefaults(
                        dates: dates,
                        bools: [UserDefaultsKeys.firstRecordingCompleted: true]
                    )
                }
                store.exhaustivity = .off

                await store.send(.recordingFeature(.delegate(.recordingCompleted(recordingResult)))) {
                    $0.selectedTab = 1
                }
                XCTAssertFalse(store.state.showPaywall)
            }
        }
    }

    func testDismissPaywall_ResetsSource() async {
        var state = VoiceAppFeature.State()
        state.showPaywall = true
        state.paywallSource = .monthlyLaunch
        let store = TestStore(initialState: state) {
            VoiceAppFeature()
        }
        store.exhaustivity = .off
        await store.send(.view(.dismissPaywall)) {
            $0.showPaywall = false
            $0.paywallSource = .featureGate
        }
    }
}
