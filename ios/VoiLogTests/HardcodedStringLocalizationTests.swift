import XCTest
@testable import VoiLog

/// Issue #221 / #222: Swift に直書きしていた日本語をカタログ経由にした文言のテスト。
///
/// 未登録のキーは実行時に日本語の原文がそのまま表示される（英語圏のユーザーに日本語が出る）。
/// コンパイルでは検出できないので、キーの存在と英語・ドイツ語の訳に日本語が残っていないことを押さえる。
final class HardcodedStringLocalizationTests: XCTestCase {

    /// テーブルごとのキー。コード側の文言を変えたらここも変える
    private static let keys: [String: [String]] = [
        "Playback": [
            "【%@】",
            "録音日時: %@",
            "再生時間: %@",
            "録音日時: %1$@  /  再生時間: %2$@",
            "【音声メモ詳細レポート】",
            "タイトル: %@",
            "ファイルサイズ: %@",
            "形式: %@",
            "サンプリングレート: %lld Hz",
            "ビット深度: %lld bit",
            "チャンネル: %@",
            "音声認識テキスト:",
            "モノラル (1ch)",
            "ステレオ (2ch)",
            "%lldチャンネル",
            "1x (標準)",
            "エクスポートセッションの作成に失敗しました"
        ],
        "AudioEditor": [
            "トリム: %1$@秒 - %2$@秒",
            "分割: %@秒",
            "結合",
            "音量調整: %1$@倍 (%2$@秒 - %3$@秒)",
            "音量調整: %@倍 (全体)",
            "分割音声 %@",
            "%@ (前半)",
            "音声ファイルが見つかりません: %@",
            "バッファの作成に失敗しました",
            "トラックの作成に失敗しました",
            "オーディオトラックが見つかりません",
            "エクスポートセッションの作成に失敗しました",
            "エクスポートに失敗しました",
            "エクスポートがキャンセルされました",
            "不明なエラーが発生しました",
            "分割ポイントが無効です（0秒または音声の終端以降）",
            "結合する音声ファイルがありません"
        ],
        "Playlist": [
            "再生に失敗しました",
            "プレイリストが見つかりません",
            "ネットワークエラー: %@",
            "データベースエラー: %@",
            "不明なエラー: %@",
            "不明なエラーが発生しました",
            "指定されたプレイリストが見つかりませんでした",
            "プレイリストの保存に失敗しました",
            "指定された音声が見つかりませんでした",
            "予期せぬエラーが発生しました: %@"
        ],
        "Localizable": [
            "VoiLogへようこそ！",
            "チュートリアル完了",
            "会議・講義・アイデアを\nワンタップで録音保存。\n実際に試してみましょう！",
            "チュートリアル完了です！\nVoiLogをお楽しみください。"
        ],
        "Settings": ["7日間無料！"],
        "Premium": ["7日間無料で試す"]
    ]

    private static let missingSentinel = "__MISSING__"

    private static func bundle(for language: String) throws -> Bundle {
        let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"), "\(language).lproj がない")
        return try XCTUnwrap(Bundle(path: path))
    }

