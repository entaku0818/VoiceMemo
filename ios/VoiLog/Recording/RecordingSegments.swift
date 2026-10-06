import Foundation
import AVFoundation
import os.log
import Dependencies

/// 長時間録音を一定時間ごとに別ファイルへ分けて書くための置き場所と、停止時の結合（#224）。
///
/// 1本のファイルに書き続けると、アプリが強制終了したときに失う範囲が録音全体になる
/// （m4a は moov アトムが閉じるときに書かれるので丸ごと読めなくなる）。
/// 区切っておけば、失うのは書きかけの最後の区切りだけで済む。
///
/// 停止したら区切りを1ファイル（従来どおり `Documents/<UUID>.<ext>`）につなぐので、
/// 再生・共有・文字起こし・Core Data の持ち方は変わらない。
enum RecordingSegments {
    /// 1つの区切りの長さ。強制終了で失いうる最大の長さでもある
    static let segmentDuration: TimeInterval = 30 * 60

    /// 区切りを置くディレクトリ（`Documents/RecordingSegments/<最終ファイル名>/`）。
    /// 孤児ファイルの走査（`RecordingRecoveryService`）は Documents 直下しか見ないので、ここは対象にならない。
    static func directory(for finalURL: URL) -> URL {
        finalURL.deletingLastPathComponent()
            .appendingPathComponent("RecordingSegments", isDirectory: true)
            .appendingPathComponent(finalURL.deletingPathExtension().lastPathComponent, isDirectory: true)
    }

    static func segmentURL(index: Int, in directory: URL, fileExtension: String) -> URL {
        directory.appendingPathComponent(String(format: "seg-%04d", index)).appendingPathExtension(fileExtension)
    }

    /// ディレクトリ内の区切りを番号順に並べる
    static func segmentFiles(in directory: URL, fileManager: FileManager = .default) -> [URL] {
        let entries = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return entries
            .filter { $0.lastPathComponent.hasPrefix("seg-") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    enum MergeError: Error, Equatable {
        case noSegments
        case exportFailed(String)
    }

    /// 区切りを1つのファイルにつなぐ。区切りが1つだけなら移動するだけ。
    /// WAV は PCM をそのまま書き足す（劣化なし）。m4a は再エンコードせずにつなぐ。
    static func merge(_ segments: [URL], into destination: URL, fileManager: FileManager = .default) async throws {
        guard let first = segments.first else { throw MergeError.noSegments }
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        if segments.count == 1 {
            try fileManager.moveItem(at: first, to: destination)
            return
        }
        switch destination.pathExtension.lowercased() {
        case "wav", "aif", "aiff", "caf":
            try mergePCM(segments, into: destination)
        default:
            try await mergeCompressed(segments, into: destination)
        }
    }

    private static func mergePCM(_ segments: [URL], into destination: URL) throws {
        let firstFile = try AVAudioFile(forReading: segments[0])
        let output = try AVAudioFile(
            forWriting: destination,
            settings: firstFile.fileFormat.settings,
            commonFormat: firstFile.processingFormat.commonFormat,
            interleaved: firstFile.processingFormat.isInterleaved
        )
        let chunk: AVAudioFrameCount = 1 << 16
        for url in segments {
            let input = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: input.processingFormat, frameCapacity: chunk) else { continue }
            while input.framePosition < input.length {
                try input.read(into: buffer, frameCount: chunk)
                if buffer.frameLength == 0 { break }
                try output.write(from: buffer)
            }
        }
    }

    private static func mergeCompressed(_ segments: [URL], into destination: URL) async throws {
        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { throw MergeError.exportFailed("could not add track") }

        var cursor = CMTime.zero
        for url in segments {
            let asset = AVURLAsset(url: url)
            guard let source = try await asset.loadTracks(withMediaType: .audio).first else { continue }
            let duration = try await asset.load(.duration)
            try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: source, at: cursor)
            cursor = CMTimeAdd(cursor, duration)
        }

        // まず再エンコードなし（速い・劣化なし）で試し、だめなら AAC で書き直す
        for preset in [AVAssetExportPresetPassthrough, AVAssetExportPresetAppleM4A] {
            guard let session = AVAssetExportSession(asset: composition, presetName: preset) else { continue }
            do {
                try await session.export(to: destination, as: .m4a)
                return
            } catch {
                try? FileManager.default.removeItem(at: destination)
                Logger(subsystem: "com.voilog.recording", category: "RecordingSegments")
                    .warning("Export with \(preset) failed: \(error.localizedDescription)")
            }
        }
        throw MergeError.exportFailed("all presets failed")
    }
}

