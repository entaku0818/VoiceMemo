# AI送信同意：1.17.0再提出準備

対象: Submission `3fd60d24-b6db-4c19-ad35-5004382c7e64`、2026-10-16、iPad Air 11-inch (M3)、1.17.0 (24)、5.1.1(i) / 5.1.2(i)。作業ブランチは `fix/ai-consent`。作業開始時の未追跡ファイル `docs/monetization_proposal_2026-10-11.md` は変更していない。

## 原因とビルド24の証拠

Appleの指摘は送信データ・送信先・事前許可の説明不足。レビュー担当者が実際に通った経路までは不明。コードから確認できた不備は以下。

- ショートカット `LatestRecordingTranscriptionRunner` は既存同意を確認せず認証・音声アップロードを実行していた。
- 音声と議事録で `ai_data_sharing_consent_v1` を共用。片方の説明への許可で、別のデータ・目的の送信も許可されていた。
- 「氏名・メールアドレスを送信しない」は音声・テキスト中の個人情報について不正確。「作成のためだけに使う」も提供者の安全性・不正利用対策等を含まない。
- 議事録の事前の端末AI可用性判定と実行時判定の間で状態が変わると、同意を確認せずクラウドへ進む余地があった。

Gitでは同意実装 `3bec9746` / `4ae3842f` がビルド24更新 `1fb13efd` の祖先。`build/VoiLog.xcarchive` は2026-10-15 14:28:54 UTC作成、1.17.0 (24)。その実行バイナリに旧同意キー・同意画面型名・許可アクションを検出。`build/export/DistributionSummary.plist` も24を記録する。従って**ローカルの24アーカイブには既存修正が含まれる**。ただしアップロード受領証やApple側バイナリとのハッシュ照合はなく、審査されたバイナリとの完全一致は断定しない。

機械可読の記録（バイナリSHA-256を含む）: [build24-and-provider.json](ai-consent-evidence/build24-and-provider.json)。既存アーカイブは上書きしない。今回のビルド番号は25（アップロード前にASC上で未使用か確認）。

## 調査した送信経路

| 入口 | データ・目的 | 実際の経路 | 修正後のゲート |
|---|---|---|---|
| 一覧／詳細のAI文字起こし、再実行 | 録音音声、言語。全文・話者区別・要約 | Firebase匿名認証 → Cloud Run `/upload-url` → Google Cloud Storage PUT → Cloud Run `/transcribe` → Google Gemini Files / GenerateContent | 音声用v2同意。認証前のReducerチェック＋全API入口で再チェック |
| 最新録音の文字起こしショートカット | 同上 | 同上 | 音声用v2同意なしなら認証前に終了し、アプリ内の確認を案内 |
| クラウド議事録 | 文字起こしテキスト、言語。要約・TODO | Firebase匿名認証 → Cloud Run `/minutes` → Google Gemini GenerateContent | テキスト用v2同意。フォールバック実行時にも検証 |
| 端末内議事録 | テキストから要約・TODO | Apple Foundation Models（端末内） | 外部送信なし。利用可否の変化でクラウドへ進んでも未同意なら停止 |
| Apple音声認識 | 音声から文字起こし | Apple Speech framework。既存OS権限の対象（Geminiとは別） | `SpeechRecognizer` は `.authorized` を検証。Apple音声認識は必ず端末内とは限らないことをポリシーに明記 |

送信内容に氏名・連絡先等が含まれれば、それも送信される。匿名UIDは認証・利用制限とStorageオブジェクト名に使用。Gemini生成リクエストにUIDや広告IDを別フィールドとして追加する実装はない。

確認根拠: `TranscriptionFeature.swift`、`MeetingMinutesFeature.swift`、`VoiceMemoAppIntents.swift`、`server/transcription/main.go`。サーバーは `BackendGeminiAPI` を指定しており、OpenAI/AnthropicやVertex AIと推測して記載していない。本番Cloud Runのモデル設定は `gemini-3.1-flash-lite`。モデル名は変更可能なためユーザー向け説明ではサービス名Gemini APIを使用。

## 変更

