# Issue #7: タイトル編集機能の実装

**Priority**: High  
**Labels**: `enhancement`, `ui`, `editing`  
**GitHub Issue**: [#77](https://github.com/entaku0818/VoiceMemo/issues/77)

## Description
録音完了時や後からファイルのタイトルを編集できる機能を実装する。

## Tasks
- [ ] タイトル編集ダイアログ
- [ ] インライン編集機能
- [ ] タイトル更新処理
- [ ] 録音完了時のタイトル設定

## Files to modify
- `VoiLog/Playback/PlaybackFeature.swift`
- `VoiLog/Recording/RecordingFeature.swift`

## Acceptance Criteria
- 録音ファイルのタイトルを編集できる
- タイトルの変更が即座に反映される
- 空のタイトルに対する適切な処理

## Implementation Notes
- SwiftUIのTextFieldまたはAlert使用
- タイトル編集時のバリデーション実装
- データベースへの更新処理