    private static func containsJapanese(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x3040...0x30FF).contains(scalar.value) || (0x4E00...0x9FFF).contains(scalar.value)
        }
    }

    func testEveryKeyIsRegisteredInTheCatalog() {
        for (table, keys) in Self.keys {
            for key in keys {
                let localized = Bundle.main.localizedString(forKey: key, value: Self.missingSentinel, table: table)
                XCTAssertNotEqual(localized, Self.missingSentinel, "\(table).xcstrings に未登録のキーがある: \(key)")
            }
        }
    }

    func testEnglishAndGermanHaveNoJapaneseLeft() throws {
        for language in ["en", "de"] {
            let bundle = try Self.bundle(for: language)
            for (table, keys) in Self.keys {
                for key in keys {
                    let value = bundle.localizedString(forKey: key, value: Self.missingSentinel, table: table)
                    XCTAssertNotEqual(value, Self.missingSentinel, "\(language)/\(table) に訳がない: \(key)")
                    XCTAssertFalse(Self.containsJapanese(value), "\(language)/\(table) に日本語が残っている: \(value)")
                }
            }
        }
    }

    // MARK: - #222 トライアル期間は7日間にそろえる

    func testTrialWordingIsSevenDaysInEnglish() throws {
        let english = try Self.bundle(for: "en")
        let settings = english.localizedString(forKey: "7日間無料！", value: nil, table: "Settings")
        let premium = english.localizedString(forKey: "7日間無料で試す", value: nil, table: "Premium")
        XCTAssertTrue(settings.contains("7"), settings)
        XCTAssertTrue(premium.contains("7"), premium)
        XCTAssertFalse(settings.localizedCaseInsensitiveContains("month"), settings)
        XCTAssertFalse(premium.localizedCaseInsensitiveContains("month"), premium)
    }

    // MARK: - 共有テキスト・レポート

    private let memo = PlaybackFeature.VoiceMemo(
        title: "週次ミーティング",
        date: Date(timeIntervalSince1970: 1_790_000_000),
        duration: 125,
        url: URL(fileURLWithPath: "/tmp/test.m4a"),
        text: "本日の会議を始めます。",
        fileFormat: "m4a",
        samplingFrequency: 44_100,
        quantizationBitDepth: 16,
        numberOfChannels: 2,
        fileSize: 1_024_576
    )

    func testTranscriptHeader_containsTitleAndMetaLines() {
        let header = MemoShareTextFormatter.transcriptHeader(title: memo.title, date: memo.date, duration: memo.duration)
        XCTAssertTrue(header.contains(memo.title))
        XCTAssertTrue(header.contains(MemoShareTextFormatter.recordedAtLine(memo.date)))
        XCTAssertTrue(header.contains(MemoShareTextFormatter.durationLine(memo.duration)))
        XCTAssertTrue(header.hasSuffix("\n\n"))
        XCTAssertFalse(header.contains("%"), header)
    }

    func testPDFMetaLine_containsDateAndDuration() {
        let line = MemoShareTextFormatter.pdfMetaLine(date: memo.date, duration: memo.duration)
        XCTAssertTrue(line.contains(MemoShareTextFormatter.detailedDate(memo.date)))
        XCTAssertTrue(line.contains(MemoShareTextFormatter.detailedDuration(memo.duration)))
        XCTAssertFalse(line.contains("%"), line)
    }

    func testDetailReport_containsAllValues() {
        let report = MemoShareTextFormatter.detailReport(memo: memo, fileSize: "1 MB", fileFormat: "AAC")
        for expected in [memo.title, "1 MB", "AAC", 44_100.formatted(), "16", memo.text, MemoShareTextFormatter.channelConfiguration(2)] {
            XCTAssertTrue(report.contains(expected), "\(expected) が含まれない: \(report)")
        }
        XCTAssertFalse(report.contains("%"), report)
    }

    func testDetailReport_omitsTranscriptionSectionWhenEmpty() {
        var memo = memo
        memo.text = ""
        let report = MemoShareTextFormatter.detailReport(memo: memo, fileSize: "1 MB", fileFormat: "AAC")
        XCTAssertFalse(report.contains(String(localized: "音声認識テキスト:", table: "Playback")))
    }

    func testDateAndDurationFollowTheGivenLocale() {
        let english = Locale(identifier: "en_US")
        XCTAssertFalse(Self.containsJapanese(MemoShareTextFormatter.detailedDate(memo.date, locale: english)))
        XCTAssertEqual(MemoShareTextFormatter.detailedDuration(125, locale: english), "2 minutes, 5 seconds")
        XCTAssertEqual(MemoShareTextFormatter.detailedDuration(5, locale: english), "5 seconds")
        XCTAssertEqual(MemoShareTextFormatter.detailedDuration(3_725, locale: english), "1 hour, 2 minutes, 5 seconds")
    }

    func testChannelConfigurationForManyChannels() {
        let value = MemoShareTextFormatter.channelConfiguration(6)
        XCTAssertTrue(value.contains("6"), value)
        XCTAssertFalse(value.contains("%"), value)
    }

    // MARK: - プレイリストのエラー

    func testPlaylistErrorDescriptionsKeepTheUnderlyingMessage() {
        let errors: [PlaylistError] = [.networkError("timeout"), .databaseError("timeout"), .unknown("timeout")]
        for error in errors {
            let description = error.errorDescription ?? ""
            XCTAssertTrue(description.contains("timeout"), description)
            XCTAssertFalse(description.contains("%"), description)
        }
        XCTAssertEqual(PlaylistError.notFound.errorDescription, String(localized: "プレイリストが見つかりません", table: "Playlist"))
    }
}