- `AIDataSharingConsent.swift`: データ・Google Cloud / Gemini・目的・個人情報の包含・今後の利用への適用・設定での取消を説明。許可/拒否を維持し、用途別v2キーで旧同意を無効化。
- `TranscriptionFeature.swift` / `MeetingMinutesFeature.swift`: 用途別同意、表示していない画面からの許可アクション無効化、通信クライアントとクラウドフォールバックで防御。
- `VoiceMemoAppIntents.swift`: 未同意ショートカットで認証・送信を開始しない。
- `SettingView.swift`: 今後の送信許可をリセット。送信済みデータの回収・処理取消ではない。
- `Transcription.xcstrings`: 新説明・エラー・許可リセットを日英＋既存の主要10言語（de/es/fr/it/pt-PT/ru/tr/vi/zh-Hans/zh-Hant）に翻訳。その他のロケールは英語フォールバック。既存45言語の見出し・許可/拒否等は保持。
- `MeetingMinutesView.swift` / `TranscriptionTabsView.swift`: 操作テスト用アクセシビリティID。
- `VoiceMemoApp.swift` / `DebugMode/AIConsentUITestFixture.swift`: Debug限定で本番のTranscriptionTabsViewに合成データ・モック通信を渡すUIテスト入口。Releaseにモック経路は含めない。
- テスト: `AIDataSharingConsentTests.swift`、`TranscriptionFeatureTests.swift`、`MeetingMinutesFeatureTests.swift`、`MeetingMinutesClientTests.swift`、`VoiceMemoAppIntentsTests.swift`、`SettingRecoveryFeatureTests.swift`、`AIConsentUITests.swift`。
- `project.pbxproj`: ビルド25。UIテストの旧 `TEST_TARGET_NAME = VoiceMemo` を実際の `VoiLog` に修正。CrashlyticsのdSYM送信を実機Release限定にし、Simulatorでは送信しない。
- 日英リリースノート、App Review Information、ポリシー、英語返信案。

## ポリシー・提供者の確認

公開中ページは旧説明のまま（[取得時の保存](ai-consent-evidence/published-policy-before.html)）。[変更案](../lp/privacy_policy.html)は未公開。

