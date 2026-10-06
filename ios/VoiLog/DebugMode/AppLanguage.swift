import Foundation
import SwiftUI

#if DEBUG
// MARK: - Screenshot Strings
//
// App Store スクリーンショット用のモック文言は DebugMode/ScreenshotStrings/<code>.json に置く。
// 翻訳者は JSON だけを編集すればよい（キーの意味は ScreenshotStrings/README.md を参照）。
// - 言語は JSON ファイルの有無で自動的に増える（ファイル名 = iOS のローカライズコード）
// - ある言語に無いキーは en.json の値にフォールバックし、DEBUG ではログに出す
// - 文字列中の %d / %@ は `format(_:_:)` で置き換える
enum ScreenshotStrings {
    static let folderName = "ScreenshotStrings"
    static let fallbackCode = "en"

    private final class BundleToken {}

    /// JSON の入っているバンドル（ホストアプリ）。テストからでもアプリ側のバンドルを引く
    static var bundle: Bundle { Bundle(for: BundleToken.self) }

    /// 全言語の JSON（code → 中身）。初回アクセス時に一度だけ読み込む
    static let tables: [String: [String: Any]] = loadTables()

    /// ストアの並び順。ここに無いコードは末尾にアルファベット順で並べる
    static let preferredOrder = [
        "en", "ja", "de", "es", "fr", "it", "pt-PT", "ru", "tr", "vi", "zh-Hans", "zh-Hant",
        "ko", "ar", "id", "hi", "nl", "pl", "sv", "th", "pt-BR", "bn", "ca", "cs", "da", "el", "fi",
        "gu", "he", "hr", "hu", "kn", "ml", "mr", "ms", "nb", "or", "pa", "ro", "sk", "sl", "ta", "te",
        "uk", "ur"
    ]

    static var availableCodes: [String] {
        tables.keys.sorted { lhs, rhs in
            let li = preferredOrder.firstIndex(of: lhs) ?? Int.max
            let ri = preferredOrder.firstIndex(of: rhs) ?? Int.max
            return li == ri ? lhs < rhs : li < ri
        }
    }

    private static func jsonURLs() -> [URL] {
        // explicitFolders で ScreenshotStrings/ フォルダごとバンドルされる。
        // 念のためバンドル直下（フラット化された場合）も探す
        if let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: folderName), !urls.isEmpty {
            return urls
        }
        return bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
    }

    private static func loadTables() -> [String: [String: Any]] {
        var result: [String: [String: Any]] = [:]
        for url in jsonURLs() {
            guard let data = try? Data(contentsOf: url),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  object["display_name"] != nil else {
                continue
            }
            result[url.deletingPathExtension().lastPathComponent] = object
        }
        return result
    }

    private static var reportedMissing = Set<String>()
    private static let lock = NSLock()

    static func value(_ key: String, code: String) -> Any? {
        if let value = tables[code]?[key] {
            return value
        }
        lock.lock()
        if reportedMissing.insert("\(code).\(key)").inserted {
            print("[ScreenshotStrings] missing key '\(key)' in \(code).json — falling back to \(fallbackCode)")
        }
        lock.unlock()
        return tables[fallbackCode]?[key]
    }
}

// MARK: - Language
struct AppLanguage: Identifiable, Hashable {
    /// iOS のローカライズコード（JSON のファイル名）。例: "en", "pt-PT", "zh-Hans"
    let code: String

    var id: String { code }
    var rawValue: String { code }

    init(code: String) {
        self.code = code
    }

    static var allCases: [AppLanguage] {
        ScreenshotStrings.availableCodes.map(AppLanguage.init(code:))
    }

    static let english = AppLanguage(code: "en")
    static let japanese = AppLanguage(code: "ja")
    static let german = AppLanguage(code: "de")

    // MARK: Lookup

    func string(_ key: String) -> String {
        ScreenshotStrings.value(key, code: code) as? String ?? key
    }

    func strings(_ key: String) -> [String] {
        ScreenshotStrings.value(key, code: code) as? [String] ?? []
    }

    func element(_ key: String, _ index: Int) -> String {
        let list = strings(key)
        guard !list.isEmpty else { return key }
        return index < list.count ? list[index] : list[0]
    }

    /// `%d`（数値）と `%@`（文字列）を順番に置き換える。翻訳者が語順を変えても壊れにくいよう単純置換にしている
    func format(_ key: String, _ args: CVarArg...) -> String {
        var text = string(key)
        for arg in args {
            let placeholder = arg is String ? "%@" : "%d"
            if let range = text.range(of: placeholder) {
                text.replaceSubrange(range, with: "\(arg)")
            }
        }
        return text
    }

    private func bool(_ key: String) -> Bool {
        (ScreenshotStrings.value(key, code: code) as? Bool) ?? false
    }

    // MARK: Layout flags

    var isRightToLeft: Bool { bool("layout_rtl") }
    var locale: Locale { Locale(identifier: code) }
    /// ハングル・タイ文字のシステムフォントには .black がなく細い字形に落ちるため、出せる最も太いウェイトを使う
    var heroHeadlineWeight: Font.Weight { ["ko", "th"].contains(code) ? .bold : .black }

    // MARK: Page

    var displayName: String { string("display_name") }

    // MARK: Common mock strings

    var appTitle: String { string("app_title") }
    var recordingTitle: String { string("recording_title") }
    var recordingText: String { string("recording_status") }
    var recordingFiles: String { string("recording_files") }
    var lockScreenDate: String { string("lock_screen_date") }
    func sampleRecordingTitle(_ index: Int) -> String { element("sample_recording_titles", index) }
    func sampleDate(_ index: Int) -> String { format("sample_date", 10 + index) }
    func useCaseSampleTitle(_ index: Int) -> String { element("use_case_sample_titles", index) }
    func useCaseTag(_ index: Int) -> String { element("use_case_tags", index) }
    var playlist: String { string("playlist") }
    func playlistName(_ index: Int) -> String { element("playlist_names", index) }
    func recordingCount(_ count: Int) -> String { format("recording_count", count) }
    func createdDate(_ index: Int) -> String { format("created_date", 15 + index) }
    var audioEdit: String { string("audio_edit") }
    var split: String { string("split") }
    var cancel: String { string("cancel") }
    var save: String { string("save") }
    var delete: String { string("delete") }
    var audioRecording: String { string("audio_recording") }
    var copy: String { string("copy") }
    var saveToFiles: String { string("save_to_files") }
    var transcriptionTitle: String { string("transcription_title") }
    func transcriptionSampleText(_ index: Int) -> String { element("transcription_sample_texts", index) }
    var premiumScreenHeadline: String { string("premium_headline") }
    var premiumNoAds: String { string("premium_no_ads") }
    var premiumOffline: String { string("premium_offline") }
    var premiumUnlimited: String { string("premium_unlimited") }
    var premiumICloud: String { string("premium_icloud") }
    var premiumCTAButton: String { string("premium_cta") }
}

// MARK: - Locale / RTL
/// RTL 言語（ar / he / ur など JSON の layout_rtl = true）だけ右から左のレイアウトとロケールを適用する。
/// LTR 言語は既存の描画を変えないよう環境を触らない（CJK のグリフ選択がロケールで変わるため）
struct ScreenshotLanguageEnvironment: ViewModifier {
    let language: AppLanguage

    func body(content: Content) -> some View {
        if language.isRightToLeft {
            content
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, language.locale)
        } else {
            content
        }
    }
}

extension View {
    func screenshotLanguage(_ language: AppLanguage) -> some View {
        modifier(ScreenshotLanguageEnvironment(language: language))
    }
}
#endif
