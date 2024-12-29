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

    var audioLevel: Float = 0.0 // 音の大きさを表すプロパティ

    static func requestPermission() async -> Bool {
        await withUnsafeContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func stop() {
        if currentTime < 2 { return }
        audioEngine?.stop()
        self.inputNode?.removeTap(onBus: 0)
        self.recognitionTask?.cancel()
        isFinal = true
        resultText = ""
        try? AVAudioSession.sharedInstance().setActive(false)
        endBackgroundTask() // バックグラウンドタスクを終了
    }

    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    func start(url: URL) async -> Bool {
        self.stop()
        setupAVAudioSession()
        beginBackgroundTask() // バックグラウンドタスクを開始
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

                NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())

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

                inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { (buffer: AVAudioPCMBuffer, _: AVAudioTime) in
                    guard !self.isPaused else { return }

                    self.currentTime = Double(audioFile.length) / sampleRate

                    self.recognitionRequest?.append(buffer)
                    self.updateAudioLevel(buffer: buffer)

                    do {
                        try audioFile.write(from: buffer)
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

    @objc func handleInterruption(notification: Notification) async {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch interruptionType {
        case .began:
            audioEngine?.pause()
            UserDefaultsManager.shared.logError("Audio session interrupted. Audio engine paused.")
        case .ended:
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                try audioEngine?.start()
                UserDefaultsManager.shared.logError("Audio session interruption ended. Audio engine restarted.")
            } catch {
                UserDefaultsManager.shared.logError("Failed to reactivate audio session: \(error.localizedDescription)")
            }
        default:
            break
        }
    }

    func pause() {
        isPaused = true
        audioEngine?.pause()
    }

    func resume() {
        isPaused = false
        try? audioEngine?.start()
    }

    func setupAVAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .mixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            UserDefaultsManager.shared.logError("Failed to set up AVAudioSession: \(error.localizedDescription)")
        }
    }

    @objc func audioEngineConfigurationChange(notification: Notification) async {
        UserDefaultsManager.shared.logError("AudioEngine configuration change detected")
    }

    func getWaveFormHeights() -> [Float] {
        []
    }

    func amplitude() -> Float {
        audioLevel
    }

    private func updateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0,
                                           to: Int(buffer.frameLength),
                                           by: buffer.stride).map { channelDataValue[$0] }
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let avgPower = 20 * log10(rms)
        DispatchQueue.main.async {
            self.audioLevel = avgPower
        }
    }

    func fetchResultText() -> String {
        resultText
    }
}