実本番キーを表示・ファイル保存せず所属情報だけ照合し、プロジェクト番号 `950571144078`（`voilog`）の `billingEnabled: true` を確認。Googleの[Gemini API有料条件](https://ai.google.dev/gemini-api/terms)と[データ処理条項](https://business.safety.google/processorterms/)を参照し、目的制限・保護条件と安全性等のログ処理を区別した。アプリの有料会員かどうかと、API提供者側の有料条件は別。

本番Storageの削除条件は `age: 1`、soft deleteは604800秒。サーバーは転送後のStorage削除と処理後のGeminiファイル削除を要求する。ライフサイクル削除は非同期なので旧説明の「1日以内に必ず削除」は改めた（[Google Cloud仕様](https://docs.cloud.google.com/storage/docs/lifecycle)）。結果を端末だけに保存すると断定せず、別途使用するiCloud・バックアップ・共有も区別。運用ログ・Slack障害通知も説明。

共有先に同等以上の保護を求める方針を明記。運営者は公開前にこの方針を確認し、今後もAPIキーの請求状態・利用規約変更に追随すること。

## 検証

最終結果は本ファイル末尾に記載。

- Simulator: iPad Air 11-inch (M3)、iOS 27.0。Appleが審査した実機・OSと同一とは主張しない。
- 初回の `simctl` 接続失敗はサンドボックスによるCoreSimulatorサービス・ログへのアクセス制限。権限を付けて再実行すると利用可能。ランタイム故障ではなかった。
- 既存UIテストは古い対象アプリ名により `UITargetAppPath should be provided` でスキップされていた。修正後、2言語のUIテストが実行され通過。
- UI: 実際の文字起こし・議事録タブと同意シートを使用。音声許可後にも議事録の別同意が必要、両方で拒否→再表示→許可→モック結果表示を検証。個人の実録音や外部AIサービスへ送信していない。
- ネットワーク遮断: 未同意/旧同意/別用途の同意・拒否・遅延した許可アクション・ショートカット・可用性変更によるクラウド経路・ライブAPI入口を回帰テスト。
- iPad実機、実クラウド生成、App Store配布署名アーカイブは今回の検証対象外。自動テスト用モックと実サービスの生成結果を混同しない。

## 公開・再提出前の残作業

1. `lp/privacy_policy.html` を運営者が確認し、改定日の「改定案（公開前）」を公開表記に変更して `https://voilog.web.app/privacy_policy.html` に公開。今回の依頼では外部公開しない。現リポジトリの `firebase.json` にはHosting設定がないので、既存の実際の公開手順・配信元を確認して行う。
2. ASC上でビルド25が未使用か確認して署名付きアーカイブ・アップロード。提出バイナリに用途別v2キー・同意画面が入っていることを再確認。
3. 公開ページの差替えを確認し、必要ならApp Privacy申告とAPI利用条件の整合を最終確認。
4. [英語返信案](ai-consent-apple-reply-en.txt)を未実施事項に合わせて確定し、[App Review Information案](../fastlane/metadata/review_information/notes.txt)を登録。Premiumのレビューsandbox導線も確認。
5. 承認を得た後にのみAppleへの返信・再提出を実施する。今回は返信送信・提出・外部公開・git push/tagを行っていない。

33の追加ロケールの新説明は英語フォールバックであり、45ロケール全件の新訳を完了したものではない。主要12言語以外の翻訳拡充が必要なら、公開前の追加作業として扱う。

## 最終ゲート結果（2026-10-18）

| ゲート | 結果 | 根拠 |
|---|---|---|
| Debugビルド | 緑 | 最終xcodebuild testでビルド成功、1.17.0 (25) |
| 関連ユニットテスト | 緑 | 61件、失敗0 |
| iPad UI操作 | 緑 | 日英2件、失敗0。旧v1許可を与えた状態でも新画面を要求し、拒否/許可・用途分離を検証 |
| lint | 緑 | `swiftlint lint --config .swiftlint.yml --no-cache`、終了0、128 warnings / 0 serious |
| ローカライズ | 緑（範囲限定） | 新7文字列の主要12言語を検査、日英の実画面確認。追加33ロケールは英語fallback |
| 差分 | 緑 | `git diff --check`、既存未追跡ファイルを保持 |
| Releaseビルド | 緑 | `xcodebuild build` 終了0、1.17.0 (25)。両用途のv2同意キーをバイナリ内で確認、Debugモック応答は含まれない |
| 実機・実クラウド生成 | 未実施 | iPad Simulatorとモック通信を使用。実データを第三者AIへ送信していない |
| 配布署名・アップロード・公開・審査返信/提出 | 未実施 | 今回の修正・検証・準備の範囲外、明示指示に従い外部変更なし |

最終テスト: `/private/tmp/voilog-ai-consent-final-tests.log`、xcresult: `/private/tmp/voilog-ai-consent/Logs/Test/Test-VoiLog-2026.10.18_00-29-12-+0900.xcresult`。
lint: `/private/tmp/voilog-ai-consent-lint-final.log`。Release: `/private/tmp/voilog-ai-consent-release.log`。

画面証拠: [日本語・音声](ai-consent-evidence/iPad-ja-audio-consent.png)、[日本語・議事録](ai-consent-evidence/iPad-ja-minutes-consent.png)、[英語・音声](ai-consent-evidence/iPad-en-audio-consent.png)、[英語・議事録](ai-consent-evidence/iPad-en-minutes-consent.png)。


再現コマンド（既存iPad Simulatorを使用、署名・外部AI送信不要）:

```sh
xcodebuild build -project ios/VoiLog.xcodeproj -scheme VoiLog -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/voilog-ai-consent-release \
  -clonedSourcePackagesDirPath /private/tmp/voilog-ai-consent/SourcePackages \
  CODE_SIGNING_ALLOWED=NO

xcodebuild test -project ios/VoiLog.xcodeproj -scheme VoiLog -configuration Debug \
  -destination 'platform=iOS Simulator,name=AIConsent-iPad-Air-M3' \
  -derivedDataPath /private/tmp/voilog-ai-consent -parallel-testing-enabled NO \
  -only-testing:VoiLogTests/AIDataSharingConsentTests \
  -only-testing:VoiLogTests/TranscriptionFeatureTests \
  -only-testing:VoiLogTests/MeetingMinutesFeatureTests \
  -only-testing:VoiLogTests/MeetingMinutesCloudFallbackTests \
  -only-testing:VoiLogTests/MeetingMinutesGeneratorTests \
  -only-testing:VoiLogTests/LatestRecordingTranscriptionRunnerTests \
  -only-testing:VoiLogTests/SettingRecoveryFeatureTests \
  -only-testing:VoiLogUITests/AIConsentUITests CODE_SIGNING_ALLOWED=NO

(cd ios && swiftlint lint --config .swiftlint.yml --no-cache)
```


Releaseビルドの初回失敗は、共有SPMキャッシュを指定した際にCrashlyticsスクリプトが既定のSourcePackagesパスを参照したため。SimulatorにはdSYMアップロードが不要なので、スクリプトを実機Release限定に修正し、同じSimulatorビルドコマンドを再実行して終了0を確認した。実機配布時の既定パスでの動作は維持している。

今回の範囲（修正・関連build/test/lint・iPad Simulator操作・返信案/ポリシー案の準備）は完了。公開、配布署名アーカイブ、アップロード、審査返信送信、再提出は未実施。


## 追加依頼：main反映と再提出

2026-10-18、ユーザーからmainへのpushと審査を進める指示を受領。上記の「未公開・未提出」は準備完了時点の記録であり、この追加依頼によりポリシー公開、署名付きビルド25のアップロード、審査情報の登録・再提出へ進む。

ASC確認: 1.17.0 は `REJECTED`、version ID `1e7f49cf-1fa0-4a0d-ad43-d37fdef296d3`。最新ビルド24のIDは `c4b32e12-ad44-46e7-8eca-a37b4474b095`（2026-10-15アップロード）。25は未使用。既存の `fix/ai-consent` のHEAD `1fb13efd` は `origin/main` と同じであり、今回の追加修正をmainに反映する。

Hosting設定は `lp/firebase.json` と `lp/.firebaserc` に存在し、対象プロジェクトは `voilog`。ルートのfirebase.jsonだけを見た準備段階の記載を補足する。
