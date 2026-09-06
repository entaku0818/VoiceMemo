//
//  RecoveryDiagnostics.swift
//  VoiLog
//
//  録音が一覧から消えたときに「端末が実際どうなっているか」を1枚のスナップショットにまとめる。
//  用途は2つ:
//   1. Crashlytics へ自動送信し、何人に起きているかをこちら側で把握する
//   2. 設定画面から本文を共有し、問い合わせメールに添付してもらう
//
//  本文は英語ラベル＋ISO8601 固定にしている。ユーザーのロケールに関係なく
//  同じ形で届いた方が問い合わせの突き合わせが速いため。
//

import Foundation
import FirebaseCore
import FirebaseCrashlytics

struct RecoveryDiagnostics: Equatable {
    /// Core Data ストアファイルの状態
    struct StoreState: Equatable {
        var exists = false
        var sizeBytes: Int64 = 0
        /// CoreDataStack が退避した `.corrupt-*` ファイルの名前
        var quarantinedFileNames: [String] = []
    }

    /// 端末内に残っている音声ファイルの状態
    struct AudioState: Equatable {
        var fileCount: Int = 0
        var totalBytes: Int64 = 0
        var oldest: Date?
        var newest: Date?
    }

    var collectedAt = Date()
    var appVersion: String = ""
    var buildNumber: String = ""
    var osVersion: String = ""
    var deviceModel: String = ""
    var freeDiskBytes: Int64?
    /// Core Data に残っている録音の行数。0 なら一覧が空の状態
    var coreDataRowCount: Int = 0
    var store = StoreState()
    var audio = AudioState()
    /// Core Data に行が無い音声ファイルの数
    var orphanCount: Int = 0
    /// iCloud(CloudKit) 上のレコード数。取得できなかった場合は nil
    var cloudRecordCount: Int?
    /// 直近のストア読み込み失敗（CoreDataStack が記録した内容）
    var lastStoreFailure: String?

    static let empty = RecoveryDiagnostics()
}

// MARK: - 収集

extension RecoveryDiagnostics {

    /// 音声ファイルの数・合計サイズ・最古/最新を数える。
    ///
    /// 復元対象の判定（`RecordingRecoveryService`）と違ってサイズ下限を設けない。
    /// 「0バイトのファイルばかり残っている」ような状態も、そのまま見えた方が調査に役立つため。
    static func audioState(in directories: [URL], fileManager: FileManager = .default) -> AudioState {
        var seenPaths = Set<String>()
        var state = AudioState()

        for directory in directories {
            guard let entries = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in entries {
                guard RecordingRecoveryService.looksLikeRecording(url) else { continue }
                guard seenPaths.insert(url.standardizedFileURL.path).inserted else { continue }

                let values = try? url.resourceValues(
                    forKeys: [.creationDateKey, .fileSizeKey, .isRegularFileKey]
                )
                guard values?.isRegularFile != false else { continue }

                state.fileCount += 1
                state.totalBytes += Int64(values?.fileSize ?? 0)

                if let created = values?.creationDate {
                    if state.oldest == nil || created < state.oldest! { state.oldest = created }
                    if state.newest == nil || created > state.newest! { state.newest = created }
                }
            }
        }

        return state
    }

    /// ストア本体の有無・サイズと、退避済みファイルの一覧
    static func storeState(storeURL: URL, fileManager: FileManager = .default) -> StoreState {
        let attributes = try? fileManager.attributesOfItem(atPath: storeURL.path)
        return StoreState(
            exists: fileManager.fileExists(atPath: storeURL.path),
            sizeBytes: (attributes?[.size] as? NSNumber)?.int64Value ?? 0,
            quarantinedFileNames: CoreDataStack
                .quarantinedStoreFiles(storeURL: storeURL, fileManager: fileManager)
                .map(\.lastPathComponent)
        )
    }

    /// 端末識別子（"iPhone16,1" 形式）。UIDevice.model は "iPhone" としか返さず機種が分からない
    static func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafeBytes(of: &systemInfo.machine) { raw -> String in
            let bytes = raw.prefix { $0 != 0 }
            return String(decoding: bytes, as: UTF8.self)
        }
        return machine.isEmpty ? "unknown" : machine
    }

    static func freeDiskBytes(fileManager: FileManager = .default) -> Int64? {
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
              let values = try? documents.resourceValues(
                forKeys: [.volumeAvailableCapacityForImportantUsageKey]
              ) else { return nil }
        return values.volumeAvailableCapacityForImportantUsage
    }
}

