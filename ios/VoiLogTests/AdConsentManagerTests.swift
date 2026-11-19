import XCTest
@testable import VoiLog

@MainActor
final class AdConsentManagerTests: XCTestCase {
    func testAdsWaitForConsentAndSDKInitializationAndInitializeOnlyOnce() {
        let sdk = ConsentSDKHarness()
        let manager = AdConsentManager(dependencies: sdk.dependencies)
        var completions = 0

        manager.gatherConsent { completions += 1 }
        manager.gatherConsent { completions += 1 }
        XCTAssertEqual(sdk.timeoutDelay, 1)
        XCTAssertEqual(sdk.updates, 1)
        XCTAssertEqual(sdk.sdkStarts, 0)
        XCTAssertFalse(manager.canLoadAds)

        sdk.allowed = true
        sdk.updateCompletion?(nil)
        XCTAssertEqual(sdk.sdkStarts, 1)
        XCTAssertFalse(manager.canLoadAds)
        XCTAssertEqual(completions, 0)

        sdk.sdkCompletion?()
        sdk.sdkCompletion?()
        XCTAssertTrue(manager.canLoadAds)
        XCTAssertEqual(completions, 2)
        sdk.updateCompletion?(nil)
        XCTAssertEqual(sdk.sdkStarts, 1)
        XCTAssertEqual(completions, 2)
    }

    func testTimeoutDoesNotPresentAFormFromLateUpdate() {
        let sdk = ConsentSDKHarness()
        let manager = AdConsentManager(dependencies: sdk.dependencies)
        var completions = 0
        manager.gatherConsent { completions += 1 }
        sdk.timeout?()

        sdk.requiresConsent = true
        sdk.updateCompletion?(nil)
        XCTAssertEqual(completions, 1)
        XCTAssertEqual(sdk.formLoads, 0)
        XCTAssertFalse(manager.canLoadAds)
        XCTAssertTrue(manager.shouldShowPrivacyOptions)
    }

    func testTimeoutDoesNotPresentAFormLoadedAfterMainScreenOpens() {
        let sdk = ConsentSDKHarness()
        sdk.requiresConsent = true
        let manager = AdConsentManager(dependencies: sdk.dependencies)
        var completions = 0
        manager.gatherConsent { completions += 1 }
        sdk.updateCompletion?(nil)
        XCTAssertEqual(sdk.formLoads, 1)

        sdk.timeout?()
        sdk.loadCompletion?(sdk.form, nil)
        XCTAssertEqual(completions, 1)
        XCTAssertEqual(sdk.formPresentations, 0)
        XCTAssertFalse(manager.isPresentingConsentForm)
    }

    func testPresentedFormWaitsForUserAndLateSDKCallbackDoesNotCompleteAgain() {
        let sdk = ConsentSDKHarness()
        sdk.requiresConsent = true
        let manager = AdConsentManager(dependencies: sdk.dependencies)
        var completions = 0
        manager.gatherConsent { completions += 1 }
        sdk.updateCompletion?(nil)
        sdk.loadCompletion?(sdk.form, nil)
        XCTAssertTrue(manager.isPresentingConsentForm)

        // Even an already-enqueued timeout cannot navigate away while the form is open.
        sdk.timeout?()
        XCTAssertEqual(completions, 0)

        sdk.requiresConsent = false
        sdk.allowed = true
        sdk.formCompletion?(nil)
        XCTAssertEqual(completions, 1)
        XCTAssertFalse(manager.isPresentingConsentForm)
        XCTAssertFalse(manager.canLoadAds)
        sdk.sdkCompletion?()
        XCTAssertTrue(manager.canLoadAds)
        XCTAssertEqual(completions, 1)
    }

    func testSDKInitializationTimeoutFinishesOnceAndCanEnableBannersLater() {
        let sdk = ConsentSDKHarness()
        sdk.allowed = true
        let manager = AdConsentManager(dependencies: sdk.dependencies)
        var completions = 0
        manager.gatherConsent { completions += 1 }
        sdk.updateCompletion?(nil)
        sdk.timeout?()
        XCTAssertEqual(completions, 1)
        XCTAssertFalse(manager.canLoadAds)

        sdk.sdkCompletion?()
        XCTAssertTrue(manager.canLoadAds)
        XCTAssertEqual(completions, 1)
    }

