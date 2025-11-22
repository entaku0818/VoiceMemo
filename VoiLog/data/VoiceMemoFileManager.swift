import Foundation

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
            print("📁 VoiceMemo directory created at: \(voiceMemoDirectory.path)")
        }
    }

    /// 音声ファイルのURLを取得（複数の場所を探索）
    /// - Parameters:
    ///   - url: Core Dataに保存されているURL
    ///   - shouldMigrate: 見つかったファイルをVoiceMemoフォルダに移動するかどうか（デフォルト: true）
    /// - Returns: 実際に存在するファイルのURL、見つからない場合はnil
    static func findAudioFile(for url: URL, shouldMigrate: Bool = true) -> URL? {
        let fileManager = FileManager.default
        let fileName = url.lastPathComponent

        // 1. まず指定されたURLをそのまま試す
        if fileManager.fileExists(atPath: url.path) {
            print("📍 File found at original URL: \(url.path)")

            // VoiceMemo専用ディレクトリにない場合は移動を試みる
            if shouldMigrate && !url.path.contains("/VoiceMemos/") {
                print("🔄 Attempting to migrate file to VoiceMemo directory...")
                do {
                    let migratedURL = try copyToVoiceMemoDirectory(from: url, destinationFileName: fileName)
                    // コピー成功したら元ファイルは削除しない（安全のため）
                    print("✅ File migrated successfully")
                    return migratedURL
                } catch {
                    print("⚠️ Migration failed, using original URL: \(error.localizedDescription)")
                    return url
                }
            }

            return url
        }

        // 2. VoiceMemo専用ディレクトリ内を探す
        let voiceMemoPath = voiceMemoDirectory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: voiceMemoPath.path) {
            print("📍 File found in VoiceMemo directory: \(voiceMemoPath.path)")
            return voiceMemoPath
        }

        // 3. Documentsディレクトリ直下を探す
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let documentsPath = documentsDirectory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: documentsPath.path) {
            print("📍 File found in Documents directory: \(documentsPath.path)")
            return migrateIfNeeded(documentsPath, shouldMigrate: shouldMigrate)
        }

        // 4. Temporaryディレクトリを探す
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempPath = tempDirectory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: tempPath.path) {
            print("📍 File found in Temporary directory: \(tempPath.path)")
            return migrateIfNeeded(tempPath, shouldMigrate: shouldMigrate)
        }

        // 5. Documentsディレクトリ内を再帰的に探す
        print("🔍 Searching recursively in Documents directory...")
        if let foundURL = searchRecursively(in: documentsDirectory, fileName: fileName) {
            print("📍 File found recursively: \(foundURL.path)")
            return migrateIfNeeded(foundURL, shouldMigrate: shouldMigrate)
        }

        // 6. Cachesディレクトリを探す
        if let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let cachesPath = cachesDirectory.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: cachesPath.path) {
                print("📍 File found in Caches directory: \(cachesPath.path)")
                return migrateIfNeeded(cachesPath, shouldMigrate: shouldMigrate)
            }

            // Cachesディレクトリ内も再帰的に探す
            if let foundURL = searchRecursively(in: cachesDirectory, fileName: fileName) {
                print("📍 File found recursively in Caches: \(foundURL.path)")
                return migrateIfNeeded(foundURL, shouldMigrate: shouldMigrate)
            }
        }

        print("❌ Audio file not found for: \(url.path)")
        print("   Searched in:")
        print("   - Original URL: \(url.path)")
        print("   - VoiceMemo directory: \(voiceMemoPath.path)")
        print("   - Documents directory: \(documentsPath.path)")
        print("   - Temporary directory: \(tempPath.path)")
        print("   - Documents (recursive)")
        print("   - Caches (recursive)")

        return nil
    }

    /// ファイルを必要に応じてVoiceMemoフォルダに移動
    private static func migrateIfNeeded(_ url: URL, shouldMigrate: Bool) -> URL {
        guard shouldMigrate else { return url }
        guard !url.path.contains("/VoiceMemos/") else { return url }

        print("🔄 Attempting to migrate file to VoiceMemo directory...")
        do {
            let migratedURL = try copyToVoiceMemoDirectory(from: url, destinationFileName: url.lastPathComponent)
            print("✅ File migrated successfully")
            return migratedURL
        } catch {
            print("⚠️ Migration failed, using original URL: \(error.localizedDescription)")
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
        print("📦 Moved file to VoiceMemo directory: \(destinationURL.path)")

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
        print("📋 Copied file to VoiceMemo directory: \(destinationURL.path)")

        return destinationURL
    }
}
