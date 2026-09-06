import XCTest
@testable import VoiLog

/// 復元まわりの文言が Settings カタログに登録されているかを見るテスト。
///
/// 未登録のキーは実行時に日本語の原文がそのまま表示される（英語圏のユーザーに日本語が出る）。
/// コンパイルでは検出できないので、キーの存在をテストで押さえる。
final class RecoveryLocalizationTests: XCTestCase {

    /// SettingView / DiagnosticsShareView が使うキー。コード側の文言を変えたらここも変える
    private static let keys: [String] = [
        "録音の復元",
        """
        一覧から録音が消えても、音声ファイル自体は端末内やiCloudに残っていることがあります。\
        両方を調べて一覧に戻します。タイトル・タグ・文字起こしは復元されず、録音日時からタイトルを付け直します。
        復元できない場合は「診断情報を共有」で状況をコピーし、お問い合わせに添付してください。
        """,
        "消えた録音を復元",
        "診断情報を共有",
        "録音を復元しました",
        "復元できる録音はありませんでした",
        "端末内から%1$d件、iCloudから%2$d件の録音を一覧に戻しました。タイトルは録音日時から付け直しています。",
        "iCloudから%d件の録音を一覧に戻しました。タイトル・文字起こしも一緒に戻っています。",
        "端末内から%d件の録音を一覧に戻しました。タイトルは録音日時から付け直しているため、必要に応じて変更してください。",
        """
        端末内とiCloudの両方を調べましたが、一覧に無い録音は見つかりませんでした。\
        端末からファイルごと削除された録音は、この方法では戻せません。
        """,
        """
        端末内を調べましたが、一覧に無い録音は見つかりませんでした。\
        iCloudにサインインすると、iCloudに同期済みの録音も確認できます。
        """,
        "診断情報",
        "この内容に録音の音声や文字起こしは含まれません。件数・サイズ・端末情報だけです。",
        "閉じる"
    ]

    private static let missingSentinel = "__MISSING__"

    func testEveryRecoveryStringIsRegisteredInTheCatalog() {
        for key in Self.keys {
            let localized = Bundle.main.localizedString(
                forKey: key, value: Self.missingSentinel, table: "Settings"
            )
            XCTAssertNotEqual(
                localized,
                Self.missingSentinel,
                "Settings.xcstrings に未登録のキーがある: \(key)"
            )
        }
    }

    func testRestoreMessagesComeFromTheCatalog() {
        // reducer が組み立てる4パターンがすべて空でないこと
        let outcomes: [SettingReducer.RestoreOutcome] = [
            .init(localCount: 2, cloudCount: 3, isCloudAvailable: true),
            .init(localCount: 0, cloudCount: 3, isCloudAvailable: true),
            .init(localCount: 2, cloudCount: 0, isCloudAvailable: true),
            .init(localCount: 0, cloudCount: 0, isCloudAvailable: false)
        ]

        for outcome in outcomes {
            let message = SettingView.restoreMessage(for: outcome)
            XCTAssertFalse(message.isEmpty)
            XCTAssertFalse(message.contains("%"), "書式指定子が残っている: \(message)")
        }
    }
}
