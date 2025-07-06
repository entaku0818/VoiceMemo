import Foundation
import AVFoundation
import UIKit

actor LongRecordingAudioRecorder: NSObject {
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var currentTime: TimeInterval = 0
    private var startTime: Date?
    private var pausedDuration: TimeInterval = 0
    private var state: RecordingState = .idle
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    // MARK: - Public Interface
    
    func requestPermission() async -> Bool {
        await withUnsafeContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func startRecording(url: URL, configuration: RecordingConfiguration) async throws -> Bool {
        // 前回の状態をリセット
        await resetState()
        
        // オーディオセッションの設定
        try await setupAudioSession()
        
        // バックグラウンドタスクの開始
        await beginBackgroundTask()
        
        // AVAudioRecorderの作成と設定
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: configuration.recordingSettings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            // 録音開始
            guard audioRecorder?.record() == true else {
                state = .error(.recordingFailed("Failed to start recording"))
                await endBackgroundTask()
                return false
            }
            
            startTime = Date()
            state = .recording(startTime: Date())
            await startTimer()
            return true
            
        } catch {
            state = .error(.fileCreationFailed)
            await endBackgroundTask()
            throw error
        }
    }
    
    func stopRecording() async {
        audioRecorder?.stop()
        await stopTimer()
        
        let finalDuration = currentTime
        state = .completed(duration: finalDuration)
        
        // リソースクリーンアップ
        await cleanupResources()
    }
    
    func pauseRecording() async {
        guard case .recording(let startTime) = state else { return }
        
        audioRecorder?.pause()
        await stopTimer()
        
        let pauseTime = Date()
        state = .paused(startTime: startTime, pausedTime: pauseTime, duration: currentTime)
    }
    
    func resumeRecording() async {
        guard case .paused(let startTime, _, let duration) = state else { return }
        
        pausedDuration += duration
        audioRecorder?.record()
        await startTimer()
        
        state = .recording(startTime: startTime)
    }
    
    func getCurrentTime() -> TimeInterval {
        return currentTime
    }
    
    func getAudioLevel() -> Float {
        guard let recorder = audioRecorder, recorder.isRecording else { return -160.0 }
        recorder.updateMeters()
        // デシベル値を0-1の範囲に正規化
        let power = recorder.averagePower(forChannel: 0)
        let normalizedPower = max(0.0, (power + 160.0) / 160.0)
        return normalizedPower
    }
    
    func getCurrentState() -> RecordingState {
        return state
    }
    
    // MARK: - Private Methods
    
    private func resetState() {
        currentTime = 0
        pausedDuration = 0
        startTime = nil
        state = .preparing
    }
    
    private func setupAudioSession() async throws {
        let session = AVAudioSession.sharedInstance()
        
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [
                    .defaultToSpeaker,
                    .allowBluetooth,
                    .allowBluetoothA2DP,
                    .mixWithOthers,
                    .duckOthers  // 他の音声を小さくして録音を継続
                ]
            )
            
            // 長時間録音に最適化された設定
            try session.setPreferredIOBufferDuration(0.005) // 5ms バッファ
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
            // 割り込み通知の登録
            NotificationCenter.default.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { await self?.handleInterruption(notification) }
            }
            
        } catch {
            state = .error(.audioSessionFailed)
            throw error
        }
    }
    
    private func startTimer() {
        Task { @MainActor in
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { await self?.updateCurrentTime() }
            }
        }
    }
    
    private func stopTimer() {
        Task { @MainActor in
            recordingTimer?.invalidate()
            recordingTimer = nil
        }
    }
    
    private func updateCurrentTime() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        currentTime = recorder.currentTime + pausedDuration
    }
    
    private func beginBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            Task { await self?.endBackgroundTask() }
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    private func cleanupResources() async {
        audioRecorder = nil
        await endBackgroundTask()
        
        // 割り込み通知の削除
        NotificationCenter.default.removeObserver(
            self,
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        // オーディオセッションの非アクティブ化
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            // ログ出力のみ、エラーは無視
            print("Failed to deactivate audio session: \(error)")
        }
    }
    
    // MARK: - Interruption Handling
    
    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // 割り込み開始 - 一時停止
            Task { await pauseRecording() }
            
        case .ended:
            // 割り込み終了
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            if options.contains(.shouldResume) {
                // 録音を再開
                Task {
                    do {
                        try AVAudioSession.sharedInstance().setActive(true)
                        await resumeRecording()
                    } catch {
                        state = .error(.audioSessionFailed)
                    }
                }
            }
            
        @unknown default:
            break
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension LongRecordingAudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task {
            if flag {
                state = .completed(duration: currentTime)
            } else {
                state = .error(.recordingFailed("Recording finished unsuccessfully"))
            }
            await cleanupResources()
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task {
            let errorMessage = error?.localizedDescription ?? "Unknown encoding error"
            state = .error(.recordingFailed(errorMessage))
            await cleanupResources()
        }
    }
}