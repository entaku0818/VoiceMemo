//
//  RecordingRecoveryService.swift
//  VoiLog
//
//  Core Data のストアが失われても音声の実体ファイルは Documents 配下に残る。
//  （CoreDataStack が「開けなかったストアを削除」していた時期があり、
//   その結果メタデータだけが消えて一覧が空になったユーザーがいる）
//  このサービスは孤児になった音声ファイルを走査し、一覧へ復帰させる。
//

import Foundation
import AVFoundation
import CryptoKit
import os.log

/// Core Data に対応する行が無い音声ファイル
struct OrphanedRecording: Equatable {
    /// ファイル名から決定的に導出した ID。再スキャンしても同じ値になる。
    let id: UUID
    let url: URL
    let createdAt: Date
    let fileSize: Int64
}

enum RecordingRecoveryService {

    /// 復元対象とする拡張子
    static let supportedExtensions: Set<String> = ["m4a", "wav"]

    /// 復元候補として無視するファイルサイズの下限（空ファイル・書きかけの除外）
    static let minimumFileSize: Int64 = 1024

    /// 録音ファイルとして扱ってよいファイルか。
    ///
    /// 通常は `<UUID>.m4a` だが、iCloud から引き戻したファイルは
    /// `CloudUploader.downloadVoiceFile` が拡張子なしの `<UUID>` で保存する。
    /// 拡張子が無くてもファイル名が UUID なら対象に含める（Documents 直下には
    /// plist や sqlite など無関係のファイルもあるため、UUID 判定で絞る）。
    static func looksLikeRecording(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if ext.isEmpty {
            return UUID(uuidString: url.lastPathComponent) != nil
        }
        return supportedExtensions.contains(ext)
    }

    // MARK: - Scan (pure / testable)

    /// 指定ディレクトリ群を走査し、`knownIDs` に含まれない音声ファイルを列挙する。
    ///
    /// 副作用を持たない純粋な走査処理。Core Data も実 Documents ディレクトリも参照しないため
    /// 一時ディレクトリだけでテストできる。
    ///
    /// - Parameters:
    ///   - directories: 走査するディレクトリ（存在しないものは黙って読み飛ばす）
    ///   - knownIDs: すでに Core Data に登録済みの録音 ID
    /// - Returns: 作成日時の昇順で並べた孤児ファイル
    static func findOrphanedRecordings(
        in directories: [URL],
        knownIDs: Set<UUID>,
        fileManager: FileManager = .default
    ) -> [OrphanedRecording] {
        var found: [UUID: OrphanedRecording] = [:]

        for directory in directories {
            guard let entries = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in entries {
                guard looksLikeRecording(url) else { continue }

                let values = try? url.resourceValues(
                    forKeys: [.creationDateKey, .fileSizeKey, .isRegularFileKey]
                )
                guard values?.isRegularFile != false else { continue }

                let fileSize = Int64(values?.fileSize ?? 0)
                guard fileSize >= minimumFileSize else { continue }

                let id = recordingID(for: url)
                guard !knownIDs.contains(id) else { continue }
                // 同じファイルが複数ディレクトリで見つかった場合は最初の1件だけ採用する
                guard found[id] == nil else { continue }

                found[id] = OrphanedRecording(
                    id: id,
                    url: url,
                    createdAt: values?.creationDate ?? Date(),
                    fileSize: fileSize
                )
            }
        }

        return found.values.sorted { $0.createdAt < $1.createdAt }
    }

    /// ファイル名から録音 ID を決定的に導出する。
    ///
    /// アプリが作るファイルは `<UUID>.m4a` なのでそのまま UUID として解釈する。
    /// それ以外の名前でも、ファイル名から安定した UUID を生成することで
    /// 「復元を2回実行すると重複が増える」ことを防ぐ。
    static func recordingID(for url: URL) -> UUID {
        let baseName = url.deletingPathExtension().lastPathComponent
        if let parsed = UUID(uuidString: baseName) {
            return parsed
        }
        return deterministicUUID(from: baseName)
    }

    /// 任意の文字列から決定的な UUID を作る（MD5 ダイジェストの 16 バイトを利用）
    static func deterministicUUID(from string: String) -> UUID {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        var bytes = [UInt8](digest)
        // RFC 4122 のバージョン/バリアントビットを立てて正規の UUID 形式にする
        bytes[6] = (bytes[6] & 0x0F) | 0x30
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    /// 復元時に付けるタイトル（録音日時ベース）
    static func recoveredTitle(for date: Date, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// アプリが録音ファイルを置きうるディレクトリ
    static func defaultSearchDirectories() -> [URL] {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return [documents, VoiceMemoFileManager.voiceMemoDirectory]
    }

    // MARK: - Duration probing

    /// 音声ファイルの再生時間を読み取る。読めない場合は 0 を返す（復元自体は続行する）
    static func duration(of url: URL) async -> Double {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            return seconds.isFinite && seconds > 0 ? seconds : 0
        } catch {
            AppLogger.file.warning("Failed to read duration for \(url.lastPathComponent): \(error.localizedDescription)")
            return 0
        }
    }
}
