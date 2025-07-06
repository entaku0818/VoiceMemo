# Issue #17: UI修正と改善

**Priority**: Medium  
**Labels**: `bug`, `ui/ux`, `enhancement`  
**GitHub Issue**: [#87](https://github.com/entaku0818/VoiceMemo/issues/87)

## Description
録音機能とプレイリスト機能、設定画面のUI/UX改善を行う。複数の小さな問題を修正し、ユーザー体験を向上させる。

## Tasks

### 🎙️ 録音機能の修正
- [ ] 録音準備完了時の前回録音時間表示を初期化
- [ ] 録音完了時のタイトル修正画面のレイアウト崩れを修正

### 📋 プレイリスト機能の改善
- [ ] プレイリストが空の場合の案内メッセージ表示
- [ ] 「プレイリストを作成しましょう」的な促進UI追加

### ⚙️ 設定画面の修正
- [ ] 設定画面タブの区切り線を追加
- [ ] 他のタブと統一感のあるデザインに修正

## Files to modify

### 録音機能
- `VoiLog/Recording/RecordingFeature.swift`
- `VoiLog/Recording/` 関連のView

### プレイリスト機能
- `VoiLog/Playlist/PlaylistListView.swift`
- `VoiLog/Playlist/ModernPlaylistListView.swift`

### 設定画面
- `VoiLog/Setting/SettingView.swift`
- `VoiLog/DebugMode/DebugModeFeature.swift` (タブ設定)

## Acceptance Criteria

### 録音機能
- [ ] 録音準備画面で前回の録音時間が表示されない
- [ ] 録音完了後のタイトル編集画面が正常に表示される
- [ ] タイトル編集UI要素が適切に配置される

### プレイリスト機能
- [ ] プレイリストが0件の場合、作成を促すメッセージが表示される
- [ ] 空状態でもユーザーが次のアクションを理解できる
- [ ] プレイリスト作成ボタンへの誘導が分かりやすい

### 設定画面
- [ ] 設定画面のタブに区切り線が表示される
- [ ] 他のタブ（録音、再生）と視覚的に統一されている
- [ ] タブ間の境界が明確に認識できる

## Implementation Notes

### 録音時間初期化
```swift
// RecordingFeature.swift
// 録音準備完了時に前回の録音時間をリセット
case .recordingPermissionGranted:
  state.recordingTime = 0
  state.mode = .recording
```

### タイトル編集画面修正
- レイアウト制約の確認
- SafeAreaの適切な設定
- キーボード表示時の対応

### プレイリスト空状態
- ContentUnavailableView (iOS 17+) または独自の空状態View
- 「プレイリストを作成して音声を整理しましょう」メッセージ
- 作成ボタンへの誘導

### 設定画面タブ
- TabViewのdivider表示
- 一貫したタブデザイン
- アイコンとラベルの統一

## Screenshots/Mockups
（必要に応じて追加）

## Related Issues
- 録音機能の基本実装
- プレイリスト機能の実装 (#81)
- UI/UXの全体的な改善

## Definition of Done
- [ ] 全ての修正項目が実装され、テストされている
- [ ] UIが各デバイスサイズで適切に表示される
- [ ] ユーザビリティテストで問題が確認されない
- [ ] コードレビューが完了している