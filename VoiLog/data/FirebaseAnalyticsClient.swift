import Foundation
import Dependencies
import FirebaseAnalytics

// MARK: - Firebase Analytics Client
struct FirebaseAnalyticsClient {
    var logEvent: (String, [String: Any]?) -> Void
    var setUserProperty: (String?, String) -> Void
    var setUserId: (String?) -> Void
}

// MARK: - Dependency Key
private enum FirebaseAnalyticsClientKey: DependencyKey {
    static let liveValue = FirebaseAnalyticsClient(
        logEvent: { eventName, parameters in
            Analytics.logEvent(eventName, parameters: parameters)
        },
        setUserProperty: { value, property in
            Analytics.setUserProperty(value, forName: property)
        },
        setUserId: { userId in
            Analytics.setUserID(userId)
        }
    )

    static let previewValue = FirebaseAnalyticsClient(
        logEvent: { eventName, parameters in
            print("📊 Analytics Event: \(eventName), Parameters: \(parameters ?? [:])")
        },
        setUserProperty: { value, property in
            print("📊 Analytics User Property: \(property) = \(value ?? "nil")")
        },
        setUserId: { userId in
            print("📊 Analytics User ID: \(userId ?? "nil")")
        }
    )

    static let testValue: FirebaseAnalyticsClient = previewValue
}

extension DependencyValues {
    var firebaseAnalytics: FirebaseAnalyticsClient {
        get { self[FirebaseAnalyticsClientKey.self] }
        set { self[FirebaseAnalyticsClientKey.self] = newValue }
    }
}

// MARK: - Analytics Events
extension FirebaseAnalyticsClient {
    // Paywall関連のイベント
    enum PaywallEvent {
        static let paywallViewed = "paywall_viewed"
        static let paywallPurchaseAttempted = "paywall_purchase_attempted"
        static let paywallPurchaseCompleted = "paywall_purchase_completed"
        static let paywallPurchaseFailed = "paywall_purchase_failed"
        static let paywallRestoreAttempted = "paywall_restore_attempted"
        static let paywallRestoreCompleted = "paywall_restore_completed"
        static let paywallRestoreFailed = "paywall_restore_failed"
        static let paywallDismissed = "paywall_dismissed"
    }

    // Recording関連のイベント
    enum RecordingEvent {
        static let recordingStarted = "recording_started"
        static let recordingCompleted = "recording_completed"
        static let recordingSaved = "recording_saved"
        static let recordingCancelled = "recording_cancelled"
    }

    // Playback関連のイベント
    enum PlaybackEvent {
        static let playbackStarted = "playback_started"
        static let playbackCompleted = "playback_completed"
        static let playbackPaused = "playback_paused"
        static let playbackStopped = "playback_stopped"
    }

    // User Property Keys
    enum UserProperty {
        static let premiumUser = "premium_user"
        static let totalRecordings = "total_recordings"
        static let appVersion = "app_version"
    }
}
