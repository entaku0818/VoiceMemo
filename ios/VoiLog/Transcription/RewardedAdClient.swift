import ComposableArchitecture
import Foundation

struct RewardedAdClient {
    var preload: @Sendable () -> Void
    var show: @Sendable (@escaping @Sendable () -> Void, @escaping @Sendable () -> Void) async -> Void
}

extension RewardedAdClient: DependencyKey {
    static let liveValue = RewardedAdClient(
        preload: {
            Task { @MainActor in RewardedAdManager.shared.preloadAd() }
        },
        show: { onRewarded, onSkipped in
            await withCheckedContinuation { continuation in
                Task { @MainActor in
                    RewardedAdManager.shared.showAd(
                        onRewarded: {
                            onRewarded()
                            continuation.resume()
                        },
                        onSkipped: {
                            onSkipped()
                            continuation.resume()
                        }
                    )
                }
            }
        }
    )

    static let testValue = RewardedAdClient(
        preload: { },
        show: { _, onSkipped in onSkipped() }
    )
}

extension DependencyValues {
    var rewardedAdClient: RewardedAdClient {
        get { self[RewardedAdClient.self] }
        set { self[RewardedAdClient.self] = newValue }
    }
}
