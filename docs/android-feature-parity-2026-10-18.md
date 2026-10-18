# AndroidのAI同意とiOS機能差分対応（2026-10-18）

## 実装

- 音声文字起こし／テキスト議事録の同意を分離。Google Cloud、Cloud Storage、Gemini API、送信データ、目的、内容に含まれる個人情報、匿名認証、継続許可、撤回方法を表示。
- 初回・拒否後は認証もAI通信も開始しない。表示中の同意画面からだけ許可できる。4つのHTTP入口も該当する許可を検証し、認証待機中の許可撤回も送信前に再検証する。
- 設定から両許可をリセット可能。v2の目的別キーのみを使い、旧キーは認可に使わない。OSバックアップ／端末移行から同意を除外。
- 既存12言語に新しい表示文を追加。同意の追加言語はiOS側で管理している同等の説明を再利用。
- 音声編集画面に分割位置スライダーと「2つの録音に分割」を追加。元の録音は変更せず、2つのAAC/M4Aファイルを作り、DBへトランザクションで登録。失敗時は作成途中のファイルを削除。元の文字起こし・議事録は分割後の録音に流用しない。
- ホーム画面の長押しショートカットに「録音停止」「最新の録音を文字起こし」を追加。停止は稼働中の録音リスナーへ渡し、新たな録音を作らない。文字起こしは最新保存録音の画面へ進み、同じ同意処理を経由する。録音なしの場合は案内を表示。
- 録音時に自動起動されるOS音声認識には、未説明のネットワークサービスを選択する経路があったため、API 31以上の端末内認識専用APIに変更。非対応端末ではリアルタイム文字起こしを行わず、通常録音は維持。録音後のクラウドAIは明示同意で利用できる。

## 端末内議事録の試作

Debug版の議事録画面に、ML Kit GenAI Summarizationによる端末内要約の試作を追加。

- 対応言語は日本語・英語・韓国語。端末・モデルの実行時状態を確認。
- モデルが既に利用可能な場合のみ実行。モデル自動ダウンロード、クラウドへのフォールバックは行わない。
- **要約のみ。TODO抽出や保存は未対応**。長文分割処理も未実装。入力上限等はSDKのエラーとして扱い、利用者に制約を表示。
- Release APKのDEXに `com/google/mlkit/genai/summarization` が含まれないことを確認。デバッグ専用の依存で、Release側は空の表示実装。
- Gemini Nano対応実機は未接続。生成品質、実端末の速度・メモリ使用量は未検証。試作を本番機能として公開する段階ではない。

根拠:
- https://developers.google.com/ml-kit/genai/summarization/android
- https://developer.android.com/reference/android/speech/SpeechRecognizer

## 検証

JBR 17、Pixel 7 API 35 Playエミュレーター（Android 15）で実施。

```sh
./gradlew :app:assembleDebug :app:assembleRelease :app:testDebugUnitTest :app:lintDebug :app:connectedDebugAndroidTest
```

- Debug APK / Release APK: 成功。
- 全単体テスト: 285件、失敗0、skip 0。
- Instrumentation: 7件、失敗0（既存1件＋同意画面5件＋実AAC編集1件）。
- lintDebug: エラー0、警告111。検出された新規翻訳漏れを解消。既存のCompose内 `context.getString` 1箇所も `stringResource` に変更。
- git diff --check: 成功。
- 同意テスト: 日本語／英語、音声／テキスト、大きな文字サイズで許可・拒否ボタンを確認。単体テストで許可前・拒否後・撤回中の送信禁止、用途別許可、旧同意無効化、許可後の送信を検証。
- 音声テスト: 人の録音を使わず、ffmpegで作成した440Hz・3秒のAAC音声を分割。元ファイルのバイト不変、出力2件の音声トラック・形式・長さを確認。
- ショートカット停止: 登録された録音リスナーだけを呼ぶこと、無関係なactionでは停止しないことを単体テスト。
- ショートカットのランチャー実操作・実録音中の停止、および最新録音からの画面遷移全体は未実機検証。
- 本番のAIサーバーへユーザー音声を送る検証は行っていない。

当初の日本語UIテスト失敗は、テスト用言語設定がComposeのLocalResourcesへ伝播せず英語画面を日本語ラベルで検索したことが原因。テストのLocalResourcesを明示し修正。説明欄には高さ上限とスクロールを設定し、選択ボタンの領域を確保した。

ログ: `/private/tmp/voilog-android-final-validation.log`。APKのハッシュ、画面画像は `docs/android-parity-evidence/` に保存。

## 制約と配布前の残作業

- 音声分割はAACのみ。旧3GP/AMR録音は変換処理を追加するまで対象外。サンプル単位での無損失切り分けであり、圧縮フレームより細かい境界精度は保証しない。
- 端末内議事録の製品化には対応実機の品質検証、長文分割、TODO抽出が必要。
- 通常録音のリアルタイム認識は端末内認識対応環境に限定される。
- リリース作業で2.10.0 (19)へ更新。日英リリースノート、署名付きAAB、mainのコミット `013500da` とタグ `android-v2.10.0` をpush済み。
- `lp/privacy_policy.html` にAndroid 2.10.0以降の端末内音声認識の説明を日英で追記。Firebase Hostingへ公開し、公開URLの内容を照合済み。
- 署名付きAABは `launchpad android build --release` 成功。更新後の単体テスト285件とlintDebugも成功。
- launchpadのアップロードは通信タイムアウト。既存editで未受信を確認し、同じGoogle Play APIへタイムアウト600秒で再送。versionCode 19とローカルSHA256の一致を確認。
- 製品版トラックへ2.10.0 (19)、日英更新説明を設定し、validate / commitがHTTP 200。再取得でもproductionに19を確認。APIの `completed` はトラックの公開割合設定で、審査完了を意味しない。
- Play Consoleの管理対象の公開はオフ（従来設定）。承認後は自動公開対象。
- 既存の未追跡 `docs/monetization_proposal_2026-10-11.md` は保持。

画像採取用に新規Instrumentation 6件を再実行し全件成功。大きな文字サイズはエミュレーターのシステムfont_scaleを1.5へ変更して検証し、終了時に元の設定へ復元。最終テストコードの再コンパイルとlintも成功（`/private/tmp/voilog-android-font-test-build.log`）。
