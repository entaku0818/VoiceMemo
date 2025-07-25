import AVFoundation
import ComposableArchitecture
import Foundation
import Speech
import FirebaseCrashlytics
import UIKit

struct AudioRecorderClient {
    var currentTime: @Sendable () async -> TimeInterval?
    var requestRecordPermission: @Sendable () async -> Bool
    var startRecording: @Sendable (URL) async throws -> Bool
    var stopRecording: @Sendable () async -> Void
    var pauseRecording: @Sendable () async -> Void
    var resumeRecording: @Sendable () async -> Void
    var volumes: @Sendable () async -> Float
    var waveFormHeights: @Sendable () async -> [Float]
    var resultText: @Sendable () async -> String
}

extension AudioRecorderClient: TestDependencyKey {
    static var previewValue: Self {
        let isRecording = ActorIsolated(false)
        let isPaused = ActorIsolated(false)
        let currentTime = ActorIsolated(0.0)

        return Self(
            currentTime: { await currentTime.value },
            requestRecordPermission: { true },
            startRecording: { _ in
                await isRecording.setValue(true)

                while true {
                    let recording = await isRecording.value
                    let paused = await isPaused.value

                    if !recording || !paused {
                        break
                    }

                    try await Task.sleep(nanoseconds: NSEC_PER_SEC)
                    await currentTime.withValue { $0 += 1 }
                }

                return true
            },
            stopRecording: {
                await isRecording.setValue(false)
                await currentTime.setValue(0)
            },
            pauseRecording: {
                await isPaused.setValue(true)
            },
            resumeRecording: {
                await isPaused.setValue(false)
            },
            volumes: { 0.0 }, // Add some stub values here if needed
            waveFormHeights: { [] },
            resultText: { "" }
        )
    }

    static let testValue = Self(
        currentTime: unimplemented("\(Self.self).currentTime", placeholder: nil),
        requestRecordPermission: unimplemented(
            "\(Self.self).requestRecordPermission", placeholder: false
        ),
        startRecording: unimplemented("\(Self.self).startRecording", placeholder: false),
        stopRecording: unimplemented("\(Self.self).stopRecording"),
        pauseRecording: unimplemented("\(Self.self).pauseRecording"),
        resumeRecording: unimplemented("\(Self.self).resumeRecording"),
        volumes: unimplemented("\(Self.self).volumes", placeholder: 0.0),
        waveFormHeights: unimplemented("\(Self.self).waveFormHeights", placeholder: []),
        resultText: unimplemented("\(Self.self).resultText", placeholder: "")
    )
}

extension DependencyValues {
    var audioRecorder: AudioRecorderClient {
        get { self[AudioRecorderClient.self] }
        set { self[AudioRecorderClient.self] = newValue }
    }
}

