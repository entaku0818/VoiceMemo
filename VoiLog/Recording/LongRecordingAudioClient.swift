import Foundation
import ComposableArchitecture

struct LongRecordingAudioClient {
    var currentTime: @Sendable () async -> TimeInterval
    var requestRecordPermission: @Sendable () async -> Bool
    var startRecording: @Sendable (URL, RecordingConfiguration) async throws -> Bool
    var stopRecording: @Sendable () async -> Void
    var pauseRecording: @Sendable () async -> Void
    var resumeRecording: @Sendable () async -> Void
    var audioLevel: @Sendable () async -> Float
    var recordingState: @Sendable () async -> RecordingState
}

extension LongRecordingAudioClient: TestDependencyKey {
    static var previewValue: Self {
        let isRecording = ActorIsolated(false)
        let isPaused = ActorIsolated(false)
        let currentTime = ActorIsolated(0.0)
        let recordingState = ActorIsolated(RecordingState.idle)

        return Self(
            currentTime: { await currentTime.value },
            requestRecordPermission: { true },
            startRecording: { _, _ in
                await isRecording.setValue(true)
                await recordingState.setValue(.recording(startTime: Date()))
                
                // シミュレーション用の時間更新
                Task {
                    while await isRecording.value && !isPaused.value {
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                        await currentTime.withValue { $0 += 0.1 }
                    }
                }
                
                return true
            },
            stopRecording: {
                await isRecording.setValue(false)
                let finalTime = await currentTime.value
                await recordingState.setValue(.completed(duration: finalTime))
                await currentTime.setValue(0)
            },
            pauseRecording: {
                await isPaused.setValue(true)
                let startTime = Date()
                let duration = await currentTime.value
                await recordingState.setValue(.paused(startTime: startTime, pausedTime: Date(), duration: duration))
            },
            resumeRecording: {
                await isPaused.setValue(false)
                await recordingState.setValue(.recording(startTime: Date()))
            },
            audioLevel: { 0.5 }, // プレビュー用の固定値
            recordingState: { await recordingState.value }
        )
    }

    static let testValue = Self(
        currentTime: unimplemented("\(Self.self).currentTime", placeholder: 0),
        requestRecordPermission: unimplemented("\(Self.self).requestRecordPermission", placeholder: false),
        startRecording: unimplemented("\(Self.self).startRecording", placeholder: false),
        stopRecording: unimplemented("\(Self.self).stopRecording"),
        pauseRecording: unimplemented("\(Self.self).pauseRecording"),
        resumeRecording: unimplemented("\(Self.self).resumeRecording"),
        audioLevel: unimplemented("\(Self.self).audioLevel", placeholder: 0.0),
        recordingState: unimplemented("\(Self.self).recordingState", placeholder: .idle)
    )
}

extension DependencyValues {
    var longRecordingAudioClient: LongRecordingAudioClient {
        get { self[LongRecordingAudioClient.self] }
        set { self[LongRecordingAudioClient.self] = newValue }
    }
}

extension LongRecordingAudioClient: DependencyKey {
    static var liveValue: Self {
        let audioRecorder = LongRecordingAudioRecorder()
        
        return Self(
            currentTime: { await audioRecorder.getCurrentTime() },
            requestRecordPermission: { await audioRecorder.requestPermission() },
            startRecording: { url, config in 
                try await audioRecorder.startRecording(url: url, configuration: config)
            },
            stopRecording: { await audioRecorder.stopRecording() },
            pauseRecording: { await audioRecorder.pauseRecording() },
            resumeRecording: { await audioRecorder.resumeRecording() },
            audioLevel: { await audioRecorder.getAudioLevel() },
            recordingState: { await audioRecorder.getCurrentState() }
        )
    }
}