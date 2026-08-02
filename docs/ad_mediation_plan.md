# 広告メディエーション導入検討 — 調査と推奨構成

作成日: 2026-08-02 / 対象: VoiLog (iOS) + シンプル録音 (Android) / 関連 issue: #212, #151

**このドキュメントの結論を一行で**: 依頼された「メディエーションでネットワークを増やす」より先に、**すでに書かれているのに未リリースのコード（App Open広告の二重ゲートbug fix）と、未実装のATTプロンプト**の方が期待値が数倍大きい。メディエーションは**SDK不要のbidding partner（特にAd Generation / Fluct）をAdMob管理画面だけで足す**のが正解で、AppLovin MAXへの乗り換え（方針B）は現在の規模では明確に不合理。

**記法**: 【事実】= コード/公式ドキュメント/AdMob実績で確認済み。【推定】= 一般ベンチマークからの試算で、VoiLog実データでの裏取り未了。

---

## 0. 依頼時の前提のうち、調査で覆ったもの

タスク指示に書かれていた「調査済み」の前提が、作業ツリーの実態と食い違っていた。先に訂正する。

| 依頼時の前提 | 実態 | 根拠 |
|---|---|---|
| iOSは GoogleMobileAds のみ。**メディエーションアダプタは一切入っていない** | **Meta Audience Network アダプタが既に追加済み**（未コミット）。`googleads-mobile-ios-mediation-meta`（branch main）+ `fbaudiencenetwork` 6.21.1、GMA 12.14.0→13.7.0 | `ios/VoiLog.xcodeproj/project.pbxproj:972-979, 1012-1019`、`Package.resolved` |
| 広告ユニットは**3枠**（ADMOB_KEY / RECORD_ADMOB_KEY / PLAYLIST_ADMOB_KEY） | **5枠**。上記に加え `INTERSTITIAL_ADMOB_KEY`（実際はApp Open広告が使用）、`REWARDED_ADMOB_KEY` | `ios/VoiLog/Info.plist:5-24`、`ios/VoiLog/Prod.xcconfig:11-16` |
| （Android側の言及なし） | Androidにも広告あり。**しかもMetaアダプタが同じく未コミットで追加済み** | `android/simpleRecord/app/build.gradle.kts:179-180` |

つまり**方針Aは既に半分着手されていて、未コミット・未リリースのまま止まっている**。これが今回いちばん重要な発見。

---

## 1. 現状整理

### 1-1. iOS (VoiLog)

**広告フォーマットと配置** — 全4バナー + App Open + リワード。

| # | フォーマット | 画面 | 使用ユニット | 課金判定 | 実装箇所 |
|---|---|---|---|---|---|
| 1 | バナー（アダプティブ） | 録音タブ | `RECORD_ADMOB_KEY` | あり | `DebugMode/VoiceAppFeature.swift:387-389` |
| 2 | バナー（アダプティブ） | 再生タブ | `RECORD_ADMOB_KEY`（**録音枠を使い回し**） | あり | `DebugMode/VoiceAppFeature.swift:406-408` |
| 3 | バナー（アダプティブ） | プレイリストタブ | `PLAYLIST_ADMOB_KEY` | あり | `DebugMode/VoiceAppFeature.swift:433-435` |
| 4 | バナー（アダプティブ） | 設定 | `ADMOB_KEY` | あり | `Setting/SettingView.swift:259-260` |
| 5 | App Open | 起動スプラッシュ | `INTERSTITIAL_ADMOB_KEY`（名前と実体が不一致） | あり | `SplashView.swift:44-91` → `AppOpenAdManager.swift` |
| 6 | リワード | Gemini文字起こしのアンロック | `REWARDED_ADMOB_KEY` | あり | `Playback/PlaybackFeature.swift:819-834` |

- インタースティシャル・ネイティブは**未実装**（`INTERSTITIAL_ADMOB_KEY` という名前だけが残っている）。
- iOSのバナーは**すでにアダプティブ**（`AdmobBannerView.swift:20-25` の `currentOrientationAnchoredAdaptiveBanner`）。ここは改善余地なし。
- `Playlist/PlaylistListView.swift:56` と `Playlist/PlaylistDetailView.swift:309` にもバナー呼び出しがあるが、両Viewは `#Preview` からしか参照されない**デッドコード**。出荷されているのは `ModernPlaylistListView` / `EnhancedPlaylistDetailView`。

**頻度制御** — App Openのみ。`appUsageCount`（`VoiceMemoApp.swift:28-29` でコールドラウンチごとに+1）を使う。