/// 強制終了で data サイズが 0 のまま残った WAV のヘッダを、実ファイル長から書き直す（#223）。
///
/// CoreAudio は WAV の RIFF サイズと data サイズを閉じるときにしか書かない。
/// 音声データ自体は書き込まれているので、ヘッダを直せば全部読める（Mac で実測: 134.7 秒ぶん全量復元）。
enum WAVHeaderRepair {
    /// - Returns: 書き直したら true。WAV でない・直す必要がないなら false
    @discardableResult
    static func repairIfNeeded(_ url: URL) throws -> Bool {
        let handle = try FileHandle(forUpdating: url)
        defer { try? handle.close() }

        let fileLength = try handle.seekToEnd()
        guard fileLength > 12 else { return false }
        try handle.seek(toOffset: 0)
        guard let header = try handle.read(upToCount: 12), header.count == 12,
              header.prefix(4) == Data("RIFF".utf8),
              header.subdata(in: 8..<12) == Data("WAVE".utf8) else { return false }

        // チャンクを順にたどって data を探す
        var offset: UInt64 = 12
        while offset + 8 <= fileLength {
            try handle.seek(toOffset: offset)
            guard let chunkHeader = try handle.read(upToCount: 8), chunkHeader.count == 8 else { return false }
            let chunkID = chunkHeader.prefix(4)
            let chunkSize = UInt64(chunkHeader.subdata(in: 4..<8).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.littleEndian)

            if chunkID == Data("data".utf8) {
                let actualDataSize = fileLength - offset - 8
                let actualRIFFSize = fileLength - 8
                // 4GiB を超える WAV は RIFF では表せない（CoreAudio は BW64 に切り替える）。区切り録音では起きない
                guard actualRIFFSize <= UInt64(UInt32.max) else { return false }
                guard chunkSize != actualDataSize else { return false }

                try handle.seek(toOffset: offset + 4)
                try handle.write(contentsOf: withUnsafeBytes(of: UInt32(actualDataSize).littleEndian) { Data($0) })
                try handle.seek(toOffset: 4)
                try handle.write(contentsOf: withUnsafeBytes(of: UInt32(actualRIFFSize).littleEndian) { Data($0) })
                return true
            }
            offset += 8 + chunkSize + (chunkSize & 1)
        }
        return false
    }
}

/// 録音中のセッションを記録しておき、強制終了したら次の起動で取り込む（#223）。
///
/// 録音を始めたら記録を足し、一覧へ保存したら消す。起動時に前のプロセスの記録が残っていれば、
/// 区切りのヘッダを直して1ファイルにつなぎ、一覧に戻す。
struct RecordingJournal {
    struct Entry: Codable, Equatable {
        var finalPath: String
        var startedAt: Date
        /// 記録したプロセス。同じプロセスの記録（いま録音中かもしれない）は復旧の対象にしない
        var processID: UUID

        var finalURL: URL { URL(fileURLWithPath: finalPath) }
    }

    /// プロセスごとに1回だけ作る ID
    static let currentProcessID = UUID()
    static let key = "InProgressRecordingJournal"

    var defaults: UserDefaults = .standard

    func entries() -> [Entry] {
        guard let data = defaults.data(forKey: Self.key) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    func add(finalURL: URL, startedAt: Date = Date(), processID: UUID = RecordingJournal.currentProcessID) {
        var list = entries().filter { $0.finalPath != finalURL.path }
        list.append(Entry(finalPath: finalURL.path, startedAt: startedAt, processID: processID))
        save(list)
    }

    func remove(finalURL: URL) {
        save(entries().filter { $0.finalPath != finalURL.path })
    }

    private func save(_ list: [Entry]) {
        if list.isEmpty {
            defaults.removeObject(forKey: Self.key)
        } else if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: Self.key)
        }
    }
}

