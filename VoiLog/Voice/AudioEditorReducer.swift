import Foundation
import ComposableArchitecture
import AVFoundation
import Combine

// 編集操作を表す列挙型
enum EditOperation: Equatable {
    case trim(startTime: Double, endTime: Double)
    case split(atTime: Double)
    case merge(withMemoID: UUID)
    case adjustVolume(level: Float, range: ClosedRange<Double>?)

    var description: String {
        switch self {
        case let .trim(startTime, endTime):
            return "トリム: \(String(format: "%.1f", startTime))秒 - \(String(format: "%.1f", endTime))秒"
        case let .split(atTime):
            return "分割: \(String(format: "%.1f", atTime))秒"
        case .merge:
            return "結合"
        case let .adjustVolume(level, range):
            if let range = range {
                return "音量調整: \(String(format: "%.1f", level))倍 (\(String(format: "%.1f", range.lowerBound))秒 - \(String(format: "%.1f", range.upperBound))秒)"
            } else {
                return "音量調整: \(String(format: "%.1f", level))倍 (全体)"
            }
        }
    }
}

struct AudioEditorReducer: Reducer {
    struct State: Equatable {
        var memoID: UUID
        var audioURL: URL
        var originalTitle: String
        var duration: TimeInterval
        var waveformData: [Float] = []
        var isLoadingWaveform = false
        var selectedRange: ClosedRange<Double>?
        var currentPlaybackTime: Double = 0
        var isPlaying = false
        var editHistory: [EditOperation] = []
        var isEdited = false
        var processingOperation: EditOperation?
        var errorMessage: String?
        var shouldDismiss = false
    }

    enum Action {
        case loadAudio
        case audioLoaded(Result<[Float], Error>)
        case selectRange(ClosedRange<Double>?)
        case trim
        case trimCompleted(Result<URL, Error>)
        case split
        case splitCompleted(Result<[URL], Error>)
        case adjustVolume(Float)
        case adjustVolumeCompleted(Result<URL, Error>)
        case playPause
        case seek(to: Double)
        case updatePlaybackTime(Double)
        case save
        case saveCompleted(Result<UUID, Error>)
        case cancel
        case dismissEditor
        case errorOccurred(String)
        case successNotification(String)
    }

    @Dependency(\.audioProcessingService) var audioProcessingService
    @Dependency(\.audioPlayer) var audioPlayer
    @Dependency(\.continuousClock) var clock

    private enum CancelID { case playback, waveformLoading }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .loadAudio:
            state.isLoadingWaveform = true
            return .run { [url = state.audioURL] send in
                do {
                    let waveformData = try await audioProcessingService.generateWaveformData(for: url)
                    await send(.audioLoaded(.success(waveformData)))
                } catch {
                    await send(.audioLoaded(.failure(error)))
                }
            }
            .cancellable(id: CancelID.waveformLoading)

        case let .audioLoaded(result):
            state.isLoadingWaveform = false
            switch result {
            case let .success(waveformData):
                state.waveformData = waveformData
            case let .failure(error):
                state.errorMessage = "波形データの読み込みに失敗しました: \(error.localizedDescription)"
            }
            return .none

        case let .selectRange(range):
            state.selectedRange = range
            return .none

        case .trim:
            guard let selectedRange = state.selectedRange else {
                state.errorMessage = "トリミングする範囲を選択してください。"
                return .none
            }

            state.processingOperation = .trim(startTime: selectedRange.lowerBound, endTime: selectedRange.upperBound)

            return .run { [url = state.audioURL, range = selectedRange] send in
                do {
                    let newURL = try await audioProcessingService.trimAudio(at: url, range: range)
                    await send(.trimCompleted(.success(newURL)))
                } catch {
                    await send(.trimCompleted(.failure(error)))
                }
            }

        case let .trimCompleted(result):
            state.processingOperation = nil

            switch result {
            case let .success(newURL):
                if let trim = state.processingOperation, case let .trim(startTime, endTime) = trim {
                    state.editHistory.append(.trim(startTime: startTime, endTime: endTime))
                    state.duration = endTime - startTime
                } else if let selectedRange = state.selectedRange {
                    // processingOperationがnilの場合は選択範囲から計算
                    state.duration = selectedRange.upperBound - selectedRange.lowerBound
                }
                state.audioURL = newURL
                state.isEdited = true

                // 波形データを再読み込み
                return self.reduce(into: &state, action: .loadAudio)

            case let .failure(error):
                state.errorMessage = "トリミングに失敗しました: \(error.localizedDescription)"
            }
            return .none

        case .split:
            guard let selectedRange = state.selectedRange,
                  selectedRange.lowerBound == selectedRange.upperBound else {
                state.errorMessage = "分割するポイントを選択してください。"
                return .none
            }