    func testPrivacyOptionsDiscardCachedAdsAndGateRequestsAfterRevocation() {
        let sdk = ConsentSDKHarness()
        sdk.allowed = true
        sdk.requiresPrivacyOptions = true
        let manager = AdConsentManager(dependencies: sdk.dependencies)
        manager.gatherConsent {}
        sdk.updateCompletion?(nil)
        sdk.sdkCompletion?()
        XCTAssertTrue(manager.canLoadAds)
        XCTAssertTrue(manager.isPrivacyOptionsRequired)
        let previousRevision = manager.adsRevision
        var privacyResult: Bool?

        manager.presentPrivacyOptions { privacyResult = $0 }
        XCTAssertEqual(sdk.privacyPresentations, 1)
        XCTAssertFalse(manager.canLoadAds)
        XCTAssertGreaterThan(manager.adsRevision, previousRevision)

        sdk.allowed = false
        sdk.privacyCompletion?(nil)
        XCTAssertEqual(privacyResult, true)
        XCTAssertFalse(manager.canLoadAds)
        XCTAssertFalse(manager.isPresentingConsentForm)
        XCTAssertGreaterThanOrEqual(sdk.cacheDiscards, 2)
    }

    func testSettingsRetryConsentAfterInitialUpdateFailure() {
        let sdk = ConsentSDKHarness()
        let manager = AdConsentManager(dependencies: sdk.dependencies)
        manager.gatherConsent {}
        sdk.updateCompletion?(URLError(.notConnectedToInternet))
        XCTAssertTrue(manager.shouldShowPrivacyOptions)

        var result: Bool?
        manager.presentPrivacyOptions { result = $0 }
        XCTAssertEqual(sdk.updates, 2)
        XCTAssertEqual(sdk.timeoutDelay, 10)
        sdk.updateCompletion?(nil)
        XCTAssertEqual(result, true)
        XCTAssertFalse(manager.shouldShowPrivacyOptions)
    }

    func testPremiumNeverAllowsAdsEvenWithConsentAndInitializedSDK() {
        let sdk = ConsentSDKHarness()
        sdk.allowed = true
        sdk.premium = true
        let manager = AdConsentManager(dependencies: sdk.dependencies)
        manager.gatherConsent {}
        sdk.updateCompletion?(nil)
        sdk.sdkCompletion?()
        XCTAssertEqual(sdk.updates, 1)
        XCTAssertFalse(manager.canLoadAds)

        sdk.premium = false
        XCTAssertTrue(manager.canLoadAds)
    }
}

@MainActor
private final class ConsentSDKHarness {
    var allowed = false
    var requiresConsent = false
    var requiresPrivacyOptions = false
    var premium = false
    var updates = 0
    var sdkStarts = 0
    var formLoads = 0
    var formPresentations = 0
    var privacyPresentations = 0
    var cacheDiscards = 0
    var updateCompletion: ((Error?) -> Void)?
    var loadCompletion: ((AdConsentDependencies.Form?, Error?) -> Void)?
    var formCompletion: ((Error?) -> Void)?
    var privacyCompletion: ((Error?) -> Void)?
    var sdkCompletion: (() -> Void)?
    var timeout: (() -> Void)?
    var timeoutDelay: TimeInterval?

    var form: AdConsentDependencies.Form {
        .init(present: { [unowned self] completion in
            self.formPresentations += 1
            self.formCompletion = completion
        })
    }

    var dependencies: AdConsentDependencies {
        .init(
            requestUpdate: { [unowned self] in self.updates += 1; self.updateCompletion = $0 },
            canRequestAds: { [unowned self] in self.allowed },
            consentRequired: { [unowned self] in self.requiresConsent },
            privacyOptionsRequired: { [unowned self] in self.requiresPrivacyOptions },
            loadForm: { [unowned self] in self.formLoads += 1; self.loadCompletion = $0 },
            presentPrivacyOptions: { [unowned self] in self.privacyPresentations += 1; self.privacyCompletion = $0 },
            startSDK: { [unowned self] in self.sdkStarts += 1; self.sdkCompletion = $0 },
            isPremium: { [unowned self] in self.premium },
            discardCachedAds: { [unowned self] in self.cacheDiscards += 1 },
            scheduleTimeout: { [unowned self] delay, callback in
                self.timeoutDelay = delay
                self.timeout = callback
                return {}
            }
        )
    }
}
