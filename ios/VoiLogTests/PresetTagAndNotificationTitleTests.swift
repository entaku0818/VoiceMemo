import XCTest
@testable import VoiLog

final class PresetTagAndNotificationTitleTests: XCTestCase {

  /// アプリに同梱された各言語の .lproj（String(localized:) の locale 引数は書式用で、言語の選択には効かない）
  private func bundle(_ code: String) throws -> Bundle {
    let path = try XCTUnwrap(Bundle.main.path(forResource: code, ofType: "lproj"), "\(code).lproj not found")
    return try XCTUnwrap(Bundle(path: path))
  }

  // MARK: - PresetTag

  func testStoredValues_AreUnchangedJapaneseForCompatibility() {
    // 既存の録音に保存済みのタグと一致させるため、保存値は変えない
    XCTAssertEqual(PresetTag.storedValues, ["会議", "講義", "インタビュー", "アイデア", "日記", "練習", "議事録", "メモ"])
  }

  func testDisplayName_English_TranslatesEveryPresetTag() throws {
    let en = try bundle("en")
    for tag in PresetTag.storedValues {
      let name = PresetTag.displayName(for: tag, bundle: en)
      XCTAssertFalse(name.isEmpty, tag)
      XCTAssertNil(name.range(of: "[ぁ-んァ-ヶ一-龠]", options: .regularExpression), "\(tag) → \(name)")
    }
    XCTAssertEqual(PresetTag.displayName(for: "会議", bundle: en), "Meeting")
    XCTAssertEqual(PresetTag.displayName(for: "会議", bundle: try bundle("de")), "Meeting")
    XCTAssertEqual(PresetTag.displayName(for: "日記", bundle: try bundle("de")), "Tagebuch")
  }

  func testDisplayName_Japanese_ReturnsStoredValue() throws {
    let ja = try bundle("ja")
    for tag in PresetTag.storedValues {
      XCTAssertEqual(PresetTag.displayName(for: tag, bundle: ja), tag)
    }
  }

  func testDisplayName_CustomTag_IsReturnedAsIs() throws {
    XCTAssertEqual(PresetTag.displayName(for: "旅行", bundle: try bundle("en")), "旅行")
    XCTAssertEqual(PresetTag.displayName(for: "My Tag", bundle: try bundle("de")), "My Tag")
  }

  // MARK: - Notification title

  func testNotificationTitle_PrefersLocalizedDisplayName() {
    let title = NotificationScheduler.displayName(
      localizedInfo: ["CFBundleDisplayName": "Diktiergerät"],
      info: ["CFBundleDisplayName": "シンプル録音", "CFBundleName": "VoiLog"]
    )
    XCTAssertEqual(title, "Diktiergerät")
  }

  func testNotificationTitle_FallsBackToInfoPlistThenBundleName() {
    XCTAssertEqual(
      NotificationScheduler.displayName(localizedInfo: nil, info: ["CFBundleDisplayName": "シンプル録音"]),
      "シンプル録音"
    )
    XCTAssertEqual(NotificationScheduler.displayName(localizedInfo: nil, info: ["CFBundleName": "VoiLog"]), "VoiLog")
    XCTAssertEqual(NotificationScheduler.displayName(localizedInfo: nil, info: nil), "VoiLog")
  }
}
