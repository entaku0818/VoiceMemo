import Foundation
import ComposableArchitecture
import ActivityKit

struct LiveActivityClient {
    var startActivity: @Sendable () async -> Void
    var updateActivity: @Sendable (TimeInterval, Bool) async -> Void
    var endActivity: @Sendable () async -> Void
}

extension LiveActivityClient: TestDependencyKey {
    static let testValue = Self(
        startActivity: unimplemented("\(Self.self).startActivity"),
        updateActivity: unimplemented("\(Self.self).updateActivity"),
        endActivity: unimplemented("\(Self.self).endActivity")
    )

    static let previewValue = Self(
        startActivity: {},
        updateActivity: { _, _ in },
        endActivity: {}
    )
}

extension DependencyValues {
    var liveActivityClient: LiveActivityClient {
        get { self[LiveActivityClient.self] }
        set { self[LiveActivityClient.self] = newValue }
    }
}

extension LiveActivityClient: DependencyKey {
    static var liveValue: Self {
        let manager = LiveActivityManager()
        return Self(
            startActivity: { await manager.startActivity() },
            updateActivity: { time, isPaused in await manager.updateActivity(recordingTime: time, isPaused: isPaused) },
            endActivity: { await manager.endActivity() }
        )
    }
}

private actor LiveActivityManager {
    private var currentActivity: Activity<RecordActivityAttributes>?

    func startActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = RecordActivityAttributes(name: "シンプル録音")
        let contentState = RecordActivityAttributes.ContentState(
            emoji: "🔴",
            recordingTime: 0,
            isPaused: false
        )
        // staleDate を8時間後に設定（クラッシュ時の自動消去用）
        let staleDate = Date().addingTimeInterval(8 * 60 * 60)
        let activityContent = ActivityContent(state: contentState, staleDate: staleDate)

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: activityContent,
                pushType: nil
            )
        } catch {
            // Live Activity might not be available (older devices, disabled in settings)
        }
    }

    func updateActivity(recordingTime: TimeInterval, isPaused: Bool) async {
        guard let activity = currentActivity else { return }
        let emoji = isPaused ? "⏸️" : "🔴"
        let contentState = RecordActivityAttributes.ContentState(
            emoji: emoji,
            recordingTime: recordingTime,
            isPaused: isPaused
        )
        let activityContent = ActivityContent(state: contentState, staleDate: nil)
        await activity.update(activityContent)
    }

    func endActivity() async {
        guard let activity = currentActivity else { return }
        let finalState = RecordActivityAttributes.ContentState(
            emoji: "⏹️",
            recordingTime: 0,
            isPaused: false
        )
        let finalContent = ActivityContent(state: finalState, staleDate: Date())
        await activity.end(finalContent, dismissalPolicy: .immediate)
        currentActivity = nil
    }
}
