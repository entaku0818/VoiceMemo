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
        resultText: unimplemented("\(Self.self).resultText", placeholder: "")
    )
}

extension DependencyValues {
    var audioRecorder: AudioRecorderClient {
        get { self[AudioRecorderClient.self] }
        set { self[AudioRecorderClient.self] = newValue }
    }
}

extension AudioRecorderClient: DependencyKey  {
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
    var buffers: [AVAudioPCMBuffer] = []
    var waveFormHeights: [CGFloat] = []
    var isFinal = false
    var currentTime: TimeInterval = 0
    var isPaused: Bool = false

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
    }

    func start(url: URL) async throws -> Bool {
        self.stop()
        setupAVAudioSession()
        let stream = AsyncThrowingStream<Bool, Error> { continuation in
            do {
                speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
                audioEngine = AVAudioEngine()
                inputNode = audioEngine?.inputNode

                guard let inputNode = inputNode else { return }

                inputNode.volume = Float(UserDefaultsManager.shared.microphonesVolume)

                recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
                guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
                recognitionRequest.shouldReportPartialResults = true

                recognitionRequest.requiresOnDeviceRecognition = false

                self.recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
                    if let result = result {
                        self.isFinal = result.isFinal
                        self.resultText = result.bestTranscription.formattedString
                    }

                    if let error = error as? NSError {
                        continuation.yield(true)
                        continuation.finish()
                    }
                    if self.isFinal {
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
                    AVLinearPCMBitDepthKey: quantizationBitDepth,
                ]

                let audioFile = try AVAudioFile(forWriting: url, settings: settings)

                inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { (buffer: AVAudioPCMBuffer, _: AVAudioTime) in
                    guard !self.isPaused else { return }

                    self.currentTime = Double(audioFile.length) / sampleRate

                    self.recognitionRequest?.append(buffer)
                    self.buffers.append(buffer)
                    self.waveFormHeights.append(buffer.waveFormHeight)
                    self.updateAudioLevel(buffer: buffer)

                    do {
                        try audioFile.write(from: buffer)
                    } catch let error {
                        Logger.shared.logError("audioFile.writeFromBuffer error:" + error.localizedDescription)
                        continuation.finish(throwing: error)
                    }
                }

                audioEngine?.prepare()
                try audioEngine?.start()

            } catch {
                Logger.shared.logError(error.localizedDescription)
                continuation.finish(throwing: error)
            }
        }

        guard let action = try await stream.first(where: { @Sendable _ in true })
        else {
            throw CancellationError()
        }
        return action
    }

    func pause() {
        isPaused = true
        audioEngine?.pause()
    }

    func resume() {
        isPaused = false
        try? audioEngine?.start()
    }

    private func setupAVAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .default, options: [.duckOthers, .allowBluetooth, .allowBluetoothA2DP, .allowAirPlay])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("マイクの音量を設定できませんでした。エラー: \(error.localizedDescription)")
        }
    }

    func amplitude() -> Float {
        return audioLevel
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
        return resultText
    }
}
