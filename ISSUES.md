# VoiceAppView Development Issues

## 🔴 高優先度（必須）

### Issue #1: データ永続化機能の実装
**Priority**: Critical  
**Labels**: `enhancement`, `data`, `core-feature`

**Description**:
新しいVoiceAppViewでは録音したデータが保存されず、アプリを再起動すると消えてしまう。既存のVoiceMemosViewと同様にCoreDataを使用したデータ永続化を実装する必要がある。

**Tasks**:
- [ ] VoiceAppFeatureにVoiceMemoRepositoryの統合
- [ ] 録音完了時の自動保存処理
- [ ] アプリ起動時の既存データ読み込み
- [ ] データ削除・更新処理

**Files to modify**:
- `VoiLog/DebugMode/DebugModeFeature.swift`
- `VoiLog/data/VoiceMemoRepository.swift`
- `VoiLog/data/VoiceMemoCoredataAccessor.swift`

**Acceptance Criteria**:
- 録音したデータがアプリ再起動後も保持される
- 既存のVoiceMemosViewのデータと互換性がある
- データの作成・読み取り・更新・削除が正常に動作する

---

### Issue #2: 録音完了後の保存フロー実装
**Priority**: Critical  
**Labels**: `enhancement`, `recording`, `data-flow`

**Description**:
現在、RecordingFeatureで録音したデータがPlaybackFeatureに自動的に反映されない。録音完了時にデータベースに保存し、再生画面に即座に表示される仕組みを実装する。

**Tasks**:
- [ ] RecordingFeature完了時のデータ保存
- [ ] PlaybackFeatureでのデータ自動更新
- [ ] VoiceAppFeature内でのデータ同期処理
- [ ] 録音完了時のdelegate action実装

**Files to modify**:
- `VoiLog/Recording/RecordingFeature.swift`
- `VoiLog/Playback/PlaybackFeature.swift`
- `VoiLog/DebugMode/DebugModeFeature.swift`

**Acceptance Criteria**:
- 録音完了後、即座に再生タブにファイルが表示される
- データの整合性が保たれる
- エラーハンドリングが適切に実装されている

---

### Issue #3: 既存データとの互換性確保
**Priority**: Critical  
**Labels**: `compatibility`, `data`, `migration`

**Description**:
既存のVoiceMemosViewで作成されたデータがVoiceAppViewで表示されない。同じデータソース（CoreData）を使用して、既存データとの互換性を確保する。

**Tasks**:
- [ ] 同一のVoiceMemoReducer.Stateモデル使用
- [ ] 既存データの読み込み処理
- [ ] データ形式の統一
- [ ] マイグレーション処理（必要に応じて）

**Files to modify**:
- `VoiLog/Voice/VoiceMemoReducer.swift`
- `VoiLog/Playback/PlaybackFeature.swift`

**Acceptance Criteria**:
- 既存のVoiceMemosViewで作成したファイルがVoiceAppViewで表示される
- データの欠損や破損が発生しない
- 両方のビューで同じデータが正常に動作する

---

## 🟡 中優先度（重要）

### Issue #4: クラウド同期機能の実装
**Priority**: High  
**Labels**: `enhancement`, `cloud`, `sync`

**Description**:
既存のVoiceMemosViewにあるクラウド同期機能（CloudUploader）をVoiceAppViewにも実装し、デバイス間でのデータ同期を可能にする。

**Tasks**:
- [ ] CloudUploaderの統合
- [ ] 同期状態の表示（synced/syncing/notSynced）
- [ ] 手動同期ボタンの追加
- [ ] 同期エラーハンドリング
- [ ] プレミアム機能との連携

**Files to modify**:
- `VoiLog/data/CloudUploader.swift`
- `VoiLog/DebugMode/DebugModeFeature.swift`
- `VoiLog/Playback/PlaybackFeature.swift`

**Acceptance Criteria**:
- iCloudを使用したデータ同期が動作する
- 同期状態が視覚的に分かる
- 同期エラー時に適切なメッセージが表示される

---

### Issue #5: プレミアム機能管理の実装
**Priority**: High  
**Labels**: `enhancement`, `monetization`, `premium`

**Description**:
既存のVoiceMemosViewにある課金機能（RevenueCat）とプレミアム機能の制御をVoiceAppViewにも実装する。

**Tasks**:
- [ ] RevenueCat統合
- [ ] プレミアム状態の管理
- [ ] 機能制限の実装
- [ ] Paywallの表示
- [ ] 購入状態の永続化

