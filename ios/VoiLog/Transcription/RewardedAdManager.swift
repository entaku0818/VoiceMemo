import GoogleMobileAds
import UIKit

@MainActor
final class RewardedAdManager: NSObject {
    static let shared = RewardedAdManager()

    private var rewardedAd: RewardedAd?
    private var isLoading = false
    private var rewardEarned = false
    private var onRewarded: (() -> Void)?
    private var onSkipped: (() -> Void)?
    private var loadGeneration = 0

    var isAdReady: Bool { AdConsentManager.shared.canLoadAds && rewardedAd != nil }

    override private init() {
        super.init()
    }

    func preloadAd() {
        guard AdConsentManager.shared.canLoadAds, !isLoading, rewardedAd == nil else { return }
        isLoading = true
        let generation = loadGeneration

        #if DEBUG
        let adUnitID = "ca-app-pub-3940256099942544/1712485313"
        #else
        let adUnitID = Bundle.main.object(forInfoDictionaryKey: "REWARDED_ADMOB_KEY") as? String ?? ""
        #endif

        RewardedAd.load(with: adUnitID, request: Request()) { [weak self] ad, _ in
            guard let self, self.loadGeneration == generation else { return }
            self.isLoading = false
            if AdConsentManager.shared.canLoadAds, let ad {
                self.rewardedAd = ad
                self.rewardedAd?.fullScreenContentDelegate = self
            }
        }
    }

    func showAd(onRewarded: @escaping () -> Void, onSkipped: @escaping () -> Void) {
        self.onRewarded = onRewarded
        self.onSkipped = onSkipped
        self.rewardEarned = false

        guard AdConsentManager.shared.canLoadAds, let ad = rewardedAd,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            onSkipped()
            self.onRewarded = nil
            self.onSkipped = nil
            preloadAd()
            return
        }

        ad.present(from: rootVC) { [weak self] in
            self?.rewardEarned = true
            self?.onRewarded?()
            self?.onRewarded = nil
        }
    }

    func discardCachedAd() {
        loadGeneration += 1
        rewardedAd = nil
        isLoading = false
    }
}

extension RewardedAdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        rewardedAd = nil
        if !rewardEarned {
            onSkipped?()
        }
        onSkipped = nil
        onRewarded = nil
        rewardEarned = false
        preloadAd()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        rewardedAd = nil
        onSkipped?()
        onSkipped = nil
        onRewarded = nil
        rewardEarned = false
        preloadAd()
    }
}
