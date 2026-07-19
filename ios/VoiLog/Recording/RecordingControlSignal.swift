//
//  RecordingControlSignal.swift
//  VoiLog
//
//  ライブアクティビティ/Dynamic Islandのボタン（issue #189）から送られる操作信号。
//
//  ライブアクティビティのボタンはWidget Extensionのプロセスで実行される`LiveActivityIntent`
//  （`ios/recordActivity/RecordingControlIntents.swift`）が起点になるため、実際の録音を
//  行っているこのアプリのプロセスへはDarwin Notificationで伝える。通知名はそちらの値と
//  一致させること。
//

import ComposableArchitecture
import Foundation

enum RecordingControlSignal {
    static let pause = "com.entaku.VoiLog.liveActivity.pause"
    static let resume = "com.entaku.VoiLog.liveActivity.resume"
    static let stop = "com.entaku.VoiLog.liveActivity.stop"
}

@MainActor
final class RecordingControlSignalObserver {
    static let shared = RecordingControlSignalObserver()

    private var isObserving = false

    private init() {}

    func startObserving() {
        guard !isObserving else { return }
        isObserving = true

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()

        for name in [RecordingControlSignal.pause, RecordingControlSignal.resume, RecordingControlSignal.stop] {
            CFNotificationCenterAddObserver(
                center,
                observer, { _, observer, name, _, _ in
                    guard let observer, let name else { return }
                    let instance = Unmanaged<RecordingControlSignalObserver>.fromOpaque(observer).takeUnretainedValue()
                    let signalName = name.rawValue as String
                    Task { @MainActor in
                        await instance.handle(signalName: signalName)
                    }
                },
                name as CFString,
                nil,
                .deliverImmediately
            )
        }
    }

    func handle(signalName: String, store: StoreOf<VoiceAppFeature> = AppEnvironment.store) async {
        switch signalName {
        case RecordingControlSignal.pause, RecordingControlSignal.resume:
            handlePauseResume(store: store)
        case RecordingControlSignal.stop:
            await handleStop(store: store)
        default:
            break
        }
    }

    private func handlePauseResume(store: StoreOf<VoiceAppFeature>) {
        let state = store.recordingFeature.recordingState
        guard state == .recording || state == .paused else { return }
        store.send(.recordingFeature(.view(.pauseResumeButtonTapped)))
    }

    private func handleStop(store: StoreOf<VoiceAppFeature>) async {
        let state = store.recordingFeature.recordingState
        guard state == .recording || state == .paused else { return }
        store.send(.recordingFeature(.view(.stopButtonTapped)))
        try? await Task.sleep(nanoseconds: 300_000_000)
        store.send(.recordingFeature(.view(.skipTitle)))
    }
}