**課金ユーザー判定** — RevenueCatのライブ問い合わせではなく `UserDefaults` の `HasPurchasedProduct` bool（`data/UserDefaultsClient.swift:114-116`）。**表示箇所は6/6すべてゲート済み**。ただし preload 側は未ゲート（`VoiceMemoApp.swift:49`、`PlaybackFeature.swift:265-268` など）で、課金ユーザーにも広告リクエストだけは飛んでいる。

### 1-2. Android (シンプル録音)

| # | フォーマット | 画面 | 課金判定 | 実装箇所 |
|---|---|---|---|---|
| 1-4 | バナー（**固定320x50、非アダプティブ**） | 録音一覧 / プレイリスト / プレイリスト詳細 / 設定 | あり | `BannerAdView.kt:25-29` ほか4画面の `bottomBar` |
| 5 | App Open | 起動時 | あり（表示のみ） | `AppOpenAdController.kt` |
| 6 | リワード | **なし（ロードのみ、表示コールサイトゼロ）** | なし | `RewardedAdController.kt:54-80` |

- **録音タブ（アプリの主画面）にバナーがない**。
- リワード広告は毎起動 `loadAd()` されるが `showAd()` の呼び出し元が存在しない。**リクエストだけ投げて1インプレッションも出していない**。
- バナーが `AdSize.BANNER` 固定サイズ。**iOSと違ってアダプティブ化されていない**。
- `adView.destroy()/pause()/resume()` のライフサイクル処理なし。
- App Open頻度: `DISPLAY_INTERVAL = 5`（5起動に1回）、有効期限4時間（`AppOpenAdController.kt:20-24`）。

### 1-3. AdMob実績（依頼時に提供された数値 + issue #212）

【事実】

| 指標 | 値 |
|---|---|
| 直近14日 収益 | ¥1,143 |
| 直近14日 インプレッション | 22,955 |
| 実効eCPM | **¥49.8**（= $0.32 @ ¥157/USD） |
| 1日あたり | ¥81.6 / 1,640 imp |
| 月換算(30日) | **¥2,449 / 49,190 imp** |
| 年換算 | ¥29,800 |
| iOSの収益シェア | **90%超**（issue #212、直近7日ベース） |
| マッチ率 | 82.66% |
| 表示率 | 73.87%（**約26%のロス**） |
| サブスクMRR | $37.68 ≒ ¥5,916/月 |

**広告は総収益の約29%**（¥2,449 / ¥8,365）。「補助」と言うにはやや大きい比率。

