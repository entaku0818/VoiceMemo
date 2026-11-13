# iOS 1.17.4 (32)

## 提出内容

- 日本語・英語（米国）の ASO: タイトル、サブタイトル、キーワード、概要、プロモーション文。
- TCA 1.26.2、Firebase 12.19.3、RevenueCat 5.102.3 と対応する依存解決結果。
- XCTestDynamicOverlay から IssueReporting への呼び出し移行。
- 配信済みの録音詳細の再生操作と、既存の起動広告ロード待ち・RevenueCat同期初期化修正を維持。
- 50言語のリリースノートを1.17.4へ更新。

## ソース

- 作業場所: `/private/tmp/voilog-release-1.17.4`
- ブランチ: `codex/release-1.17.4`
- 提出ソース: `1c631331`、タグ: `v1.17.4`（GitHub push済み）
- ベース: `7b62b7bd`（録音詳細の再生操作）
- 元ワークスペースのAndroid・スクリーンショット制作の作業中変更は含めない。
- 旧リリースの専用一時ディレクトリ・コミットは残っていないため、現在の追跡済みコードとリリース記録、既存修正の差分を確認して構成。

## ストア準備

- App ID: `6443528409`
- Version ID: `330f9186-4902-4fec-9b66-602ce95e7f86`
- 50言語のリリースノートを launchpad で反映し、読み戻し一致を確認。
- 日英ASOの名前・サブタイトルが一致し、その他のバージョン項目を維持していることもAPIで照合。
- 既存750枚のスクリーンショットを50言語で継承済み。全画像の状態 COMPLETE を確認。ローカルの制作中画像で上書きしないため再アップロードは省略。
- 公開方式は既存の AFTER_APPROVAL を維持。

## 検証・提出

- Releaseアーカイブ・App Store用IPA書き出し成功。
- SwiftLint: エラーなし（既存警告あり）。ビルド時の自動整形差分をソースに含む。
- 全336テスト: 初回332成功・2スキップ・画像生成2件が60秒制限でタイムアウト。画像生成2件を600秒制限で再実行し両方成功。最終的に334成功・2スキップ、未解決の失敗なし。
- 前回タイムアウトした MonthlyPaywallPolicyTests の初回録音テストも成功。
- IPA: `/private/tmp/voilog-1.17.4-build/export/VoiLog.ipa`
- IPA SHA-256: `a167c7cf419ea7fbeb3f00b325c88bc2ca0a9a83f4a993154a4e03db427b3d3b`
- Upload Delivery UUID: `3ac90fc1-d8c2-4da4-ac47-028221c14d87`
- 審査提出成功: 2026-11-08 17:15 JST。
- 確認状態: `WAITING_FOR_REVIEW`（バージョン・申請の両方で照合）。
- 選択ビルド: 1.17.4 (32)、Build ID `3ac90fc1-d8c2-4da4-ac47-028221c14d87`。
- Review submission ID: `2fb08ec6-1834-4999-8e03-00491a1f4d0f`。
- 承認後に自動公開（AFTER_APPROVAL）。現時点では未公開。
- [App Store Connect](https://appstoreconnect.apple.com/apps/6443528409/distribution/ios/version/inflight)
- [GitHub Release](https://github.com/entaku0818/VoiceMemo/releases/tag/v1.17.4)


ログ: `/tmp/voilog-1.17.4-{build,tests,tests-screenshots,lint,metadata,upload-release}.log`

