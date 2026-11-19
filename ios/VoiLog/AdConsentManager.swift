import GoogleMobileAds
import Observation
import UIKit
import UserMessagingPlatform

/// UMP owns consent persistence. All SDK callbacks and state changes run on the main thread.
@Observable
@MainActor
final class AdConsentManager {
    static let shared = AdConsentManager(dependencies: .live)

    private(set) var canRequestAds = false
    private(set) var isPrivacyOptionsRequired = false
    private(set) var isConsentRequired = false
    private(set) var hasUpdatedConsentInformation = false
    private(set) var isPresentingConsentForm = false
    private(set) var isSDKInitialized = false
    private(set) var adsRevision = 0
    private(set) var didFailConsentRequest = false

    var canLoadAds: Bool {
        canRequestAds && isSDKInitialized && !isPresentingConsentForm && !dependencies.isPremium()
    }

    var shouldShowPrivacyOptions: Bool {
        isPrivacyOptionsRequired || isConsentRequired || !hasUpdatedConsentInformation
    }

    var isGatheringConsent: Bool { requestID != nil }

    private enum Phase {
        case updating, loadingForm, presentingForm, waitingForSDK
    }

    @ObservationIgnored private let dependencies: AdConsentDependencies
    private var requestID: UUID?
    @ObservationIgnored private var phase: Phase?
    @ObservationIgnored private var completions: [() -> Void] = []
    @ObservationIgnored private var cancelTimeout: (() -> Void)?
    @ObservationIgnored private var isStartingSDK = false
    @ObservationIgnored private var privacyOptionsID: UUID?

    init(dependencies: AdConsentDependencies) {
        self.dependencies = dependencies
    }

    /// Call once each launch, before requesting ads. Concurrent callers share the same flow.
    /// Launch uses a one-second budget; a settings retry can wait longer. An open form waits for input.
    func gatherConsent(timeout: TimeInterval = 1, completion: @escaping () -> Void) {
        completions.append(completion)
        guard requestID == nil, !isPresentingConsentForm else { return }

        let id = UUID()
        requestID = id
        phase = .updating
        didFailConsentRequest = false
        cancelTimeout = dependencies.scheduleTimeout(timeout) { [weak self] in
            guard let self, self.requestID == id, self.phase != .presentingForm else { return }
            self.didFailConsentRequest = true
            self.finish(id)
        }

        dependencies.requestUpdate { [weak self] error in
            guard let self else { return }
            if error == nil { self.hasUpdatedConsentInformation = true }
            self.refreshConsentState()
            // A timed-out update may refresh permission, but must never present a late form.
            guard self.requestID == id else { return }
            if error != nil {
                self.didFailConsentRequest = true
                self.finishWhenSDKReady(id)
            } else if self.isConsentRequired {
                self.loadRequiredForm(id)
            } else {
                self.finishWhenSDKReady(id)
            }
        }
        // UMP restores the previous session's decision synchronously when update is requested.
        refreshConsentState()
    }

    /// This entry point is only called in response to a user tapping the settings button.
    func presentPrivacyOptions(completion: @escaping (Bool) -> Void) {
        guard !isGatheringConsent, !isPresentingConsentForm else {
            completion(false)
            return
        }
        guard hasUpdatedConsentInformation, !isConsentRequired else {
            gatherConsent(timeout: 10) { [weak self] in
                guard let self else { completion(false); return }
                completion(!self.didFailConsentRequest && !self.isConsentRequired)
            }
            return
        }
        guard isPrivacyOptionsRequired else {
            completion(true)
            return
        }

        let id = UUID()
        privacyOptionsID = id
        isPresentingConsentForm = true
        invalidateCachedAds()
        dependencies.presentPrivacyOptions { [weak self] error in
            guard let self, self.privacyOptionsID == id else { return }
            self.privacyOptionsID = nil
            self.isPresentingConsentForm = false
            self.didFailConsentRequest = error != nil
            self.refreshConsentState()
            self.invalidateCachedAds()
            completion(error == nil)
            self.completeWaiters()
        }
    }

