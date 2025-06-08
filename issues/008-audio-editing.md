# Issue #8: 音声編集機能の実装

**Priority**: High  
**Labels**: `enhancement`, `audio-editing`, `premium`  
**GitHub Issue**: [#78](https://github.com/entaku0818/VoiceMemo/issues/78)

## Description
既存のVoiceMemosViewにある音声編集機能（トリミング、分割、音量調整）をVoiceAppViewにも実装する。

## Tasks
- [ ] AudioEditorViewの統合
- [ ] 波形表示機能
- [ ] トリミング機能
- [ ] 分割機能
- [ ] 音量調整機能

## Files to modify
- `VoiLog/Voice/AudioEditorView.swift`
- `VoiLog/Voice/AudioEditorReducer.swift`
- `VoiLog/Playback/PlaybackFeature.swift`

## Acceptance Criteria
- 音声ファイルの編集ができる
- 編集結果が適切に保存される
- プレミアム機能として制御される

## Implementation Notes
- 既存のAudioEditorViewを活用
- AVAudioEngineを使用した音声処理
- プレミアム機能として制限を実装