/// 前のプロセスで終わらなかった録音を、ファイルとして復旧する（Core Data への登録は呼び出し側）。
enum InterruptedRecordingRecovery {
    private static let logger = Logger(subsystem: "com.voilog.recording", category: "InterruptedRecordingRecovery")

    /// - Returns: 復旧できた（最終ファイルが存在する）録音の ID。一覧に未登録かどうかは呼び出し側が判定する
    static func recover(
        journal: RecordingJournal = RecordingJournal(),
        currentProcessID: UUID = RecordingJournal.currentProcessID,
        fileManager: FileManager = .default
    ) async -> [UUID] {
        var recoveredIDs: [UUID] = []
        for entry in journal.entries() where entry.processID != currentProcessID {
            let finalURL = entry.finalURL
            let directory = RecordingSegments.directory(for: finalURL)

            if fileManager.fileExists(atPath: directory.path) {
                let readable = RecordingSegments.segmentFiles(in: directory, fileManager: fileManager)
                    .filter(isReadableAfterRepair)
                if !readable.isEmpty, !fileManager.fileExists(atPath: finalURL.path) {
                    do {
                        try await RecordingSegments.merge(readable, into: finalURL, fileManager: fileManager)
                        logger.info("Recovered \(readable.count) segment(s) into \(finalURL.lastPathComponent)")
                    } catch {
                        // つなげなかったら区切りは消さずに残す（次の起動でもう一度試す）
                        logger.error("Failed to merge segments for \(finalURL.lastPathComponent): \(error.localizedDescription)")
                        continue
                    }
                }
                try? fileManager.removeItem(at: directory)
            } else if fileManager.fileExists(atPath: finalURL.path) {
                // 区切りなしで書いていた時期のファイル、または結合後に保存前で終了したもの
                if finalURL.pathExtension.lowercased() == "wav" {
                    _ = try? WAVHeaderRepair.repairIfNeeded(finalURL)
                }
            }

            if fileManager.fileExists(atPath: finalURL.path) {
                recoveredIDs.append(RecordingRecoveryService.recordingID(for: finalURL))
            }
            journal.remove(finalURL: finalURL)
        }
        return recoveredIDs
    }

    /// WAV ならヘッダを直してから、開けて長さがあるかを確かめる。書きかけの m4a はここで落ちる
    static func isReadableAfterRepair(_ url: URL) -> Bool {
        if url.pathExtension.lowercased() == "wav" {
            _ = try? WAVHeaderRepair.repairIfNeeded(url)
        }
        guard let file = try? AVAudioFile(forReading: url) else { return false }
        return file.length > 0
    }
}

/// 起動時に前のプロセスの録音を復旧する入口（VoiceAppFeature から呼ぶ）
struct InterruptedRecordingRecoveryClient {
    /// - Returns: ファイルとして復旧できた録音の ID
    var recover: @Sendable () async -> [UUID]
}

extension InterruptedRecordingRecoveryClient: DependencyKey {
    static let liveValue = Self { await RecoveryOnce.shared.run() }
    /// テストでは何も復旧しない（実際の Documents と UserDefaults に触らない）
    static let testValue = Self { [] }
    static let previewValue = testValue
}

extension DependencyValues {
    var interruptedRecordingRecovery: InterruptedRecordingRecoveryClient {
        get { self[InterruptedRecordingRecoveryClient.self] }
        set { self[InterruptedRecordingRecoveryClient.self] = newValue }
    }
}

/// onAppear は何度も呼ばれうるので、復旧はプロセスごとに1回だけにする
private actor RecoveryOnce {
    static let shared = RecoveryOnce()
    private var done = false

    func run() async -> [UUID] {
        guard !done else { return [] }
        done = true
        return await InterruptedRecordingRecovery.recover()
    }
}
