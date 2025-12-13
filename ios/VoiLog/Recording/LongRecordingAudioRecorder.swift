import Foundation
import AVFoundation
import UIKit
import os.log

actor LongRecordingAudioRecorder: NSObject {
    private var audioRecorder: AVAudioRecorder?
    private var startTime: Date?
    private var pausedDuration: TimeInterval = 0
    private var state: RecordingState = .idle
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    // ログカテゴリ
    private let logger = Logger(subsystem: "com.voilog.recording", category: "LongRecordingAudioRecorder")

    // MARK: - Public Interface

    func requestPermission() async -> Bool {
        logger.info("録音許可をリクエスト中...")
        let granted = await withUnsafeContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        logger.info("録音許可結果: \(granted ? "許可" : "拒否")")
        return granted
    }

    func startRecording(url: URL, configuration: RecordingConfiguration) async throws -> Bool {
        logger.info("録音開始: \(url.lastPathComponent), フォーマット: \(configuration.fileFormat.rawValue)")

        // 前回の状態をリセット
        resetState()
        logger.debug("録音状態をリセット完了")

        // オーディオセッションの設定
        do {
            try await setupAudioSession()
            logger.debug("オーディオセッション設定完了")
        } catch {
            logger.error("オーディオセッション設定失敗: \(error.localizedDescription)")
            throw error
        }

        // バックグラウンドタスクの開始
        beginBackgroundTask()
        logger.debug("バックグラウンドタスク開始")

        // AVAudioRecorderの作成と設定
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: configuration.recordingSettings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            logger.debug("AVAudioRecorder作成完了")

            // 録音開始
            guard audioRecorder?.record() == true else {
                logger.error("録音開始に失敗")
                state = .error(.recordingFailed("Failed to start recording"))
                endBackgroundTask()
                return false
            }

            startTime = Date()
            state = .recording(startTime: Date())
            logger.info("録音開始成功")
            return true

        } catch {
            logger.error("AVAudioRecorder作成失敗: \(error.localizedDescription)")
            state = .error(.fileCreationFailed)
            endBackgroundTask()
            throw error
        }
    }

    func stopRecording() async {
        logger.info("録音停止開始")
        let finalDuration = getCurrentTime()
        audioRecorder?.stop()

        state = .completed(duration: finalDuration)
        logger.info("録音停止完了 - 録音時間: \(String(format: "%.2f", finalDuration))秒")

        // リソースクリーンアップ
        await cleanupResources()
    }

    func pauseRecording() async {
        guard case .recording(let startTime) = state else {
            logger.warning("録音一時停止要求されたが、録音中ではない状態: \(String(describing: self.state))")
            return
        }

        logger.info("録音一時停止開始")
        let currentDuration = getCurrentTime()
        audioRecorder?.pause()

        let pauseTime = Date()
        state = .paused(startTime: startTime, pausedTime: pauseTime, duration: currentDuration)
        logger.info("録音一時停止完了 - 現在の録音時間: \(String(format: "%.2f", currentDuration))秒")
    }

    func resumeRecording() async {
        guard case .paused(let startTime, _, let duration) = state else {
            logger.warning("録音再開要求されたが、一時停止中ではない状態: \(String(describing: self.state))")
            return
        }

        logger.info("録音再開開始")
        pausedDuration += duration
        audioRecorder?.record()

        state = .recording(startTime: startTime)
        logger.info("録音再開完了")
    }

    func getCurrentTime() -> TimeInterval {
        guard let recorder = audioRecorder else { return 0 }
        return recorder.currentTime + pausedDuration
    }

    func getAudioLevel() -> Float {
        // 録音状態をチェック
        switch state {
        case .recording:
            guard let recorder = audioRecorder else {
                logger.debug("AudioLevel: レコーダーがnil、-60.0を返す")
                return -60.0
            }
            recorder.updateMeters()
            // デシベル値を取得（-160から0の範囲）
            let power = recorder.averagePower(forChannel: 0)
            // -60から0の範囲にクリップ
            let clippedPower = max(-60.0, min(0.0, power))

            // デバッグログ
            logger.debug("AudioLevel: Raw power: \(String(format: "%.2f", power)) dB, Clipped: \(String(format: "%.2f", clippedPower)) dB")
            UserDefaultsManager.shared.logError(String(format: "LongRecordingAudioRecorder - Power: %.2f dB, Clipped: %.2f dB", power, clippedPower))

            return clippedPower
        default:
            // 録音中でない場合は-60.0を返す
            return -60.0
        }
    }

    func getCurrentState() -> RecordingState {
        state
    }

    // MARK: - Private Methods

    private func resetState() {
        pausedDuration = 0
        startTime = nil
        state = .preparing
    }

    private func updateState(_ newState: RecordingState) {
        state = newState
    }

    private func setupAudioSession() async throws {
        logger.debug("オーディオセッション設定開始")
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
            logger.debug("オーディオセッションカテゴリ設定完了")

            // 長時間録音に最適化された設定
            try session.setPreferredIOBufferDuration(0.005) // 5ms バッファ
            logger.debug("IOバッファ設定完了: 5ms")

            try session.setActive(true, options: .notifyOthersOnDeactivation)
            logger.debug("オーディオセッションアクティブ化完了")

            // 割り込み通知の登録
            NotificationCenter.default.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { await self?.handleInterruption(notification) }
            }
            logger.debug("割り込み通知監視開始")

        } catch {
            logger.error("オーディオセッション設定エラー: \(error.localizedDescription)")
            state = .error(.audioSessionFailed)
            throw error
        }
    }

    private func beginBackgroundTask() {
        endBackgroundTask() // End any existing task first

        Task { @MainActor in
            let taskId = UIApplication.shared.beginBackgroundTask { [weak self] in
                Task { await self?.endBackgroundTask() }
            }
            await self.setBackgroundTaskId(taskId)
        }
    }

    private func endBackgroundTask() {
        let taskId = backgroundTask
        if taskId != .invalid {
            backgroundTask = .invalid
            Task { @MainActor in
                UIApplication.shared.endBackgroundTask(taskId)
            }
        }
    }

    private func setBackgroundTaskId(_ taskId: UIBackgroundTaskIdentifier) {
        backgroundTask = taskId
    }

    private func cleanupResources() async {
        audioRecorder = nil
        endBackgroundTask()

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
            logger.warning("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }

    // MARK: - Interruption Handling

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            logger.warning("割り込み通知の解析に失敗")
            return
        }

        switch type {
        case .began:
            // 割り込み開始 - 一時停止
            logger.info("オーディオ割り込み開始 - 録音を一時停止")
            Task { await pauseRecording() }

        case .ended:
            // 割り込み終了
            logger.info("オーディオ割り込み終了")
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                logger.warning("割り込み終了オプションの取得に失敗")
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)

            if options.contains(.shouldResume) {
                // 録音を再開
                logger.info("録音再開が推奨されています")
                Task {
                    do {
                        try AVAudioSession.sharedInstance().setActive(true)
                        await resumeRecording()
                    } catch {
                        logger.error("割り込み後のオーディオセッション再開に失敗: \(error.localizedDescription)")
                        state = .error(.audioSessionFailed)
                    }
                }
            } else {
                logger.info("録音再開は推奨されていません")
            }

        @unknown default:
            logger.warning("不明な割り込みタイプ: \(type.rawValue)")
            break
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension LongRecordingAudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task {
            if flag {
                let finalTime = await getCurrentTime()
                await updateState(.completed(duration: finalTime))
            } else {
                await updateState(.error(.recordingFailed("Recording finished unsuccessfully")))
            }
            await cleanupResources()
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task {
            let errorMessage = error?.localizedDescription ?? "Unknown encoding error"
            await updateState(.error(.recordingFailed(errorMessage)))
            await cleanupResources()
        }
    }
}