extension AudioRecorderClient: DependencyKey {
    static var liveValue: Self {
        let audioRecorder = AudioRecorder()
        return Self(
            currentTime: { await audioRecorder.currentTime },
            requestRecordPermission: { await AudioRecorder.requestPermission() },
            startRecording: { url in try await audioRecorder.start(url: url) },
            stopRecording: { await audioRecorder.stop() },
            pauseRecording: { await audioRecorder.pause() },
            resumeRecording: { await audioRecorder.resume() },
            volumes: { await audioRecorder.amplitude() },
            waveFormHeights: { await audioRecorder.getWaveFormHeights() },
            resultText: { await audioRecorder.fetchResultText() }
        )
    }
}
private actor AudioRecorder {
    var speechRecognizer: SFSpeechRecognizer?
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    var audioEngine: AVAudioEngine?
    var inputNode: AVAudioInputNode?
    var resultText: String = ""
    var isFinal = false
    var currentTime: TimeInterval = 0
    var isPaused = false
    var isRecording = false // 録音状態を追跡

    var audioLevel: Float = -60.0 // 音の大きさを表すプロパティ（デシベル単位、初期値は最小）

    static func requestPermission() async -> Bool {
        await withUnsafeContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func stop() {
        if currentTime < 2 { return }

        // 録音状態をfalseに設定
        isRecording = false

        // 割り込み処理を削除
        self.removeInterruptionHandling()

        audioEngine?.stop()
        self.inputNode?.removeTap(onBus: 0)
        self.recognitionTask?.cancel()
        isFinal = true
        resultText = ""
        try? AVAudioSession.sharedInstance().setActive(false)
        endBackgroundTask() // バックグラウンドタスクを終了
    }

    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    func setupAVAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // より強力な録音継続設定
            try audioSession.setCategory(.playAndRecord, options: [
                .defaultToSpeaker,
                .allowBluetooth,
                .allowBluetoothA2DP,
                .mixWithOthers,
                .duckOthers  // 他の音声を小さくして録音を継続
            ])
            try audioSession.setPreferredSampleRate(UserDefaultsManager.shared.samplingFrequency)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            UserDefaultsManager.shared.logError("Failed to set up AVAudioSession: \(error.localizedDescription)")
        }
    }

    func start(url: URL) async -> Bool {
        self.stop()
        setupAVAudioSession()
        beginBackgroundTask()

        // 録音状態をtrueに設定
        isRecording = true

        let stream = AsyncThrowingStream<Bool, Error> { continuation in
            do {
                speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
                audioEngine = AVAudioEngine()
                inputNode = audioEngine?.inputNode

                guard let inputNode = inputNode else {
                    UserDefaultsManager.shared.logError("Input node not available")
                    continuation.finish(throwing: NSError(domain: "InputNodeError", code: -1, userInfo: nil))
                    return
                }

                // 割り込み処理を安全に登録
                self.setupInterruptionHandling()

                inputNode.volume = Float(UserDefaultsManager.shared.microphonesVolume)

                recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
                guard let recognitionRequest = recognitionRequest else {
                    UserDefaultsManager.shared.logError("Unable to create a SFSpeechAudioBufferRecognitionRequest object")
                    fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object")
                }
                recognitionRequest.shouldReportPartialResults = true
                recognitionRequest.requiresOnDeviceRecognition = false

                self.recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, _ in
                    if let result = result {
                        self.isFinal = result.isFinal
                        self.resultText = result.bestTranscription.formattedString
                    }

                    if self.isFinal {
                        UserDefaultsManager.shared.logError("isFinal")
                        self.recognitionTask = nil
                        continuation.yield(true)
                        continuation.finish()
                    }
                }

                let fileFormat: AudioFormatID = Constants.FileFormat(rawValue: UserDefaultsManager.shared.selectedFileFormat)?.audioId ?? kAudioFormatMPEG4AAC
                let quantizationBitDepth: Int = UserDefaultsManager.shared.quantizationBitDepth
                let sampleRate: Double = UserDefaultsManager.shared.samplingFrequency
                let numberOfChannels: Int = 1

                let settings = [
                    AVFormatIDKey: fileFormat,
                    AVNumberOfChannelsKey: numberOfChannels,
                    AVSampleRateKey: sampleRate,
                    AVLinearPCMBitDepthKey: quantizationBitDepth
                ]

                let audioFile = try AVAudioFile(forWriting: url, settings: settings)

                // 入力フォーマットを取得
                let inputFormat = inputNode.inputFormat(forBus: 0)

                // 出力フォーマットを設定
                let outputFormat = AVAudioFormat(
                    commonFormat: .pcmFormatFloat32,
                    sampleRate: sampleRate,
                    channels: 1,
                    interleaved: false
                )!

                // コンバーターを作成
                let converter = AVAudioConverter(from: inputFormat, to: outputFormat)!

                inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { (buffer: AVAudioPCMBuffer, _: AVAudioTime) in
                    guard !self.isPaused else { return }

                    let currentFrame = audioFile.length
                    self.currentTime = Double(currentFrame) / sampleRate

                    // バッファを変換
                    let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: AVAudioFrameCount(Double(buffer.frameLength) * outputFormat.sampleRate / inputFormat.sampleRate))!
                    var error: NSError?
                    let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                        outStatus.pointee = .haveData
                        return buffer
                    }

                    converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

                    if let error = error {
                        UserDefaultsManager.shared.logError("Conversion error: \(error.localizedDescription)")
                        return
                    }

                    self.recognitionRequest?.append(convertedBuffer)
                    self.updateAudioLevel(buffer: convertedBuffer)

                    do {
                        try audioFile.write(from: convertedBuffer)
                    } catch {
                        UserDefaultsManager.shared.logError(error.localizedDescription)
                        RollbarLogger.shared.logError("audioFile.writeFromBuffer error:" + error.localizedDescription)
                        continuation.finish(throwing: error)
                    }
                }

                audioEngine?.prepare()
                try audioEngine?.start()

            } catch {
                UserDefaultsManager.shared.logError(error.localizedDescription)
                RollbarLogger.shared.logError(error.localizedDescription)
                continuation.finish(throwing: error)
            }
        }

        do {
            guard let action = try await stream.first(where: { @Sendable _ in true }) else {
                UserDefaultsManager.shared.logError("CancellationError")
                return false
            }
            return action
        } catch {
            UserDefaultsManager.shared.logError("Stream error: \(error.localizedDescription)")
            return false
        }
    }

    private func beginBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            guard let self = self else { return }
            UIApplication.shared.endBackgroundTask(self.backgroundTask)
            self.backgroundTask = .invalid
        }
    }

    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    func pause() {
        isPaused = true
        audioEngine?.pause()
    }

    func resume() {
        guard isRecording else { return }
        isPaused = false
        try? audioEngine?.start()
    }

    func audioEngineConfigurationChange(notification: Notification) async {
        UserDefaultsManager.shared.logError("AudioEngine configuration change detected")
    }

    func getWaveFormHeights() -> [Float] {
        []
    }

    func amplitude() -> Float {
        audioLevel
    }

    private func updateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { 
            UserDefaultsManager.shared.logError("AudioLevel: channelData is nil")
            return 
        }
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0,
                                           to: Int(buffer.frameLength),
                                           by: buffer.stride).map { channelDataValue[$0] }
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))

        // デバッグログ出力
        let maxValue = channelDataValueArray.max() ?? 0
        let minValue = channelDataValueArray.min() ?? 0
        
        // RMSが非常に小さい場合は最小値を設定
        let avgPower: Float
        if rms < 0.00001 {
            avgPower = -60.0
        } else {
            let calculatedPower = 20 * log10(rms)
            // -60dBから0dBの範囲にクリップ
            avgPower = max(-60.0, min(0.0, calculatedPower))
        }
        
        // デバッグ情報を詳細にログ出力
        UserDefaultsManager.shared.logError(String(format: "AudioLevel Debug - RMS: %.6f, Power: %.2f dB, Max: %.6f, Min: %.6f, Samples: %d", 
                                                  rms, avgPower, maxValue, minValue, buffer.frameLength))

        // actorのコンテキストで更新
        self.audioLevel = avgPower
    }

    func fetchResultText() -> String {
        resultText
    }

    // 安全な割り込み処理の設定
    private func setupInterruptionHandling() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }

        // ルート変更の監視も追加（Bluetoothヘッドセットの接続/切断など）
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
    }

    // 割り込み処理の削除
    private func removeInterruptionHandling() {
        NotificationCenter.default.removeObserver(
            self,
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    // 同期的な割り込み処理（クラッシュを防ぐ）
    private func handleInterruption(_ notification: Notification) {
        guard isRecording else { return }

        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            UserDefaultsManager.shared.logError("Audio interruption began - trying to maintain recording")
            // 録音を継続するために何もしない（duckOthersオプションで他の音を小さくする）

        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)

            if options.contains(.shouldResume) {
                UserDefaultsManager.shared.logError("Audio interruption ended - resuming recording")
                // AudioSessionを再アクティブ化
                do {
                    try AVAudioSession.sharedInstance().setActive(true)
                } catch {
                    UserDefaultsManager.shared.logError("Failed to reactivate audio session: \(error)")
                }
            }

        @unknown default:
            break
        }
    }

    // ルート変更の処理
    private func handleRouteChange(_ notification: Notification) {
        guard isRecording else { return }

        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .newDeviceAvailable:
            UserDefaultsManager.shared.logError("New audio device available")
        case .oldDeviceUnavailable:
            UserDefaultsManager.shared.logError("Audio device disconnected")
        default:
            break
        }
    }
}
