import Foundation
import os.log

/// VoiceMemo専用のファイル管理クラス
struct VoiceMemoFileManager {

    /// VoiceMemo専用のディレクトリパス
    static var voiceMemoDirectory: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("VoiceMemos", isDirectory: true)
    }

    /// VoiceMemo専用ディレクトリを作成（存在しない場合）
    static func ensureVoiceMemoDirectoryExists() throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: voiceMemoDirectory.path) {
            try fileManager.createDirectory(at: voiceMemoDirectory, withIntermediateDirectories: true, attributes: nil)
            AppLogger.file.info("VoiceMemo directory created at: \(voiceMemoDirectory.path)")
        }
    }

    /// 音声ファイルのURLを取得（複数の場所を探索）
    /// - Parameters:
    ///   - url: Core Dataに保存されているURL
    ///   - shouldMigrate: 見つかったファイルをVoiceMemoフォルダに移動するかどうか（デフォルト: true）
    /// - Returns: 実際に存在するファイルのURL、見つからない場合はnil
    static func findAudioFile(for url: URL, shouldMigrate: Bool = true) -> URL? {
        let fileName = url.lastPathComponent

        // まず元の拡張子で探す
        if let found = findAudioFileWithName(fileName, originalURL: url, shouldMigrate: shouldMigrate) {
            return found
        }

        // 見つからない場合、別の拡張子で探す (.m4a <-> .wav)
        let alternativeFileName = alternateExtension(for: fileName)
        if alternativeFileName != fileName {
            AppLogger.file.debug("Trying alternative extension: \(alternativeFileName)")
            if let found = findAudioFileWithName(alternativeFileName, originalURL: url, shouldMigrate: shouldMigrate) {
                return found
            }
        }

        AppLogger.file.error("Audio file not found for: \(url.path)")
        AppLogger.file.error("Searched with extensions: \(fileName), \(alternativeFileName)")

        return nil
    }

    /// 拡張子を切り替える (.m4a <-> .wav)
    private static func alternateExtension(for fileName: String) -> String {
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        let baseName = (fileName as NSString).deletingPathExtension

        switch fileExtension {
        case "m4a":
            return baseName + ".wav"
        case "wav":
            return baseName + ".m4a"
        default:
            return fileName
        }
    }

    /// 指定したファイル名で音声ファイルを探す
    private static func findAudioFileWithName(_ fileName: String, originalURL: URL, shouldMigrate: Bool) -> URL? {
        let fileManager = FileManager.default

        // 1. 元のURLのディレクトリ + 新しいファイル名で試す
        let originalDir = originalURL.deletingLastPathComponent()
        let urlWithFileName = originalDir.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: urlWithFileName.path) {
            AppLogger.file.debug("File found at original directory: \(urlWithFileName.path)")

            // VoiceMemo専用ディレクトリにない場合は移動を試みる
            if shouldMigrate && !urlWithFileName.path.contains("/VoiceMemos/") {
                AppLogger.file.info("Attempting to migrate file to VoiceMemo directory...")
                do {
                    let migratedURL = try copyToVoiceMemoDirectory(from: urlWithFileName, destinationFileName: fileName)
                    AppLogger.file.info("File migrated successfully")
                    return migratedURL
                } catch {
                    AppLogger.file.warning("Migration failed, using original URL: \(error.localizedDescription)")
                    return urlWithFileName
                }
            }

            return urlWithFileName
        }

        // 2. VoiceMemo専用ディレクトリ内を探す
        let voiceMemoPath = voiceMemoDirectory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: voiceMemoPath.path) {
            AppLogger.file.debug("File found in VoiceMemo directory: \(voiceMemoPath.path)")
            return voiceMemoPath
        }

        // 3. Documentsディレクトリ直下を探す
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let documentsPath = documentsDirectory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: documentsPath.path) {
            AppLogger.file.debug("File found in Documents directory: \(documentsPath.path)")
            return migrateIfNeeded(documentsPath, shouldMigrate: shouldMigrate)
        }

        // 4. Temporaryディレクトリを探す
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempPath = tempDirectory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: tempPath.path) {
            AppLogger.file.debug("File found in Temporary directory: \(tempPath.path)")
            return migrateIfNeeded(tempPath, shouldMigrate: shouldMigrate)
        }

        // 5. Documentsディレクトリ内を再帰的に探す
        AppLogger.file.debug("Searching recursively in Documents directory...")
        if let foundURL = searchRecursively(in: documentsDirectory, fileName: fileName) {
            AppLogger.file.debug("File found recursively: \(foundURL.path)")
            return migrateIfNeeded(foundURL, shouldMigrate: shouldMigrate)
        }

        // 6. Cachesディレクトリを探す
        if let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let cachesPath = cachesDirectory.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: cachesPath.path) {
                AppLogger.file.debug("File found in Caches directory: \(cachesPath.path)")
                return migrateIfNeeded(cachesPath, shouldMigrate: shouldMigrate)
            }

            // Cachesディレクトリ内も再帰的に探す
            if let foundURL = searchRecursively(in: cachesDirectory, fileName: fileName) {
                AppLogger.file.debug("File found recursively in Caches: \(foundURL.path)")
                return migrateIfNeeded(foundURL, shouldMigrate: shouldMigrate)
            }
        }

        // 見つからなかった
        return nil
    }

    /// ファイルを必要に応じてVoiceMemoフォルダに移動
    private static func migrateIfNeeded(_ url: URL, shouldMigrate: Bool) -> URL {
        guard shouldMigrate else { return url }
        guard !url.path.contains("/VoiceMemos/") else { return url }

        AppLogger.file.info("Attempting to migrate file to VoiceMemo directory...")
        do {
            let migratedURL = try copyToVoiceMemoDirectory(from: url, destinationFileName: url.lastPathComponent)
            AppLogger.file.info("File migrated successfully")
            return migratedURL
        } catch {
            AppLogger.file.warning("Migration failed, using original URL: \(error.localizedDescription)")
            return url
        }
    }

    /// ディレクトリ内を再帰的に探索
    private static func searchRecursively(in directory: URL, fileName: String, maxDepth: Int = 5, currentDepth: Int = 0) -> URL? {
        guard currentDepth < maxDepth else { return nil }

        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent == fileName {
                if fileManager.fileExists(atPath: fileURL.path) {
                    return fileURL
                }
            }
        }

        return nil
    }

    /// 新しい録音ファイルのURLを生成（VoiceMemo専用ディレクトリ内）
    /// - Parameter uuid: 録音のUUID
    /// - Returns: VoiceMemo専用ディレクトリ内の新しいファイルURL
    static func newRecordingURL(uuid: UUID) throws -> URL {
        try ensureVoiceMemoDirectoryExists()
        return voiceMemoDirectory
            .appendingPathComponent(uuid.uuidString)
            .appendingPathExtension("m4a")
    }

    /// ファイルをVoiceMemo専用ディレクトリに移動
    /// - Parameters:
    ///   - sourceURL: 移動元のURL
    ///   - destinationFileName: 移動先のファイル名（nilの場合は元のファイル名を使用）
    /// - Returns: 移動後のURL
    @discardableResult
    static func moveToVoiceMemoDirectory(from sourceURL: URL, destinationFileName: String? = nil) throws -> URL {
        try ensureVoiceMemoDirectoryExists()

        let fileName = destinationFileName ?? sourceURL.lastPathComponent
        let destinationURL = voiceMemoDirectory.appendingPathComponent(fileName)

        let fileManager = FileManager.default

        // すでに同じファイルが存在する場合は削除
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        // ファイルを移動
        try fileManager.moveItem(at: sourceURL, to: destinationURL)
        AppLogger.file.info("Moved file to VoiceMemo directory: \(destinationURL.path)")

        return destinationURL
    }

    /// ファイルをVoiceMemo専用ディレクトリにコピー
    /// - Parameters:
    ///   - sourceURL: コピー元のURL
    ///   - destinationFileName: コピー先のファイル名（nilの場合は元のファイル名を使用）
    /// - Returns: コピー後のURL
    @discardableResult
    static func copyToVoiceMemoDirectory(from sourceURL: URL, destinationFileName: String? = nil) throws -> URL {
        try ensureVoiceMemoDirectoryExists()

        let fileName = destinationFileName ?? sourceURL.lastPathComponent
        let destinationURL = voiceMemoDirectory.appendingPathComponent(fileName)

        let fileManager = FileManager.default

        // すでに同じファイルが存在する場合は削除
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        // ファイルをコピー
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        AppLogger.file.info("Copied file to VoiceMemo directory: \(destinationURL.path)")

        return destinationURL
    }
}