**eCPM ¥49.8 は日本のiOSバナー相場を大きく下回る。** 日本はiOSバナーのeCPMが世界最高水準の市場で、ベンチマークは **$1.25（≒¥196）**、レンジ $0.50〜$1.50 ([RevenueFlex 2026](https://revenueflex.com/blog/app-ad-revenue-benchmarks-2026/))。VoiLogは**ベンチマークの約1/4**。ただしこのベンチマークはゲーム中心のデータセットなので、非ゲームのユーティリティアプリがそのまま届く水準ではない。それでも乖離は大きく、**「埋まっていない」より「単価が出ていない」問題**であることを示唆する。後述するATT未実装がその主因と考えられる。

---

## 2. 調査で見つかった、メディエーション以前の問題

依頼のスコープ外だが、**メディエーションより期待値が大きい**ので先に出す。

### 2-1. 🔴 App Open広告の二重ゲートで、意図の1/5しか表示されていない（iOS・本番稼働中）

【事実】main (v1.12.1、本番) のコード:

- `SplashView.swift:54` … `appUsageCount % 3 == 0` （ハードコード）
- `AppOpenAdManager.swift:24, 96` … `appUsageCount % displayInterval == 0`、`displayInterval = 5`

両方を通過する必要があるため、実際に表示されるのは **`appUsageCount % 15 == 0`、つまり15起動に1回**。設計意図は5起動に1回。

作業ツリーの未コミット修正（`displayInterval = 3` + SplashViewがマネージャの値を読む）で **3起動に1回 = 現状比5倍** になる。テストも `ios/VoiLogTests/AppOpenAdManagerTests.swift`（未追跡）に書かれている。

App Openは全フォーマット中もっともeCPMが高い部類。**この修正が未リリースであること自体が、eCPM ¥49.8 という低い実効単価の有力な説明になる**（高単価フォーマットがほぼ死んでいて、収益が低単価バナーで構成されている）。

> ⚠️ 注意: 15回に1回 → 3回に1回は**体感5倍**の変化。リテンションとレビュー評価への影響があり得る。まず5回に1回（設計意図どおり）で出して、数値を見てから3回に1回を検討する方が安全。

### 2-2. 🔴 ATT（App Tracking Transparency）プロンプトを一度も出していない（iOS）

【事実】`ATTrackingManager` / `AppTrackingTransparency` / `requestTrackingAuthorization` はリポジトリ全体で**ヒットゼロ**。`INFOPLIST_KEY_NSUserTrackingUsageDescription` は `project.pbxproj:747, 801` に設定済みなので、**プロンプトを出す準備だけできていて、実際には一度も出していない**。

結果、IDFA取得率は実質0%。全iOSインプレッションが非パーソナライズ扱いで配信されている。

- ATTオプトイン率の業界水準は **25〜27%** ([Playwire](https://www.playwire.com/blog/mastering-idfa-opt-in-rates-the-complete-apptrackingtransparency-guide-for-ios-apps), [adlibrary 2026](https://adlibrary.com/posts/ios-14-att))
- IDFA不可トラフィックのeCPMは可のトラフィックより **37〜42%低い** ([InMobi](https://advertising.inmobi.com/blog/att-and-ios-14.5-impact-analysis-initial-insights/inmobi-exchange-ios-14-and-idfa-what-you-should-know))

### 2-3. 🔴 Metaに嘘のトラッキング同意シグナルを送っている（iOS・未リリース）

【事実】作業ツリーの `VoiceMemoApp.swift:44-46`:

```swift
// GDPR同意管理(UMP)未導入のため暫定値。導入後は実際の同意状態を渡すこと（issue #212）
FBAdSettings.setAdvertiserTrackingEnabled(true)
```

ATTの許諾を一度も取っていない状態で `advertiserTrackingEnabled = true` を固定値で渡している。Metaはこの値がATTの実際の許諾状態を反映することを要求しており、**Audience Networkのアカウント停止リスクがある**。UMPもiOS/Androidとも未導入（Androidは `com.google.android.ump` 依存すら無し）。

**このままリリースしてはいけない。** ATT実装（2-2）とセットでないとMetaアダプタは出せない。

### 2-4. 🟡 Androidのバナーが非アダプティブ

【事実】`BannerAdView.kt:25-29` は `AdSize.BANNER`（320x50固定）。

アダプティブアンカーバナーへの差し替えは事実上ドロップイン。日本の家計簿アプリ Zaim の公式事例で **Android +48% / iOS +27% eCPM** ([Google AdMob](https://admob.google.com/home/resources/zaim-boosts-ecpm-up-to-forty-eight-percent-admob-adaptive-banners/))。一般的なレンジは +15〜25%、大きい事例で +200%。

### 2-5. 🟡 Androidのリワード広告が「ロードするだけで一度も表示されない」

【事実】`RewardedAdController.showAd()`（`RewardedAdController.kt:54-80`）の呼び出し元がゼロ。文言リソース `rewarded_ad_watch` / `rewarded_ad_reward_earned` もKotlinから未参照。毎起動リクエストだけ発生 → **フィルレート統計を汚し、収益はゼロ**。

iOS同等の「リワード視聴で文字起こしアンロック」を実装するか、ロード呼び出しを削除するかの二択。

### 2-6. 🟠 リポジトリ衛生（メディエーションとは別件だが実害あり）

| 項目 | 内容 |
|---|---|
| `android/.../res/xml/gma_ad_services_config.xml` が**未追跡** | ローカルとリリースで**挙動が食い違う**。`AndroidManifest.xml:42-45` が `@xml/gma_ad_services_config` を参照しているが、この名前のリソースは play-services-ads の AAR にデフォルトが同梱されているため**ビルドは通る**（クリーンworktreeで `assembleDebug` 成功を確認済み）。問題は、ローカルの未追跡ファイルが `ad_services_enabled=false` でそれを上書きしている点。**手元では Privacy Sandbox Ad Services が無効、CI/リリースビルドでは AAR デフォルト（有効）** になる。追跡するか削除するかを決めて、両者を一致させる必要がある |
| `ios/VoiLog/Prod.xcconfig` が**git追跡下で本番ユニットIDが平文** | `git ls-files` に載っている。gitignoreされていない |
| Metaアダプタが `branch = main` ピン | `project.pbxproj:972-979`。バージョン固定でないため再現性なし。タグ指定にすべき |
| SKAdNetworkリスト未更新 | `Info.plist` に50件（AdMob標準リストのみ）。Metaアダプタを足したのに Meta のパートナーIDリストを追加していない |
| `setHasPurchasedProduct(false)` の呼び出しがゼロ | 解約・返金後も広告が二度と出ない（収益漏れ） |
| Android: `app-keys/admob.properties` 不在時に**Googleのテストユニットへ黙ってフォールバック** | `build.gradle.kts:59-62`。警告もビルド失敗もなし |

---

## 3. 方針A / 方針B の比較

| 評価軸 | **A: AdMobメディエーションに他社アダプタを追加** | **B: AppLovin MAX等へ乗り換え（AdMobをぶら下げる）** |
|---|---|---|
| **日本のiOSでの実績eCPM** | AdMobは**バナーとApp Openに強い**とされる。VoiLogの在庫はバナー4枠 + App Openが中心なので**主体をAdMobに置くのが素直** | MAXの優位は主にフルスクリーン系（インタースティシャル/リワード）。**VoiLogにはその在庫がほぼ無い**（リワードは無料ユーザー生涯3回上限）([TrustRadius](https://www.trustradius.com/compare-products/applovin-max-vs-google-admob), [Teqblaze](https://teqblaze.com/blog/mobile-app-monetization-for-publishers)) |
| **App Open在庫への効果** | **サードパーティSDKありの広告ソースは App Open を1社も対応していない**【事実・公式表で確認】。SDK不要のbidding枠では **Ad Generation が App Open 対応**（後述） | 同上。MAXもApp Openのサードパーティ需要は薄い |
| **ATT環境での埋まり具合** | 現状マッチ率82.66% → 上限100%なので**フィル改善の理論上限は+21%**。ここは大きな伸びしろではない | 同じ制約。乗り換えてもフィル上限は変わらない |
| **アプリサイズ / 起動時間** | SDK不要のbidding partnerなら**増加ゼロ**。SDKアダプタは1社あたり数MB + 初期化コスト | MAX SDK本体 + 各アダプタで**最大の増加**。既存GMA SDKも残すので二重 |
| **審査リスク** | 低。ただしATT未実装のままMetaを出すのは**Meta側のポリシー違反リスク**（§2-3）。SDK追加時はApple の privacy manifest + signature 要件に適合したアダプタバージョンが必須（GMA 11.2.0+ が対応、現在13.7.0なのでOK）([Apple](https://developer.apple.com/news/?id=3d8a9yyh)) | 中。SDK数が増えるほど privacy manifest / SKAdNetwork / データ開示の管理対象が増える |
| **実装工数** | SDK不要枠: **コード0行・リリース0回**（管理画面のみ）。SDKアダプタ: 2025年9月からSPM対応済み([Google Ads Developer Blog](https://ads-developers.googleblog.com/2025/09/google-mobile-ads-mediation-adapters.html))なので1社あたり iOS+Android で概ね2〜4時間 + リリース1回 | **全画面の広告呼び出しコードを書き換え**。iOS/Android両方。加えて**60〜90日の学習期間があり、その間は収益が下がる可能性がある**([Segwise](https://segwise.ai/blog/applovin-publisher-monetization-guide)) |
| **本人作業量** | SDK不要枠: AdMob管理画面でメディエーショングループ作成のみ。SDKアダプタ: 各社アカウント開設 + 税務 + 支払情報 | MAXアカウント審査 + 各ネットワークのアカウント + AdMobをMAX配下に登録し直し + 全ユニットの再マッピング |
| **規模適合性** | 制約なし | **AppLovin公式ガイドの推奨水準は 100K+ DAU。50K DAU未満は「データ点が足りない」**とされ、運用に 0.5〜1 FTE 相当を想定([Segwise](https://segwise.ai/blog/applovin-publisher-monetization-guide)) |
| **支払い** | bidding収益は**大半がAdMob経由で一本化**して支払われる。一部「direct pay」ソースのみ個別([AdMob Help](https://support.google.com/admob/answer/9360574?hl=en)) | 各ネットワークから個別入金。AppLovinは**$100の最低支払額**、Mintegralは銀行送金$300 / PayPal$50 |

### 方針Bを推奨しない決定的な理由

VoiLogの規模は **1,640 imp/日**。1ユーザー1日3インプレッションと仮定しても**DAUは数百規模**で、AppLovin MAXの推奨水準（100K+ DAU）の **1/100〜1/500**。

加えて低volume時の一般的推奨は「**50K DAU未満はネットワーク3社のwaterfallに留め、ARPDAUではなくリテンションを見る**」というもの。MAXの強みであるリアルタイムオークションの学習が回らない規模で、乗り換えコスト（全画面の実装変更 + 60〜90日の収益ディップ）だけを払うことになる。

さらに、仮にAppLovinが月の広告収益の15%（≒¥367）を持っていったとして、**$100 = ¥15,700 の最低支払額に達するまで約43ヶ月**。実質的に入金されない。

**方針B は却下。方針A を採用する。ただし後述のとおり順序を変える。**

---

## 4. 追加候補ネットワークの推奨順

日本での配信実績とVoiLogの在庫構成（バナー中心 + App Open、非ゲーム、日本ユーザー中心）で絞った。

### 第1優先: SDK不要のbidding partner（コード変更ゼロ・アプリ更新不要）

【事実】AdMob公式の広告ソース一覧で「No third-party SDKs required / Bidding only」に分類される枠。**アプリの更新もSDK追加も不要で、AdMob管理画面の設定だけで有効化できる。**

| ネットワーク | 地域 | 対応フォーマット | VoiLogへの適合 |
|---|---|---|---|
| **Ad Generation**（Supership） | 日本最大級のSSP | **App Open, Banner, Interstitial, Rewarded, Rewarded Interstitial, Native** | ★★★ **唯一 App Open に対応する追加需要源**。日本の需要。最優先 |
| **Fluct** | APAC / NA | Banner, Interstitial, Rewarded, Native | ★★★ 日本のSSP。バナー需要 |
| **YieldOne**（Platform One） | APAC | 全フォーマット | ★★☆ 日本のSSP |
| **Index Exchange / PubMatic / Magnite / OpenX / Sharethrough / Equativ / TripleLift** | グローバル | Banner中心 | ★★☆ 単価競争の頭数として。ゼロコストなので入れて損はない |

**この層だけで、コード0行・リリース0回・アプリサイズ増加0・審査リスク0。** 支払いもAdMob経由に一本化される。**やらない理由が無い。**

### 第2優先: 日本特化のSDKアダプタ

| ネットワーク | 状況 | 判断 |
|---|---|---|
| **LY Ads Network**（LINEヤフー） | AdMob bidding partner一覧に「LINE / JP」で掲載。Banner・Interstitial・Rewarded・Native | 日本の非ゲームアプリと相性が良い可能性。第1優先層の結果を見てから |
| **i-mobile / maio / Zucks** | AdMobのアダプタ一覧で「Japan-only」扱い | 日本特化。ただし個別アカウント・税務が必要 |

### 第3優先: 既に着手済みの Meta Audience Network

**iOS/Androidとも実装済み（未コミット）。** ただし:

- 2026年にMetaのiOS収益が急伸したのは **リワード動画とインタースティシャルのみで、バナーは横ばい** ([Gamesforum](https://www.globalgamesforum.com/features/is-meta-back-on-ios-the-data-is-here), [GameBiz Consulting](https://www.gamebizconsulting.com/newsletter/admon-newsletter-8-meta-is-back-on-ios))
- VoiLogの在庫はバナー中心。リワードは生涯3回上限で volume が小さい。**App Openは Meta 非対応**
- → **Metaからの上乗せは限定的**と見るべき
- リリース前に §2-3（ATT）の解決が必須

### 非推奨: Unity Ads / Pangle / Mintegral

いずれもAdMobのbidding partnerではあるが、**広告主基盤がゲーム（アプリインストール広告）に強く偏っている**。日本の非ゲーム・ユーティリティアプリのバナー在庫に対して良い単価が出る根拠が見つからなかった。加えて個別のアカウント・税務・支払情報の管理コストと最低支払額（Mintegral: 銀行送金$300）が、想定される上乗せ額に対して過大。

【推定】この判断は「ゲーム偏重」という定性情報に基づくもので、VoiLog実データでのA/Bはしていない。第1・第2優先を試して物足りなければ再検討の余地はある。

---

## 5. 推奨構成と理由

```
AdMob を主体のまま維持
  ├─ Google AdMob Network              （現状のまま）
  ├─ SDK不要 bidding partner 群         ← 【今回やる】コード0行
  │    Ad Generation ★App Open対応
  │    Fluct / YieldOne
  │    Index Exchange / PubMatic / Magnite / OpenX / Sharethrough
  ├─ Meta Audience Network             ← 実装済み。ATT対応後にリリース
  └─ （効果が出れば）LY Ads Network / AppLovin
```

**理由:**

1. **VoiLogの在庫の主力（バナー・App Open）はAdMobが得意な領域**で、乗り換える動機がない。
2. **App Openはサードパーティ需要がほぼ存在しない**。SDKアダプタを何社足してもApp Open在庫は1円も増えない。唯一の例外がAd Generation（SDK不要）。
3. **フィル改善の理論上限が+21%**（マッチ率82.66%）しかなく、「埋まらない」問題ではない。単価の問題。単価は §2-2 のATTの方が効く。
4. **SDK不要層はコスト実質ゼロ**なので、費用対効果の議論が不要。まずこれを入れ、効果を測ってからSDKアダプタの判断をする。

---

## 6. 期待効果の見積もり

ベース: 広告収益 **¥2,449/月**（iOS ≒¥2,204 / Android ≒¥245、issue #212の「iOS 90%超」による）。

### Tier 0 — 既に書かれている / SDK追加不要（最優先）

| 施策 | 月次上乗せ【推定】 | 根拠 |
|---|---|---|
| App Open二重ゲート修正（未リリース分） | **+¥400 〜 +¥1,500** | 表示機会が15起動に1回 → 5または3起動に1回（3〜5倍）。App Openは高eCPMフォーマット。現状の寄与額が不明なためレンジが広い |
| ATTプロンプト実装 | **+¥300 〜 +¥450** | iOS ¥2,204 に対し、オプトイン26% × 非同意時eCPM -40% ⇒ ブレンドで約+17% |
| Androidバナーのアダプティブ化 | **+¥70 〜 +¥120** | Android ¥245 に対し Zaim事例 +48%（日本のAndroidアプリ実績） |
| 小計 | **+¥770 〜 +¥2,070 / 月** | **年 +¥9,200 〜 +¥24,800** |

### Tier 1 — SDK不要 bidding partner（今回の本題・コード0行）

| 施策 | 月次上乗せ【推定】 | 根拠 |
|---|---|---|
| フィル改善（82.66% → 90〜95%） | +¥220 〜 +¥370 | インプレッション +9〜15% |
| 単価競争によるeCPM上昇 | +¥120 〜 +¥370 | +5〜15%。低volumeでは学習が効きにくいので保守的に |
| 小計 | **+¥340 〜 +¥740 / 月** | **年 +¥4,100 〜 +¥8,900** |

### Tier 2 — SDKアダプタ（Meta / LY Ads / AppLovin）

| 施策 | 月次上乗せ【推定】 | 根拠 |
|---|---|---|
| Meta（実装済み分） | +¥0 〜 +¥150 | バナー中心の在庫に対しMetaのiOSバナーは横ばいとの報告 |
| LY Ads / AppLovin 追加 | +¥150 〜 +¥400 | Tier 1で頭数が揃った後の限界的な上乗せ |
| 小計 | **+¥150 〜 +¥550 / 月** | **年 +¥1,800 〜 +¥6,600** |

### 合計と工数の突き合わせ

| | 月次上乗せ | 年間 | 追加工数 | 本人作業 | 円/時間【推定】 |
|---|---|---|---|---|---|
| Tier 0 | +¥770〜2,070 | +¥9,200〜24,800 | **2〜4h**（大半が実装済み） | ほぼ無し | **¥2,300〜12,400/h** |
| Tier 1 | +¥340〜740 | +¥4,100〜8,900 | **0h**（管理画面のみ） | 30分〜1h | **¥4,100〜17,800/h** |
| Tier 2 | +¥150〜550 | +¥1,800〜6,600 | 6〜12h + リリース | 各社アカウント3〜5h | **¥100〜730/h** |
| 方針B（MAX乗り換え） | 不明・**短期はマイナス** | — | 30h+ | 10h+ | **明確に赤字** |

### 「割に合うのか」への正直な回答

- **Tier 0 と Tier 1 は明確に割に合う。** Tier 1 に至っては**コードを1行も書かずに年間4,000〜9,000円**。Tier 0 は**すでに書き終わっているコードをリリースしていないだけ**で、時間単価は最も高い。
- **Tier 2（SDKアダプタの新規追加）は割に合わない。** 年間2,000〜7,000円のために、1社ごとにアカウント開設・税務書類・支払情報・SKAdNetwork ID追加・privacy manifest確認・アプリ更新1回、さらに恒久的な管理対象が増える。**時間単価は数百円**。ただし **Metaはすでに実装済みなので、ATT対応さえ済めば「捨てるよりリリースした方が得」**。
- **方針B（MAX乗り換え）は論外。** 規模が2桁足りない。
- そして全体として: **広告全体を仮に1.5倍にできても月+¥1,200程度。同じ労力をサブスク転換率に向けた方が期待値は大きい**（MRR $37.68 に対し、課金ユーザーが数人増えるだけで同額に届く）。広告は「取りこぼしを拾う」対象であって、成長ドライバーとして投資する対象ではない、というのが数字から見た結論。

### 見積もりの前提と弱点（正直に）

- **最大の不確実性は、App Open / バナー / リワードの収益内訳が分かっていないこと。** 依頼で提供されたのは合算値のみ。§8-1 のとおり、AdMob管理画面の広告ユニット別レポートを取れば Tier 0 の見積もりレンジは大幅に狭められる。**着手前にこれを取るのが最も費用対効果が高い**。
- 為替は ¥157/USD で計算（2026年8月時点）。
- eCPMベンチマーク（日本iOSバナー $1.25）はゲーム中心のデータセット。非ゲームのユーティリティアプリはこれより低いのが通常なので、「ベンチマークまで戻る」前提の試算はしていない。
- ATTの +17% は業界平均のオプトイン率と非同意eCPM差からの単純計算。VoiLogのユーザー層（日本・実用アプリ）でのオプトイン率は未検証。

---

## 7. 実装ステップ

### Phase 0: 計測基盤（着手前・30分・本人作業）

0-1. AdMob管理画面で**広告ユニット別**の直近30日レポート（収益/インプレッション/eCPM/マッチ率/表示率）を取得。5ユニット + iOS/Android別。
0-2. その数字を issue #212 に貼る。以降の見積もりの基準線にする。

### Phase 1: 既存の取りこぼし回収（コード・SDK追加なし）

1-1. 未コミットのiOS変更を整理してPR化。**ただし `displayInterval` はまず `5`（設計意図どおり）に。** 3への変更はリテンション影響を見てから別PR。
   - `AppOpenAdManager.swift` / `SplashView.swift` / `AdDebugView.swift`
   - `VoiLogTests/AppOpenAdManagerTests.swift` を `git add`
   - **Meta関連（`project.pbxproj` / `Package.resolved` / `VoiceMemoApp.swift` の `FBAdSettings`）はこのPRに含めない** — Phase 3へ切り出す
1-2. `android/.../res/xml/gma_ad_services_config.xml` の扱いを決める（ローカルとリリースで Privacy Sandbox Ad Services の有効/無効が食い違っている。追跡するか削除するか）
1-3. Androidバナーを `AdSize.BANNER` → アダプティブアンカーバナーに変更（`BannerAdView.kt`）
1-4. Androidの `RewardedAdController.loadAd()` 呼び出しを削除（表示先が無いため）。iOS同等のリワード導線は別issueに切り出す
1-5. iOS/Androidとも、課金ユーザーに対する preload をゲート
1-6. リリース（iOS v1.12.2 / Android 2.8.1）
1-7. **リリース+7日で AdMob 数値を確認**

### Phase 2: SDK不要 bidding partner の追加（コード変更なし・本人作業のみ）

2-1. AdMob管理画面 → メディエーション → メディエーショングループを作成
   - フォーマット別に: App Open / バナー / リワード
   - iOS・Android それぞれ
2-2. bidding広告ソースとして **Ad Generation, Fluct, YieldOne, Index Exchange, PubMatic, Magnite, OpenX, Sharethrough** を追加
   - **App Openグループには Ad Generation を必ず入れる**（唯一の対応ソース）
2-3. eCPM floor は初回は設定しない（低volumeで絞ると機会損失になるため）
2-4. **設定から14日後に効果測定**。Phase 0 の基準線と比較

### Phase 3: ATT + 同意管理 → Meta のリリース（Phase 1・2の結果を見て判断）

3-1. `AppTrackingTransparency` を導入し、適切なタイミング（オンボーディング後、初回録音完了後など）で `requestTrackingAuthorization` を呼ぶ
3-2. UMP (User Messaging Platform) を導入し、EEA/UK向けの同意フォームを表示（iOS/Android両方）
3-3. `FBAdSettings.setAdvertiserTrackingEnabled()` に**実際のATTステータス**を渡す。Android側にも同意シグナルを配線
3-4. Meta の SKAdNetwork ID を `Info.plist` に追加
3-5. Metaアダプタのピンを `branch = main` → **バージョンタグ**に変更
3-6. リリース → 7日後に効果測定
3-7. issue #212 をクローズ、または残タスクを再定義

### Phase 4: 追加SDKアダプタ（Phase 2・3の実測次第。デフォルトは「やらない」）

Phase 2 で有意な上乗せが確認できた場合に限り、LY Ads Network → AppLovin の順で検討。**Phase 2 の効果が月¥300未満なら、ここで打ち止めにするのが合理的。**

---

## 8. 本人（entaku）がやらないといけない作業

エンジニア作業では代替できないもの。

### 必須（Phase 0-2、合計 1〜1.5時間程度）

- [ ] **AdMob管理画面: 広告ユニット別レポートの取得**（直近30日、5ユニット × iOS/Android）→ issue #212 に貼る
- [ ] **AdMob管理画面: メディエーショングループの作成**（App Open / バナー / リワード × iOS / Android）
- [ ] **AdMob管理画面: SDK不要 bidding partner の有効化**（Ad Generation, Fluct, YieldOne, Index Exchange, PubMatic, Magnite, OpenX, Sharethrough）
  - ※ 各ソースの利用規約への同意が発生する場合あり
  - ※ 「direct pay」と表示されるソースがあれば、そのソースだけ別途アカウント・支払情報が必要になる。**面倒なら direct pay のソースはスキップして構わない**
- [ ] **AdMobのアプリ承認ステータスの確認**（未承認だとbiddingソースが有効化できない）

### Phase 3 の前に判断が必要（製品判断・エンジニアが決められない）

- [ ] **ATTプロンプトをどこで出すか**。初回起動時に出すと許諾率が下がる。「オンボーディング完了後」「初回録音の保存後」などの候補から選ぶ必要がある。**ここは仕様の分かれ道なので指示がほしい**
- [ ] **App Open広告の表示頻度**。現状は実質15起動に1回。設計意図の5回に1回に戻すか、未コミット変更どおり3回に1回まで攻めるか。収益とリテンションのトレードオフ
- [ ] **Metaアダプタをリリースするかどうか**。期待上乗せは月¥0〜150程度。ATT/UMP実装（Phase 3の工数の大半）が前提条件になるので、「ATTは広告全体のためにやる価値があるが、Metaのためだけならやらない」という整理もあり得る

### Phase 4 に進む場合のみ（現時点では不要）

- [ ] AppLovin アカウント開設 → Account > Keys から **SDK Key** と **Report Key** を取得（issue #212 に手順記載済み）
- [ ] AppLovin の税務情報・支払情報の登録（**最低支払額 $100**。現在の規模では到達まで年単位かかる見込み）
- [ ] LY Ads Network / i-mobile / maio / Zucks を使う場合、各社の媒体審査・アカウント開設・税務・支払情報
- [ ] 各社の管理画面で取得したキーを AdMob のメディエーション設定にマッピング

### 別件だが対応推奨（セキュリティ・運用）

- [ ] `ios/VoiLog/Prod.xcconfig` が git 追跡下で本番ユニットIDを平文保持している件の扱いを決める（AdMobユニットIDは秘匿情報ではないという整理も可能だが、同ファイルに `ROLLBAR_KEY` / `REVENUECAT_KEY` も入っている点は要確認）

---

## 9. 参考資料

- [AdMob bidding partners（公式一覧）](https://admob.google.com/home/bidding/bidding-partners/)
- [Choose ad sources — iOS（フォーマット別対応表・App Open対応の根拠）](https://developers.google.com/admob/ios/choose-networks)
- [AdMob Bidding FAQ（支払い経路・direct pay）](https://support.google.com/admob/answer/9360574?hl=en)
- [Google Mobile Ads Mediation adapters adopt Swift Package Manager (2025-09)](https://ads-developers.googleblog.com/2025/09/google-mobile-ads-mediation-adapters.html)
- [Zaim boosts eCPM up to 48% with AdMob adaptive banners（日本アプリの公式事例）](https://admob.google.com/home/resources/zaim-boosts-ecpm-up-to-forty-eight-percent-admob-adaptive-banners/)
- [App Ad Revenue Benchmarks 2026（日本iOSバナー $1.25）](https://revenueflex.com/blog/app-ad-revenue-benchmarks-2026/)
- [The Publisher's Guide to AppLovin（100K+ DAU推奨・60〜90日学習期間）](https://segwise.ai/blog/applovin-publisher-monetization-guide)
- [Mastering IDFA Opt-In Rates（ATTオプトイン率）](https://www.playwire.com/blog/mastering-idfa-opt-in-rates-the-complete-apptrackingtransparency-guide-for-ios-apps)
- [iOS 14 ATT: Five-Year Retrospective (2026)](https://adlibrary.com/posts/ios-14-att)
- [ATT and iOS 14.5 Impact Analysis（非同意トラフィックのeCPM -37〜42%）](https://advertising.inmobi.com/blog/att-and-ios-14.5-impact-analysis-initial-insights/inmobi-exchange-ios-14-and-idfa-what-you-should-know)
- [Is Meta Back on iOS? The Data is Here（2026年のMeta iOS: バナーは横ばい）](https://www.globalgamesforum.com/features/is-meta-back-on-ios-the-data-is-here)
- [Compare AppLovin MAX vs Google AdMob](https://www.trustradius.com/compare-products/applovin-max-vs-google-admob)
- [Apple: Privacy updates for App Store submissions](https://developer.apple.com/news/?id=3d8a9yyh)
- 社内: issue #212（AppLovin導入の事前調査・fill rate 82.66% / 表示率 73.87% の出典）、issue #151（SplashView広告ロジックのテスト不能問題）