            let splitPoint = selectedRange.lowerBound
            state.processingOperation = .split(atTime: splitPoint)

            return .run { [url = state.audioURL, splitPoint] send in
                do {
                    let newURLs = try await audioProcessingService.splitAudio(at: url, atTime: splitPoint)
                    await send(.splitCompleted(.success(newURLs)))
                } catch {
                    await send(.splitCompleted(.failure(error)))
                }
            }

        case let .splitCompleted(result):
            state.processingOperation = nil

            switch result {
            case let .success(newURLs):
                if newURLs.count >= 1 {
                    if let split = state.processingOperation, case let .split(atTime) = split {
                        state.editHistory.append(.split(atTime: atTime))
                    }
                    state.audioURL = newURLs[0] // 最初の部分を現在の編集対象とする
                    state.isEdited = true

                    // 成功メッセージ
                    print("音声分割が完了しました。前半を保存: \(newURLs[0].lastPathComponent)")

                    // 成功メッセージを表示
                    state.errorMessage = "分割が完了しました。\n分割ポイントまでの「\(state.originalTitle) (前半)」\nとして保存されました。"

                    // 波形データを再読み込み
                    return self.reduce(into: &state, action: .loadAudio)
                } else {
                    state.errorMessage = "分割に失敗しました: 新しいファイルが作成されませんでした。"
                }

            case let .failure(error):
                state.errorMessage = "分割に失敗しました: \(error.localizedDescription)"
            }
            return .none

        case let .adjustVolume(level):
            guard level != 1.0 else { return .none } // 音量変更なし

            let range = state.selectedRange
            state.processingOperation = .adjustVolume(level: level, range: range)

            return .run { [url = state.audioURL, level, range] send in
                do {
                    let newURL = try await audioProcessingService.adjustVolume(at: url, level: level, range: range)
                    await send(.adjustVolumeCompleted(.success(newURL)))
                } catch {
                    await send(.adjustVolumeCompleted(.failure(error)))
                }
            }

        case let .adjustVolumeCompleted(result):
            state.processingOperation = nil

            switch result {
            case let .success(newURL):
                if let adjustVolume = state.processingOperation, case let .adjustVolume(level, range) = adjustVolume {
                    state.editHistory.append(.adjustVolume(level: level, range: range))
                }
                state.audioURL = newURL
                state.isEdited = true

                // 波形データを再読み込み
                return self.reduce(into: &state, action: .loadAudio)

            case let .failure(error):
                state.errorMessage = "音量調整に失敗しました: \(error.localizedDescription)"
            }
            return .none

        case .playPause:
            state.isPlaying.toggle()

            if state.isPlaying {
                return .run { [url = state.audioURL, time = state.currentPlaybackTime] send in
                    let playTask = Task {
                        do {
                            try await audioPlayer.play(url, time, .normal, false)
                            await send(.playPause) // 再生終了時に停止状態に
                        } catch {
                            // エラーメッセージをアクションを通して更新
                            await send(.errorOccurred("再生に失敗しました: \(error.localizedDescription)"))
                            await send(.playPause)
                        }
                    }

                    // 再生位置を更新するタイマータスク
                    for await _ in clock.timer(interval: .milliseconds(100)) {
                        if Task.isCancelled { break }
                        let currentTime = try? await audioPlayer.getCurrentTime()
                        if let currentTime = currentTime {
                            await send(.updatePlaybackTime(currentTime))
                        }
                    }

                    await playTask.value
                }
                .cancellable(id: CancelID.playback)
            } else {
                return .run { _ in
                    try? await audioPlayer.stop()
                }
                .cancellable(id: CancelID.playback, cancelInFlight: true)
            }

        case let .seek(position):
            state.currentPlaybackTime = position

            if state.isPlaying {
                // 再生中なら、新しい位置から再生を再開
                return .run { [url = state.audioURL, position] _ in
                    try? await audioPlayer.stop()
                    try? await audioPlayer.play(url, position, .normal, false)
                }
                .cancellable(id: CancelID.playback, cancelInFlight: true)
            }
            return .none

        case let .updatePlaybackTime(time):
            state.currentPlaybackTime = time
            return .none

        case .save:
            // 現在の日時を含むタイトルを生成
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let timestamp = dateFormatter.string(from: Date())
            let newTitle = "分割音声 \(timestamp)"

