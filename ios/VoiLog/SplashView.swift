//
//  SplashView.swift
//  VoiLog
//
//  Created by Claude on 2026.
//

import SwiftUI

struct SplashView: View {
    let onComplete: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景色
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // アプリアイコン
                    Image("AppIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .cornerRadius(24)
                        .shadow(radius: 10)

                    // アプリ名
                    Text("VoiLog")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("シンプル録音")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .onAppear {
            print("[SplashView] onAppear called")
            checkAndShowAd()
        }
    }

    private func checkAndShowAd() {
        let isPremium = UserDefaultsManager.shared.hasPurchasedProduct
        let appUsageCount = UserDefaults.standard.integer(forKey: "appUsageCount")

        print("[SplashView] checkAndShowAd - count: \(appUsageCount), isPremium: \(isPremium)")

        // プレミアムユーザーはスキップ
        guard !isPremium else {
            print("[SplashView] Skipping ad - premium user")
            completeAfterDelay(delay: 0.5)
            return
        }

        // 5回に1回広告表示
        let shouldShowAd = appUsageCount > 0 && appUsageCount % 5 == 0
        print("[SplashView] shouldShowAd: \(shouldShowAd) (count: \(appUsageCount) % 5 = \(appUsageCount % 5))")

        if shouldShowAd {
            print("[SplashView] Will load and show ad")
            // 広告をロードして表示
            loadAndShowAd()
        } else {
            // 広告表示しない回は短いスプラッシュ
            print("[SplashView] Not ad turn, completing after 1 second")
            completeAfterDelay(delay: 1.0)
        }
    }

    private func loadAndShowAd() {
        // 既に広告がロード済みの場合
        if InterstitialAdManager.shared.isAdReady {
            print("[SplashView] Ad already loaded, showing immediately")
            showAdAndComplete()
            return
        }

        print("[SplashView] Waiting for ad to load...")

        // 広告をプリロード（ロード完了を待つ）
        InterstitialAdManager.shared.preloadAd { [self] success in
            print("[SplashView] Ad preload completed - success: \(success)")
            if success {
                // ロード成功したら広告表示
                showAdAndComplete()
            } else {
                // ロード失敗したらスキップ
                print("[SplashView] Ad load failed, completing without ad")
                completeAfterDelay(delay: 0.5)
            }
        }

        // タイムアウト（5秒後に広告ロードを諦める）
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [self] in
            if !InterstitialAdManager.shared.isAdReady {
                print("[SplashView] Ad load timeout, completing without ad")
                completeAfterDelay(delay: 0.0)
            }
        }
    }

    private func showAdAndComplete() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            print("[SplashView] Calling showAdIfNeeded")
            let adShown = InterstitialAdManager.shared.showAdIfNeeded {
                // 広告が閉じられたら遷移
                print("[SplashView] Ad dismissed, completing")
                onComplete()
            }
            print("[SplashView] showAdIfNeeded returned: \(adShown)")
            if !adShown {
                // 広告が何らかの理由で表示されなかった場合
                print("[SplashView] No ad shown, completing after delay")
                completeAfterDelay(delay: 0.5)
            }
        }
    }

    private func completeAfterDelay(delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            print("[SplashView] Completing splash")
            onComplete()
        }
    }
}

#Preview {
    SplashView {
        print("Splash completed")
    }
}