    private func loadRequiredForm(_ id: UUID) {
        phase = .loadingForm
        dependencies.loadForm { [weak self] form, error in
            guard let self, self.requestID == id, self.phase == .loadingForm else { return }
            guard error == nil, let form else {
                self.didFailConsentRequest = true
                self.finishWhenSDKReady(id)
                return
            }
            self.phase = .presentingForm
            self.isPresentingConsentForm = true
            self.cancelTimeout?()
            self.cancelTimeout = nil
            self.invalidateCachedAds()
            form.present { [weak self] error in
                guard let self, self.requestID == id, self.phase == .presentingForm else { return }
                self.isPresentingConsentForm = false
                self.didFailConsentRequest = error != nil
                self.refreshConsentState()
                self.invalidateCachedAds()
                // Do not add another SDK/network wait after the user dismisses the form.
                self.finish(id)
            }
        }
    }

    private func refreshConsentState() {
        let previouslyAllowed = canRequestAds
        canRequestAds = dependencies.canRequestAds()
        isPrivacyOptionsRequired = dependencies.privacyOptionsRequired()
        isConsentRequired = dependencies.consentRequired()
        if previouslyAllowed && !canRequestAds { invalidateCachedAds() }

        guard canRequestAds, !isStartingSDK, !isSDKInitialized else { return }
        isStartingSDK = true
        dependencies.startSDK { [weak self] in
            guard let self, !self.isSDKInitialized else { return }
            self.isSDKInitialized = true
            self.isStartingSDK = false
            if self.phase == .waitingForSDK, let id = self.requestID {
                self.finish(id)
            }
        }
    }

    private func finishWhenSDKReady(_ id: UUID) {
        guard requestID == id else { return }
        if canRequestAds && !isSDKInitialized {
            phase = .waitingForSDK
        } else {
            finish(id)
        }
    }

    private func finish(_ id: UUID) {
        guard requestID == id else { return }
        requestID = nil
        phase = nil
        cancelTimeout?()
        cancelTimeout = nil
        completeWaiters()
    }

    private func completeWaiters() {
        let waiting = completions
        completions.removeAll()
        waiting.forEach { $0() }
    }

    private func invalidateCachedAds() {
        adsRevision += 1
        dependencies.discardCachedAds()
    }
}

/// Small SDK boundary lets tests drive late network callbacks without opening real consent forms.
@MainActor
struct AdConsentDependencies {
    struct Form {
        var present: (@escaping (Error?) -> Void) -> Void
    }

    var requestUpdate: (@escaping (Error?) -> Void) -> Void
    var canRequestAds: () -> Bool
    var consentRequired: () -> Bool
    var privacyOptionsRequired: () -> Bool
    var loadForm: (@escaping (Form?, Error?) -> Void) -> Void
    var presentPrivacyOptions: (@escaping (Error?) -> Void) -> Void
    var startSDK: (@escaping () -> Void) -> Void
    var isPremium: () -> Bool
    var discardCachedAds: () -> Void
    var scheduleTimeout: (TimeInterval, @escaping () -> Void) -> (() -> Void)

    static let live = Self(
        requestUpdate: { completion in
            ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters(), completionHandler: completion)
        },
        canRequestAds: { ConsentInformation.shared.canRequestAds },
        consentRequired: { ConsentInformation.shared.consentStatus == .required },
        privacyOptionsRequired: { ConsentInformation.shared.privacyOptionsRequirementStatus == .required },
        loadForm: { completion in
            ConsentForm.load { form, error in
                completion(form.map { form in Form { form.present(from: nil, completionHandler: $0) } }, error)
            }
        },
        presentPrivacyOptions: { ConsentForm.presentPrivacyOptionsForm(from: nil, completionHandler: $0) },
        startSDK: { completion in MobileAds.shared.start { _ in completion() } },
        isPremium: { UserDefaults.standard.bool(forKey: "HasPurchasedProduct") },
        discardCachedAds: {
            AppOpenAdManager.shared.discardCachedAd()
            RewardedAdManager.shared.discardCachedAd()
        },
        scheduleTimeout: { delay, callback in
            let work = DispatchWorkItem(block: callback)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
            return { work.cancel() }
        }
    )
}
