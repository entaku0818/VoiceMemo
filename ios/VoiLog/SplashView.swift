//
//  SplashView.swift
//  VoiLog
//
//  Created by Claude on 2026.
//

import SwiftUI
import Dependencies

/// onCompleteが二重に呼ばれるのを防ぐためのフラグ置き場。
/// SplashViewは値型なので、escapingクロージャ間で状態を共有するには参照型が必要。
final class SplashCompletionGuard {
    private var hasStarted = false
    private var hasResolvedPremium = false
    private(set) var isCompleted = false
    private(set) var isPremiumStatusVerified = false

    func begin() -> Bool {
        guard !hasStarted else { return false }
        hasStarted = true
        return true
    }

    /// A slow purchase refresh and its timeout must not both start consent gathering.
    func resolvePremium(isVerified: Bool = false) -> Bool {
        guard !hasResolvedPremium, !isCompleted else { return false }
        hasResolvedPremium = true
        isPremiumStatusVerified = isVerified
        return true
    }

    /// 初回のみtrueを返す。2回目以降は常にfalse。
    func claim() -> Bool {
        guard !isCompleted else { return false }
        isCompleted = true
        return true
    }
}

struct SplashView: View {
    let onComplete: () -> Void
    @Dependency(\.userDefaults) var userDefaults

    static let maximumAdWait: TimeInterval = 1
    static let maximumPremiumRefreshWait: TimeInterval = 1

    /// 広告のロード完了・表示終了・タイムアウトは互いに独立して発火するため、
    /// ガードが無いとonCompleteが複数回呼ばれる（タイムアウト後に広告がロードされると
    /// 本編UIの上にApp Open広告が被さる）
    @State private var completionGuard = SplashCompletionGuard()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景色
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // アプリアイコン
                    Image(.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .cornerRadius(24)
                        .shadow(radius: 10)

                    // アプリ名
                    Text(String(localized: "シンプル録音"))
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .onAppear {
            prepareAds()
        }
    }

    private func prepareAds() {
        guard completionGuard.begin() else { return }

        // Offline purchase checks must not prevent the user from starting a recording.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.maximumPremiumRefreshWait) {
            gatherConsentAfterPremiumRefresh()
        }
        Task { @MainActor in
            let isPremium = await PurchaseManager.shared.refreshPremiumStatus()
            if let isPremium {
                // Also apply a response that arrives after the splash has finished.
                AppEnvironment.store.send(.premiumStatusRefreshed(isPremium))
            }
            gatherConsentAfterPremiumRefresh(isVerified: isPremium != nil)
        }
    }

    private func gatherConsentAfterPremiumRefresh(isVerified: Bool = false) {
        guard completionGuard.resolvePremium(isVerified: isVerified) else { return }
        AdConsentManager.shared.gatherConsent {
            guard !completionGuard.isCompleted else { return }
            checkAndShowAd()
        }
    }

    private func checkAndShowAd() {
        let isPremium = userDefaults.hasPurchasedProduct()
        let appUsageCount = UserDefaults.standard.integer(forKey: "appUsageCount")

        // プレミアムユーザーはスキップ
        // Do not put a full-screen ad in front of a subscriber whose status is still unknown.
        guard completionGuard.isPremiumStatusVerified,
              !isPremium, AdConsentManager.shared.canLoadAds else {
            complete()
            return
        }

        // AppOpenAdManager側の表示条件と必ず一致させる（別の間隔値を持たせない）
        let displayInterval = AppOpenAdManager.shared.displayInterval
        let shouldShowAd = appUsageCount > 0 && appUsageCount % displayInterval == 0

        if shouldShowAd {
            loadAndShowAd()
        } else {
            AppOpenAdManager.shared.preloadAd()
            complete()
        }
    }

    private func loadAndShowAd() {
        // 既に広告がロード済みの場合
        if AppOpenAdManager.shared.isAdReady {
            showAdAndComplete()
            return
        }

        // 広告をプリロード（ロード完了を待つ）
        AppOpenAdManager.shared.preloadAd { [self] success in
            if success {
                showAdAndComplete()
            } else {
                complete()
            }
        }

        // 広告だけを待つ時間は最大1秒。遅い広告は次回へ回す。
        // 広告を表示中の場合は、ユーザーが視聴し終えるまで待つ
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.maximumAdWait) { [self] in
            guard !AppOpenAdManager.shared.isPresentingAd else { return }
            complete()
        }
    }

    private func showAdAndComplete() {
        DispatchQueue.main.async { [self] in
            // タイムアウト等で既に本編へ遷移済みなら、広告を後から被せない
            guard !completionGuard.isCompleted else { return }

            let adShown = AppOpenAdManager.shared.showAdIfNeeded {
                complete()
            }
            if !adShown {
                complete()
            }
        }
    }

    /// onCompleteを最大1回だけ呼ぶ
    private func complete() {
        guard completionGuard.claim() else { return }
        onComplete()
    }
}

#Preview {
    SplashView {
    }
}