**Files to modify**:
- `VoiLog/Store/PaywallView.swift`
- `VoiLog/DebugMode/DebugModeFeature.swift`

**Acceptance Criteria**:
- プレミアム機能の購入・復元が動作する
- 無料ユーザーに適切な制限が適用される
- 購入状態がアプリ再起動後も保持される

---

### Issue #6: 設定画面の実装
**Priority**: High  
**Labels**: `enhancement`, `settings`, `ui`

**Description**:
音声品質設定（サンプリング周波数、ビット深度等）やアプリ設定を行う画面をVoiceAppViewに追加する。

**Tasks**:
- [ ] SettingViewの統合
- [ ] 録音品質設定
- [ ] アプリ設定項目
- [ ] 設定の永続化
- [ ] 設定画面へのナビゲーション

**Files to modify**:
- `VoiLog/Setting/SettingView.swift`
- `VoiLog/Setting/SettingReducer.swift`
- `VoiLog/Recording/RecordingFeature.swift`

**Acceptance Criteria**:
- 録音品質を変更できる
- 設定がアプリ再起動後も保持される
- 設定画面にアクセスできる

---

### Issue #7: タイトル編集機能の実装
**Priority**: High  
**Labels**: `enhancement`, `ui`, `editing`

**Description**:
録音完了時や後からファイルのタイトルを編集できる機能を実装する。

**Tasks**:
- [ ] タイトル編集ダイアログ
- [ ] インライン編集機能
- [ ] タイトル更新処理
- [ ] 録音完了時のタイトル設定

**Files to modify**:
- `VoiLog/Playback/PlaybackFeature.swift`
- `VoiLog/Recording/RecordingFeature.swift`

**Acceptance Criteria**:
- 録音ファイルのタイトルを編集できる
- タイトルの変更が即座に反映される
- 空のタイトルに対する適切な処理

---

### Issue #8: 音声編集機能の実装
**Priority**: High  
**Labels**: `enhancement`, `audio-editing`, `premium`

**Description**:
既存のVoiceMemosViewにある音声編集機能（トリミング、分割、音量調整）をVoiceAppViewにも実装する。

**Tasks**:
- [ ] AudioEditorViewの統合
- [ ] 波形表示機能
- [ ] トリミング機能
- [ ] 分割機能
- [ ] 音量調整機能

**Files to modify**:
- `VoiLog/Voice/AudioEditorView.swift`
- `VoiLog/Voice/AudioEditorReducer.swift`
- `VoiLog/Playback/PlaybackFeature.swift`

**Acceptance Criteria**:
- 音声ファイルの編集ができる
- 編集結果が適切に保存される
- プレミアム機能として制御される

---

## 🟢 低優先度（将来的）

### Issue #9: 広告表示機能の実装
**Priority**: Medium  
**Labels**: `enhancement`, `monetization`, `ads`

**Description**:
収益化のためのAdMob広告表示機能をVoiceAppViewに実装する。

**Tasks**:
- [ ] AdMobBannerViewの統合
- [ ] 広告表示位置の最適化
- [ ] 広告トラッキング許可の管理
- [ ] 広告収益の最適化

**Files to modify**:
- `VoiLog/AdmobBannerView.swift`
- `VoiLog/DebugMode/DebugModeFeature.swift`

**Acceptance Criteria**:
- 適切な位置に広告が表示される
- 広告がユーザー体験を阻害しない
- 広告収益が計測できる

---

### Issue #10: チュートリアル機能の実装
**Priority**: Medium  
**Labels**: `enhancement`, `onboarding`, `ui`

**Description**:
新規ユーザー向けのチュートリアル機能をVoiceAppViewに実装する。

**Tasks**:
- [ ] TutorialViewの統合
- [ ] チュートリアル表示制御
- [ ] 初回起動判定
- [ ] チュートリアルスキップ機能

**Files to modify**:
- `VoiLog/Voice/TutorialView.swift`
- `VoiLog/DebugMode/DebugModeFeature.swift`

**Acceptance Criteria**:
- 初回起動時にチュートリアルが表示される
- チュートリアルをスキップできる
- チュートリアル完了状態が保存される

---

### Issue #11: プレイリスト機能の実装
**Priority**: Medium  
**Labels**: `enhancement`, `playlist`, `organization`

**Description**:
音声ファイルをプレイリストで管理する機能をVoiceAppViewに実装する。

**Tasks**:
- [ ] PlaylistFeatureの統合
- [ ] プレイリスト作成・編集
- [ ] プレイリスト再生機能
- [ ] プレイリスト管理UI