// MARK: - 出力

extension RecoveryDiagnostics {

    /// 問い合わせに添付してもらうための本文
    func formatted() -> String {
        var lines: [String] = []
        lines.append("VoiLog recovery diagnostics")
        lines.append("collected: \(Self.iso8601(collectedAt))")
        lines.append("app: \(appVersion) (\(buildNumber))")
        lines.append("os: \(osVersion)  device: \(deviceModel)")
        lines.append("free disk: \(Self.byteText(freeDiskBytes))")
        lines.append("core data rows: \(coreDataRowCount)")
        lines.append("store: \(store.exists ? "present" : "missing") (\(Self.byteText(store.sizeBytes)))")

        if store.quarantinedFileNames.isEmpty {
            lines.append("quarantined stores: 0")
        } else {
            lines.append(
                "quarantined stores: \(store.quarantinedFileNames.count) "
                    + "[\(store.quarantinedFileNames.joined(separator: ", "))]"
            )
        }

        lines.append(
            "audio files: \(audio.fileCount) (\(Self.byteText(audio.totalBytes)))"
                + " oldest=\(Self.iso8601(audio.oldest)) newest=\(Self.iso8601(audio.newest))"
        )
        lines.append("orphaned files: \(orphanCount)")
        lines.append("icloud records: \(cloudRecordCount.map(String.init) ?? "unavailable")")
        lines.append("last store failure: \(lastStoreFailure ?? "none")")
        return lines.joined(separator: "\n")
    }

    /// Crashlytics の custom keys。値はスカラーのみ（配列はダッシュボードで潰れるため件数と先頭1件にする）
    func crashlyticsKeys() -> [String: Any] {
        var keys: [String: Any] = [
            "recovery_core_data_rows": coreDataRowCount,
            "recovery_store_exists": store.exists,
            "recovery_store_bytes": store.sizeBytes,
            "recovery_quarantined_count": store.quarantinedFileNames.count,
            "recovery_audio_files": audio.fileCount,
            "recovery_audio_bytes": audio.totalBytes,
            "recovery_orphan_count": orphanCount,
            "recovery_icloud_records": cloudRecordCount ?? -1
        ]
        if let first = store.quarantinedFileNames.first {
            keys["recovery_quarantined_first"] = first
        }
        if let lastStoreFailure {
            keys["recovery_last_store_failure"] = lastStoreFailure
        }
        if let freeDiskBytes {
            keys["recovery_free_disk_bytes"] = freeDiskBytes
        }
        return keys
    }

    /// 「一覧は空なのに音声ファイルは残っている」＝ 今回の事故そのものの形かどうか。
    /// 自動送信を全実行ぶん送るとノイズになるので、この条件のときだけ非致命として送る。
    var looksLikeDataLoss: Bool {
        coreDataRowCount == 0 && audio.fileCount > 0
    }

    /// データ消失の形をしているときだけ Crashlytics に非致命として送る。
    ///
    /// 復元ボタンは「消えたかもしれない」と思った人が押すので、実行のたびに送ると
    /// 何も起きていないケースが大半を占めてしまう。`looksLikeDataLoss` で絞って
    /// 「一覧が空なのにファイルは残っている」＝ 事故そのものの形だけを拾う。
    func reportIfDataLoss() {
        guard looksLikeDataLoss else { return }
        guard FirebaseApp.app() != nil else { return }

        let crashlytics = Crashlytics.crashlytics()
        for (key, value) in crashlyticsKeys() {
            crashlytics.setCustomValue(value, forKey: key)
        }
        crashlytics.log(formatted())
        crashlytics.record(
            error: NSError(
                domain: "RecordingDataLossDetected",
                code: orphanCount,
                userInfo: [NSLocalizedDescriptionKey: formatted()]
            )
        )
    }

    private static func iso8601(_ date: Date?) -> String {
        guard let date else { return "-" }
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    private static func byteText(_ bytes: Int64?) -> String {
        guard let bytes else { return "unknown" }
        // ByteCountFormatter は端末ロケールで単位を訳すため、問い合わせ本文がぶれないよう自前で組む
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var index = 0
        while value >= 1000, index < units.count - 1 {
            value /= 1000
            index += 1
        }
        let text = index == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
        return "\(text) \(units[index])"
    }
}
