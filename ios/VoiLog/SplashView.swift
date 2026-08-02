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
private final class SplashCompletionGuard {
    private(set) var isCompleted = false

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

    /// 広告のロード完了・表示終了・5秒タイムアウトは互いに独立して発火するため、
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
            checkAndShowAd()
        }
    }

    private func checkAndShowAd() {
        let isPremium = userDefaults.hasPurchasedProduct()
        let appUsageCount = UserDefaults.standard.integer(forKey: "appUsageCount")

        // プレミアムユーザーはスキップ
        guard !isPremium else {
            completeAfterDelay(delay: 0.5)
            return
        }

        // AppOpenAdManager側の表示条件と必ず一致させる（別の間隔値を持たせない）
        let displayInterval = AppOpenAdManager.shared.displayInterval
        let shouldShowAd = appUsageCount > 0 && appUsageCount % displayInterval == 0

        if shouldShowAd {
            loadAndShowAd()
        } else {
            completeAfterDelay(delay: 1.0)
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
                completeAfterDelay(delay: 0.5)
            }
        }

        // タイムアウト（5秒後に広告ロードを諦める）
        // 広告を表示中の場合は、ユーザーが視聴し終えるまで待つ
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [self] in
            guard !AppOpenAdManager.shared.isPresentingAd else { return }
            complete()
        }
    }

    private func showAdAndComplete() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            // タイムアウト等で既に本編へ遷移済みなら、広告を後から被せない
            guard !completionGuard.isCompleted else { return }

            let adShown = AppOpenAdManager.shared.showAdIfNeeded {
                complete()
            }
            if !adShown {
                completeAfterDelay(delay: 0.5)
            }
        }
    }

    private func completeAfterDelay(delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            complete()
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