**Files to modify**:
- `VoiLog/Playlist/PlaylistDetailFeature.swift`
- `VoiLog/Playback/PlaybackFeature.swift`

**Acceptance Criteria**:
- プレイリストを作成・編集できる
- プレイリストから連続再生できる
- プレイリストの管理が直感的

---

### Issue #12: 詳細な音声情報表示
**Priority**: Low  
**Labels**: `enhancement`, `ui`, `metadata`

**Description**:
録音ファイルの詳細情報（ファイル形式、サンプリング周波数、ビット深度等）を表示する機能を実装する。

**Tasks**:
- [ ] 音声ファイル詳細情報の表示
- [ ] ファイルサイズ表示
- [ ] 音質設定の表示
- [ ] メタデータ表示UI

**Files to modify**:
- `VoiLog/Playback/PlaybackFeature.swift`
- `VoiLog/Voice/VoiceMemoReducer.swift`

**Acceptance Criteria**:
- ファイルの詳細情報が表示される
- 情報が正確で読みやすい
- 技術的な情報が適切に表示される

---

### Issue #13: Live Activities対応
**Priority**: Low  
**Labels**: `enhancement`, `ios16`, `live-activities`

**Description**:
録音中にiOS 16.1以降のLive Activities機能を使用して、ロック画面やDynamic Islandに録音状態を表示する。

**Tasks**:
- [ ] recordActivityAttributesの統合
- [ ] Live Activities開始・終了処理
- [ ] 録音時間の動的更新
- [ ] iOS バージョン対応

**Files to modify**:
- `recordActivity/` ディレクトリ
- `VoiLog/Recording/RecordingFeature.swift`

**Acceptance Criteria**:
- 録音中にLive Activitiesが表示される
- 録音時間がリアルタイムで更新される
- iOS 16.1未満でもエラーが発生しない

---

### Issue #14: アプリ評価・フィードバック機能
**Priority**: Low  
**Labels**: `enhancement`, `feedback`, `app-store`

**Description**:
アプリの評価促進とユーザーフィードバック収集機能を実装する。

**Tasks**:
- [ ] SKStoreReviewController統合
- [ ] メール送信機能
- [ ] フィードバック収集フロー
- [ ] 評価促進タイミングの最適化

**Files to modify**:
- `VoiLog/DebugMode/DebugModeFeature.swift`

**Acceptance Criteria**:
- 適切なタイミングで評価が促進される
- フィードバックを送信できる
- ユーザー体験を阻害しない

---

### Issue #15: 検索機能の強化
**Priority**: Low  
**Labels**: `enhancement`, `search`, `ui`

**Description**:
音声ファイルの検索機能を強化し、タイトル、文字起こしテキスト、日付などで検索できるようにする。

**Tasks**:
- [ ] 高度な検索フィルター
- [ ] 検索履歴機能
- [ ] 検索結果のハイライト
- [ ] 検索パフォーマンスの最適化

**Files to modify**:
- `VoiLog/Playback/PlaybackFeature.swift`

**Acceptance Criteria**:
- 複数の条件で検索できる
- 検索が高速で動作する
- 検索結果が分かりやすい

---

### Issue #16: エクスポート・共有機能
**Priority**: Low  
**Labels**: `enhancement`, `export`, `sharing`

**Description**:
録音ファイルを他のアプリに共有したり、異なる形式でエクスポートする機能を実装する。

**Tasks**:
- [ ] ファイル共有機能
- [ ] 形式変換機能
- [ ] クラウドストレージ連携
- [ ] 一括エクスポート機能

**Files to modify**:
- `VoiLog/Playback/PlaybackFeature.swift`

**Acceptance Criteria**:
- ファイルを他のアプリに共有できる
- 異なる形式でエクスポートできる
- 共有が簡単で直感的

---

## 📋 実装順序の推奨

1. **Phase 1 (Critical)**: Issues #1, #2, #3
2. **Phase 2 (Core Features)**: Issues #4, #5, #6, #7, #8
3. **Phase 3 (Enhancement)**: Issues #9, #10, #11
4. **Phase 4 (Polish)**: Issues #12, #13, #14, #15, #16

## 🔧 開発環境

- **iOS**: 16.4+
- **Xcode**: 15.0+
- **Swift**: 5.9+
- **Dependencies**: ComposableArchitecture, RevenueCat, Firebase, GoogleMobileAds

## 📝 Notes

- 各issueは独立して実装可能
- Phase 1の完了後、基本的なアプリとして動作する
- プレミアム機能は適切に制御する
- 既存のVoiceMemosViewとの互換性を常に考慮する 