            return .run { [url = state.audioURL, memoID = state.memoID, newTitle] send in
                do {
                    // 新しい音声メモとして保存
                    let (repository, originalMemo) = MainActor.assumeIsolated {
                        let repo = VoiceMemoRepository(
                            coreDataAccessor: VoiceMemoCoredataAccessor(),
                            cloudUploader: CloudUploader()
                        )
                        // 元の音声メモから必要なメタデータを取得
                        let memo = repo.fetch(uuid: memoID)
                        return (repo, memo)
                    }

                    if let originalMemo {
                        let fileURL = url
                        let audioAsset = AVAsset(url: fileURL)
                        let durationInSeconds = try await audioAsset.load(.duration).seconds

                        // 新しいUUIDを生成
                        let newUUID = UUID()

                        // 新しい保存先のパスを生成
                        let documentsPath = NSHomeDirectory() + "/Documents"
                        let filename = "\(newUUID.uuidString).\(url.pathExtension)"
                        let destinationPath = "\(documentsPath)/\(filename)"
                        let destinationURL = URL(fileURLWithPath: destinationPath)

                        // ファイルをコピーする前にファイルの存在を確認
                        if FileManager.default.fileExists(atPath: url.path) {
                            print("コピー元ファイルが存在します: \(url.path)")

                            // 保存先ディレクトリが存在することを確認
                            try FileManager.default.createDirectory(atPath: documentsPath, withIntermediateDirectories: true, attributes: nil)

                            // ファイルをコピー
                            try FileManager.default.copyItem(at: url, to: destinationURL)
                            print("ファイルをコピーしました: \(destinationURL.path)")
                        } else {
                            print("コピー元ファイルが存在しません: \(url.path)")
                            throw NSError(domain: "AudioEditor", code: 2, userInfo: [NSLocalizedDescriptionKey: "編集したオーディオファイルが見つかりません"])
                        }

                        // 新しい音声メモをデータベースに保存
                        let newVoice = VoiceMemoRepository.Voice(
                            title: newTitle,
                            url: destinationURL,
                            id: newUUID,
                            text: originalMemo.resultText,
                            createdAt: Date(),
                            updatedAt: Date(),
                            duration: durationInSeconds,
                            fileFormat: originalMemo.fileFormat,
                            samplingFrequency: originalMemo.samplingFrequency,
                            quantizationBitDepth: Int16(originalMemo.quantizationBitDepth),
                            numberOfChannels: Int16(originalMemo.numberOfChannels),
                            isCloud: false
                        )

                        // VoiceMemoRepositoryのVoiceオブジェクトをRecordingMemo.Stateに変換
                        let newMemoState = RecordingMemo.State(
                            uuid: newVoice.id,
                            date: newVoice.createdAt,
                            duration: newVoice.duration,
                            volumes: 0.0,
                            resultText: newVoice.text,
                            mode: .encoding,
                            fileFormat: newVoice.fileFormat,
                            samplingFrequency: newVoice.samplingFrequency,
                            quantizationBitDepth: Int(newVoice.quantizationBitDepth),
                            numberOfChannels: Int(newVoice.numberOfChannels),
                            url: newVoice.url,
                            startTime: 0,
                            time: 0
                        )

                        // レポジトリのインサートメソッドを使用
                        MainActor.assumeIsolated {
                            repository.insert(state: newMemoState)
                        }
                        await send(.saveCompleted(.success(newUUID)))
                    } else {
                        throw NSError(domain: "AudioEditor", code: 1, userInfo: [NSLocalizedDescriptionKey: "元の音声メモが見つかりませんでした"])
                    }
                } catch {
                    await send(.saveCompleted(.failure(error)))
                }
            }

        case let .saveCompleted(result):
            switch result {
            case .success:
                // 保存成功したら編集画面を閉じる
                state.shouldDismiss = true
                return .send(.dismissEditor)
            case let .failure(error):
                state.errorMessage = "保存に失敗しました: \(error.localizedDescription)"
            }
            return .none

        case .cancel:
            // 編集をキャンセルして元に戻す
            if state.isPlaying {
                state.isPlaying = false
                return .merge(
                    .run { _ in
                        do {
                            try await audioPlayer.stop()
                        } catch {
                            // エラー処理（必要に応じて）
                        }
                    }
                    .cancellable(id: CancelID.playback, cancelInFlight: true),
                    .send(.dismissEditor)
                )
            }
            if state.isEdited {
                // 編集途中の一時ファイルを削除するロジックを追加
            }
            state.shouldDismiss = true
            return .send(.dismissEditor)

        case .dismissEditor:
            // 編集画面を閉じる
            return .none

        case let .errorOccurred(message):
            state.errorMessage = message
            return .none

        case let .successNotification(message):
            state.errorMessage = message
            return .none
        }
    }
}

// AudioProcessingServiceの依存性を定義
struct AudioProcessingServiceKey: DependencyKey {
    static var liveValue: AudioProcessingServiceProtocol = AudioProcessingService()
}

extension DependencyValues {
    var audioProcessingService: AudioProcessingServiceProtocol {
        get { self[AudioProcessingServiceKey.self] }
        set { self[AudioProcessingServiceKey.self] = newValue }
    }
}
