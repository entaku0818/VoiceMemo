import Foundation
import AVFoundation
import Accelerate

// 音声処理サービスのプロトコル
protocol AudioProcessingServiceProtocol {
    func generateWaveformData(for url: URL) async throws -> [Float]
    func trimAudio(at url: URL, range: ClosedRange<Double>) async throws -> URL
    func splitAudio(at url: URL, atTime: Double) async throws -> [URL]
    func mergeAudio(urls: [URL]) async throws -> URL
    func adjustVolume(at url: URL, level: Float, range: ClosedRange<Double>?) async throws -> URL
}

// 音声処理サービスの実装
struct AudioProcessingService: AudioProcessingServiceProtocol {

    // 波形データの生成
    func generateWaveformData(for url: URL) async throws -> [Float] {
        try await withCheckedThrowingContinuation { continuation in
            do {
                // ファイルの存在確認
                let fileManager = FileManager.default
                guard fileManager.fileExists(atPath: url.path) else {
                    throw NSError(domain: "AudioProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "音声ファイルが見つかりません: \(url.path)"])
                }

                print("波形データ生成開始: \(url.path)")

                // AVAudioSessionを設定
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default)
                try audioSession.setActive(true)

                let audioFile = try AVAudioFile(forReading: url)
                let format = audioFile.processingFormat
                let frameCount = UInt32(audioFile.length)
                let sampleRate = format.sampleRate

                // 波形データのサンプル数を決定（波形表示に適したデータ量に調整）
                let desiredSampleCount = 200 // 表示用の波形データの数
                let samplesPerSegment = Int(frameCount) / desiredSampleCount

                guard samplesPerSegment > 0 else {
                    // 音声が短すぎる場合の対処
                    let empty: [Float] = Array(repeating: 0.01, count: desiredSampleCount)
                    continuation.resume(returning: empty)
                    return
                }

                // バッファを準備
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                    throw NSError(domain: "AudioProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "バッファの作成に失敗しました"])
                }

                // 音声ファイルを読み込む
                try audioFile.read(into: buffer)

                // 波形データの生成
                var waveformData = [Float](repeating: 0.0, count: desiredSampleCount)
                let channelData = buffer.floatChannelData?[0]

                for segment in 0..<desiredSampleCount {
                    let segmentStart = segment * samplesPerSegment
                    let segmentEnd = min(segmentStart + samplesPerSegment, Int(frameCount))

                    if segmentStart < segmentEnd {
                        var maxAmplitude: Float = 0.0
                        for sample in segmentStart..<segmentEnd {
                            let amplitude = abs(channelData?[sample] ?? 0.0)
                            maxAmplitude = max(maxAmplitude, amplitude)
                        }
                        waveformData[segment] = maxAmplitude
                    }
                }

                // 値の正規化
                let maxValue = waveformData.max() ?? 1.0
                if maxValue > 0 {
                    waveformData = waveformData.map { $0 / maxValue }
                }

                // 最小値の設定（見やすさのため）
                waveformData = waveformData.map { max($0, 0.01) }

                continuation.resume(returning: waveformData)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // 音声のトリミング
    func trimAudio(at url: URL, range: ClosedRange<Double>) async throws -> URL {
        // ファイルの存在確認
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            throw NSError(domain: "AudioProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "音声ファイルが見つかりません: \(url.path)"])
        }

        let asset = AVAsset(url: url)
        let composition = AVMutableComposition()

        // 新しい音声トラックを作成
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            throw NSError(domain: "AudioProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "トラックの作成に失敗しました"])
        }

        // 元の音声ファイルからオーディオトラックを取得
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw NSError(domain: "AudioProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "オーディオトラックが見つかりません"])
        }

        // 時間範囲を設定
        let startTime = CMTime(seconds: range.lowerBound, preferredTimescale: 1000)
        let endTime = CMTime(seconds: range.upperBound, preferredTimescale: 1000)
        let timeRange = CMTimeRange(start: startTime, end: endTime)

        // 音声トラックを追加
        try compositionTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)

        // 一時ファイルのURLを生成
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let outputURL = tempDirectoryURL.appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension)

        // ファイルが既に存在する場合は削除
        try? FileManager.default.removeItem(at: outputURL)

        // コンポジションをエクスポート
        return try await withCheckedThrowingContinuation { continuation in
            guard let exportSession = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPresetAppleM4A
            ) else {
                continuation.resume(throwing: NSError(domain: "AudioProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "エクスポートセッションの作成に失敗しました"]))
                return
            }

            exportSession.outputURL = outputURL
            exportSession.outputFileType = .m4a

            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume(returning: outputURL)
                case .failed:
                    if let error = exportSession.error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: NSError(domain: "AudioProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "エクスポートに失敗しました"]))
                    }
                case .cancelled:
                    continuation.resume(throwing: NSError(domain: "AudioProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "エクスポートがキャンセルされました"]))
                default:
                    continuation.resume(throwing: NSError(domain: "AudioProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "不明なエラーが発生しました"]))
                }
            }
        }
    }

    // 音声の分割
    func splitAudio(at url: URL, atTime: Double) async throws -> [URL] {
        // 前半部分のトリミング
        let firstRange = 0.0...atTime
        let firstPart = try await trimAudio(at: url, range: firstRange)

        // 後半部分のトリミング
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        let secondRange = atTime...duration
        let secondPart = try await trimAudio(at: url, range: secondRange)

        return [firstPart, secondPart]
    }

    // 音声の結合
    func mergeAudio(urls: [URL]) async throws -> URL {
        guard !urls.isEmpty else {
            throw NSError(domain: "AudioProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "結合する音声ファイルがありません"])
        }

        if urls.count == 1 {
            // 1つしかない場合はそのまま返す
            return urls[0]
        }

        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            throw NSError(domain: "AudioProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "トラックの作成に失敗しました"])
        }

        var insertTime = CMTime.zero

        // 全ての音声ファイルを順番に結合
        for url in urls {
            let asset = AVAsset(url: url)
            guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
                continue // このファイルは飛ばす
            }

            let duration = try await asset.load(.duration)
            let timeRange = CMTimeRange(start: .zero, duration: duration)

            try compositionTrack.insertTimeRange(timeRange, of: audioTrack, at: insertTime)
            insertTime = CMTimeAdd(insertTime, duration)
        }

        // 出力ファイルのURLを生成
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let outputURL = tempDirectoryURL.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")

        // ファイルが既に存在する場合は削除
        try? FileManager.default.removeItem(at: outputURL)

        // コンポジションをエクスポート
        return try await withCheckedThrowingContinuation { continuation in
            guard let exportSession = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPresetAppleM4A
            ) else {
                continuation.resume(throwing: NSError(domain: "AudioProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "エクスポートセッションの作成に失敗しました"]))
                return
            }

            exportSession.outputURL = outputURL
            exportSession.outputFileType = .m4a

            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume(returning: outputURL)
                case .failed:
                    if let error = exportSession.error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: NSError(domain: "AudioProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "エクスポートに失敗しました"]))
                    }
                case .cancelled:
                    continuation.resume(throwing: NSError(domain: "AudioProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "エクスポートがキャンセルされました"]))
                default:
                    continuation.resume(throwing: NSError(domain: "AudioProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "不明なエラーが発生しました"]))
                }
            }
        }
    }

    // 音量調整
    func adjustVolume(at url: URL, level: Float, range: ClosedRange<Double>?) async throws -> URL {
        let asset = AVAsset(url: url)
        let composition = AVMutableComposition()

        // 新しい音声トラックを作成
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            throw NSError(domain: "AudioProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "トラックの作成に失敗しました"])
        }

        // 元の音声ファイルからオーディオトラックを取得
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw NSError(domain: "AudioProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "オーディオトラックが見つかりません"])
        }

        let duration = try await asset.load(.duration)

        // 音声トラックを追加
        try compositionTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: audioTrack, at: .zero)

        // オーディオミックスを作成
        let audioMix = AVMutableAudioMix()
        var audioMixParameters = [AVMutableAudioMixInputParameters]()

        let parameters = AVMutableAudioMixInputParameters(track: audioTrack)

        if let range = range {
            // 特定の範囲のみ音量を調整
            let startTime = CMTime(seconds: range.lowerBound, preferredTimescale: 1000)
            let endTime = CMTime(seconds: range.upperBound, preferredTimescale: 1000)

            // 初期音量を設定（範囲外は元の音量）
            parameters.setVolume(1.0, at: .zero)

            // 範囲開始点で指定音量に変更
            parameters.setVolumeRamp(fromStartVolume: 1.0, toEndVolume: level, timeRange: CMTimeRange(start: startTime, end: startTime + CMTime(seconds: 0.01, preferredTimescale: 1000)))

            // 範囲終了点で元の音量に戻す
            parameters.setVolumeRamp(fromStartVolume: level, toEndVolume: 1.0, timeRange: CMTimeRange(start: endTime - CMTime(seconds: 0.01, preferredTimescale: 1000), end: endTime))
        } else {
            // 全体の音量を調整
            parameters.setVolume(level, at: .zero)
        }

        audioMixParameters.append(parameters)
        audioMix.inputParameters = audioMixParameters

        // 一時ファイルのURLを生成
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let outputURL = tempDirectoryURL.appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension)

        // ファイルが既に存在する場合は削除
        try? FileManager.default.removeItem(at: outputURL)

        // コンポジションをエクスポート
        return try await withCheckedThrowingContinuation { continuation in
            guard let exportSession = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPresetAppleM4A
            ) else {
                continuation.resume(throwing: NSError(domain: "AudioProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "エクスポートセッションの作成に失敗しました"]))
                return
            }

            exportSession.outputURL = outputURL
            exportSession.outputFileType = .m4a
            exportSession.audioMix = audioMix

            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume(returning: outputURL)
                case .failed:
                    if let error = exportSession.error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: NSError(domain: "AudioProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "エクスポートに失敗しました"]))
                    }
                case .cancelled:
                    continuation.resume(throwing: NSError(domain: "AudioProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "エクスポートがキャンセルされました"]))
                default:
                    continuation.resume(throwing: NSError(domain: "AudioProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "不明なエラーが発生しました"]))
                }
            }
        }
    }
}
