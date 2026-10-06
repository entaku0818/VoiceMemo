import Foundation
import AVFoundation
import UIKit
import os.log

actor LongRecordingAudioRecorder: NSObject {
    /// いま書いている区切りのレコーダー。メディアリセットや予期しない停止のあとは nil（再開時に次の区切りを作る）
    private var audioRecorder: AVAudioRecorder?
    private var startTime: Date?
    private var state: RecordingState = .idle
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    // 区切り録音（#224）
    /// 停止時に区切りをつないで書き出す先（従来どおり `Documents/<UUID>.<ext>`）
    private var finalURL: URL?
    private var segmentDirectory: URL?
    private var segmentURLs: [URL] = []
    /// 書き終えた区切りの合計の長さ
    private var finishedSegmentsDuration: TimeInterval = 0
    /// 現在の区切りで最後に確認できた長さ。レコーダーが勝手に止まると currentTime が 0 に戻るので覚えておく
    private var lastObservedSegmentTime: TimeInterval = 0
    private var rotationTask: Task<Void, Never>?
    private let journal: RecordingJournal
    private let segmentDuration: TimeInterval
    private let rotationCheckInterval: Duration

    // 割り込み（#226）
    /// NotificationCenter のブロック版 addObserver が返すトークン。`removeObserver(self)` では外れないので保持して外す
    private var observerTokens: [NSObjectProtocol] = []
    /// 割り込みで止めたか（ユーザーが自分で一時停止した場合は、割り込みが終わっても再開しない）
    private var pausedByInterruption = false

    // ログカテゴリ
    private let logger = Logger(subsystem: "com.voilog.recording", category: "LongRecordingAudioRecorder")

    /// - Parameters:
    ///   - segmentDuration: 1つの区切りの長さ（テストでは短くする）
    ///   - rotationCheckInterval: 区切りを切り替えるか確かめる間隔
    init(
        segmentDuration: TimeInterval = RecordingSegments.segmentDuration,
        rotationCheckInterval: Duration = .seconds(10),
        journal: RecordingJournal = RecordingJournal()
    ) {
        self.segmentDuration = segmentDuration
        self.rotationCheckInterval = rotationCheckInterval
        self.journal = journal
        super.init()
    }

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

    private var recordingConfiguration: RecordingConfiguration = .default

    func startRecording(url: URL, configuration: RecordingConfiguration) async throws -> Bool {
        recordingConfiguration = configuration
        logger.info("録音開始: \(url.lastPathComponent), フォーマット: \(configuration.fileFormat.rawValue)")

        // 前回の状態をリセット
        resetState()

        do {
            try configureAudioSession()
            registerObservers()
        } catch {
            logger.error("オーディオセッション設定失敗: \(error.localizedDescription)")
            state = .error(.audioSessionFailed)
            throw error
        }

        beginBackgroundTask()

        let directory = RecordingSegments.directory(for: url)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            logger.error("区切り用ディレクトリの作成に失敗: \(error.localizedDescription)")
            state = .error(.fileCreationFailed)
            endBackgroundTask()
            throw error
        }
        finalURL = url
        segmentDirectory = directory

        do {
            guard try startNewSegment() else {
                logger.error("録音開始に失敗")
                state = .error(.recordingFailed("Failed to start recording"))
                endBackgroundTask()
                return false
            }
        } catch {
            logger.error("AVAudioRecorder作成失敗: \(error.localizedDescription)")
            state = .error(.fileCreationFailed)
            endBackgroundTask()
            throw error
        }

        // 強制終了したら次の起動で取り込めるよう、録音中であることを記録する（#223）
        journal.add(finalURL: url)

        startTime = Date()
        state = .recording(startTime: Date())
        startRotationTask()
        logger.info("録音開始成功")
        return true
    }

    func stopRecording() async {
        logger.info("録音停止開始")
        let finalDuration = getCurrentTime()
        rotationTask?.cancel()
        rotationTask = nil
        let recorder = audioRecorder
        // 先に外しておくと、stop() 後に届く delegate の完了通知を「予期しない停止」と取り違えない
        audioRecorder = nil
        recorder?.stop()

        state = .completed(duration: finalDuration)
        logger.info("録音停止完了 - 録音時間: \(String(format: "%.2f", finalDuration))秒")

        await finalizeSegments()
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

        state = .paused(startTime: startTime, pausedTime: Date(), duration: currentDuration)
        logger.info("録音一時停止完了 - 現在の録音時間: \(String(format: "%.2f", currentDuration))秒")
    }

    func resumeRecording() async {
        _ = resume()
    }

    func getCurrentTime() -> TimeInterval {
        let segmentTime = audioRecorder?.currentTime ?? 0
        if segmentTime > 0 {
            lastObservedSegmentTime = segmentTime
        }
        return finishedSegmentsDuration + segmentTime
    }

    func getAudioLevel() -> Float {
        guard case .recording = state, let recorder = audioRecorder else { return -60.0 }
        recorder.updateMeters()
        // デシベル値（-160〜0）を -60〜0 にクリップする。
        // 以前はここで毎回 UserDefaults にログを書いていた（100ms ごと = 16時間で約57万回）ので削除した（#225）
        return max(-60.0, min(0.0, recorder.averagePower(forChannel: 0)))
    }

    func getCurrentState() -> RecordingState {
        state
    }

    /// 一覧へ保存し終えたら呼ぶ。次の起動で同じ録音を復旧し直さないよう記録を消す（#223）
    func markRecordingSaved(url: URL) {
        journal.remove(finalURL: url)
    }

    // MARK: - Private Methods

    private func resetState() {
        startTime = nil
        state = .preparing
        audioRecorder = nil
        finalURL = nil
        segmentDirectory = nil
        segmentURLs = []
        finishedSegmentsDuration = 0
        lastObservedSegmentTime = 0
        pausedByInterruption = false
        rotationTask?.cancel()
        rotationTask = nil
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        // ノイズキャンセリング or AGC が有効な場合は .voiceChat モードを使用
        let useVoiceProcessing = recordingConfiguration.noiseCancellationEnabled
            || recordingConfiguration.autoGainControlEnabled
        let mode: AVAudioSession.Mode = useVoiceProcessing ? .voiceChat : .default

        try session.setCategory(
            .playAndRecord,
            mode: mode,
            options: [
                .defaultToSpeaker,
                .allowBluetooth,
                .allowBluetoothA2DP,
                .mixWithOthers,
                .duckOthers  // 他の音声を小さくして録音を継続
            ]
        )
        // IO バッファは指定しない（以前は 5ms 固定）。ファイルへ書くだけなら低遅延は要らず、
        // 短いほど CPU の起床が増えて電池を使う（#225）
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    /// 次の区切りの録音を始め、それまでのレコーダーを止める。
    /// 新しい方を先に動かしてから古い方を止めるので、切り替えで音が欠けない（ごく短く重なる）。
    private func startNewSegment() throws -> Bool {
        guard let directory = segmentDirectory, let finalURL else { return false }
        let url = RecordingSegments.segmentURL(
            index: segmentURLs.count,
            in: directory,
            fileExtension: finalURL.pathExtension
        )
        let recorder = try AVAudioRecorder(url: url, settings: recordingConfiguration.recordingSettings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        guard recorder.record() else { return false }

        let previous = audioRecorder
        if let previous {
            finishedSegmentsDuration += previous.currentTime
        }
        audioRecorder = recorder
        lastObservedSegmentTime = 0
        segmentURLs.append(url)
        previous?.stop()
        logger.info("区切り \(self.segmentURLs.count) を開始: \(url.lastPathComponent)")
        return true
    }

    private func startRotationTask() {
        rotationTask?.cancel()
        rotationTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let interval = await self?.rotationCheckInterval else { return }
                try? await Task.sleep(for: interval)
                await self?.rotateSegmentIfNeeded()
            }
        }
    }

    private func rotateSegmentIfNeeded() {
        guard case .recording = state,
              let recorder = audioRecorder,
              recorder.isRecording,
              recorder.currentTime >= segmentDuration else { return }
        do {
            if try !startNewSegment() {
                // 次の区切りを始められなかったら、今の区切りに書き続ける（次の確認でまた試す）
                logger.error("次の区切りを開始できなかった")
            }
        } catch {
            logger.error("次の区切りの作成に失敗: \(error.localizedDescription)")
        }
    }

    /// 区切りを1ファイルにつなぐ。つなげなかったら区切りを残し、次の起動の復旧に任せる
    private func finalizeSegments() async {
        guard let finalURL, let directory = segmentDirectory else { return }
        // 予期しない停止で閉じられなかった WAV はヘッダを直し、読めない区切り（書きかけの m4a）は除く
        let readable = RecordingSegments.segmentFiles(in: directory)
            .filter(InterruptedRecordingRecovery.isReadableAfterRepair)
        guard !readable.isEmpty else {
            logger.error("つなげる区切りがない")
            return
        }
        do {
            try await RecordingSegments.merge(readable, into: finalURL)
            try? FileManager.default.removeItem(at: directory)
            logger.info("\(readable.count) 個の区切りを \(finalURL.lastPathComponent) につないだ")
        } catch {
            logger.error("区切りの結合に失敗（次の起動で再試行）: \(error.localizedDescription)")
        }
    }

    /// - Returns: 録音を再開できたら true
    private func resume() -> Bool {
        guard case .paused(let startTime, _, _) = state else {
            logger.warning("録音再開要求されたが、一時停止中ではない状態: \(String(describing: self.state))")
            return false
        }

        logger.info("録音再開開始")
        // 割り込みやメディアリセットの後はセッションが非アクティブ・設定なしになっているので、設定し直す
        do {
            try configureAudioSession()
        } catch {
            logger.error("録音再開時のオーディオセッション設定に失敗: \(error.localizedDescription)")
        }

        let resumed: Bool
        if let recorder = audioRecorder {
            resumed = recorder.record()
        } else {
            // レコーダーが使えなくなった後（メディアリセット・予期しない停止）は次の区切りから録り直す
            resumed = (try? startNewSegment()) ?? false
        }
        guard resumed else {
            // 他アプリがマイクを使用中などで再開できない。一時停止のまま残す
            logger.error("録音再開に失敗 - 一時停止のまま")
            return false
        }

        pausedByInterruption = false
        state = .recording(startTime: startTime)
        logger.info("録音再開完了")
        return true
    }

    /// 録音中にレコーダーが使えなくなったとき（メディアリセット・書き込みエラー・システムによる停止）。
    /// それまでの区切りは残し、一時停止にして知らせる。再開すると次の区切りから録る
    private func handleRecorderLost(reason: String) {
        let startTime: Date
        switch state {
        case .recording(let start): startTime = start
        case .paused(let start, _, _): startTime = start
        default: return
        }
        logger.error("レコーダーが使えなくなった: \(reason)")
        finishedSegmentsDuration += lastObservedSegmentTime
        lastObservedSegmentTime = 0
        audioRecorder = nil
        state = .paused(startTime: startTime, pausedTime: Date(), duration: finishedSegmentsDuration)
        RecordingAlertNotifier.notifyRecordingPaused()
    }

    private func beginBackgroundTask() {
        endBackgroundTask() // End any existing task first

        Task { @MainActor [self] in
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
        rotationTask?.cancel()
        rotationTask = nil
        endBackgroundTask()
        removeObservers()

        // オーディオセッションの非アクティブ化
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            logger.warning("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }

    // MARK: - Notifications

    private func registerObservers() {
        removeObservers()
        let center = NotificationCenter.default
        observerTokens = [
            center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
                let info = InterruptionInfo(notification)
                Task { await self?.handleInterruption(info) }
            },
            center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
                let reason = (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt)
                    .flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
                Task { await self?.handleRouteChange(reason) }
            },
            center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
                Task { await self?.handleMediaServicesReset() }
            }
        ]
    }

    private func removeObservers() {
        observerTokens.forEach(NotificationCenter.default.removeObserver)
        observerTokens = []
    }

    /// Notification は Sendable ではないので、actor に渡す前に必要な値だけ取り出す
    struct InterruptionInfo: Sendable {
        var type: AVAudioSession.InterruptionType?
        var shouldResume: Bool

        init(_ notification: Notification) {
            let info = notification.userInfo
            type = (info?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            let options = (info?[AVAudioSessionInterruptionOptionKey] as? UInt).map(AVAudioSession.InterruptionOptions.init(rawValue:))
            shouldResume = options?.contains(.shouldResume) ?? false
        }
    }

    private func handleInterruption(_ info: InterruptionInfo) async {
        switch info.type {
        case .began:
            logger.info("オーディオ割り込み開始 - 録音を一時停止")
            guard case .recording = state else { return }
            await pauseRecording()
            pausedByInterruption = true

        case .ended:
            logger.info("オーディオ割り込み終了 (shouldResume: \(info.shouldResume))")
            guard pausedByInterruption else { return }
            // 再生アプリと違い、録音アプリは shouldResume が無くても再開を試す。
            // 電話のあとなどに付かないことがあり、その場合に何時間も止まったままになるのを防ぐ（#226）
            if !resume() {
                RecordingAlertNotifier.notifyRecordingPaused()
            }

        case .none:
            logger.warning("割り込み通知の解析に失敗")
        @unknown default:
            logger.warning("不明な割り込みタイプ")
        }
    }

    /// イヤホンの抜き差し・Bluetooth の切り替えで録音が止まっていたら再開する
    private func handleRouteChange(_ reason: AVAudioSession.RouteChangeReason?) {
        guard case .recording = state, let recorder = audioRecorder else { return }
        logger.info("ルート変更: \(reason.map { String($0.rawValue) } ?? "unknown")")
        guard !recorder.isRecording else { return }
        if !recorder.record() {
            handleRecorderLost(reason: "route change")
        }
    }

    /// メディアサービスが再起動するとレコーダーは使えなくなる。
    /// Apple の指針どおり、録音の再開はユーザーの操作（再開ボタン）を待つ
    private func handleMediaServicesReset() {
        logger.error("メディアサービスがリセットされた")
        handleRecorderLost(reason: "media services were reset")
    }

    func recorderDidFinish(_ recorderID: ObjectIdentifier, successfully: Bool) {
        // 区切りの切り替えや停止で止めたレコーダーの通知は無視する
        guard let current = audioRecorder, ObjectIdentifier(current) == recorderID else { return }
        handleRecorderLost(reason: successfully ? "finished unexpectedly" : "finished unsuccessfully")
    }
}

// MARK: - AVAudioRecorderDelegate

extension LongRecordingAudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let id = ObjectIdentifier(recorder)
        Task { await recorderDidFinish(id, successfully: flag) }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        let id = ObjectIdentifier(recorder)
        Task { await recorderDidFinish(id, successfully: false) }
    }
}
