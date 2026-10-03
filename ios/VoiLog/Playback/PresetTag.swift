import Foundation

/// 録音に付けるプリセットタグ。
/// 保存値（Core Data の tags）は既存データとの互換のため日本語のまま固定し、表示だけ各言語に翻訳する。
enum PresetTag {
  /// 保存に使う値。並び順はタグ選択画面の表示順。
  static let storedValues = ["会議", "講義", "インタビュー", "アイデア", "日記", "練習", "議事録", "メモ"]

  /// 表示用のラベル。プリセット以外（ユーザーが付けた任意のタグ）はそのまま返す。
  static func displayName(for storedValue: String, bundle: Bundle = .main) -> String {
    switch storedValue {
    case "会議": return String(localized: "会議", table: "Tags", bundle: bundle)
    case "講義": return String(localized: "講義", table: "Tags", bundle: bundle)
    case "インタビュー": return String(localized: "インタビュー", table: "Tags", bundle: bundle)
    case "アイデア": return String(localized: "アイデア", table: "Tags", bundle: bundle)
    case "日記": return String(localized: "日記", table: "Tags", bundle: bundle)
    case "練習": return String(localized: "練習", table: "Tags", bundle: bundle)
    case "議事録": return String(localized: "議事録", table: "Tags", bundle: bundle)
    case "メモ": return String(localized: "メモ", table: "Tags", bundle: bundle)
    default: return storedValue
    }
  }
}
