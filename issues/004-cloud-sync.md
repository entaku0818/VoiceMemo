# Issue #4: クラウド同期機能の実装

**Priority**: High  
**Labels**: `enhancement`, `cloud`, `sync`  
**GitHub Issue**: [#74](https://github.com/entaku0818/VoiceMemo/issues/74)

## Description
既存のVoiceMemosViewにあるクラウド同期機能（CloudUploader）をVoiceAppViewにも実装し、デバイス間でのデータ同期を可能にする。

## Tasks
- [ ] CloudUploaderの統合
- [ ] 同期状態の表示（synced/syncing/notSynced）
- [ ] 手動同期ボタンの追加
- [ ] 同期エラーハンドリング
- [ ] プレミアム機能との連携

## Files to modify
- `VoiLog/data/CloudUploader.swift`
- `VoiLog/DebugMode/DebugModeFeature.swift`
- `VoiLog/Playback/PlaybackFeature.swift`

## Acceptance Criteria
- iCloudを使用したデータ同期が動作する
- 同期状態が視覚的に分かる
- 同期エラー時に適切なメッセージが表示される

## Implementation Notes
- 既存のCloudUploaderクラスを活用
- 同期状態をStateで管理
- プレミアム機能として制御する場合の実装も考慮 