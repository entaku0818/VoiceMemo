# Issue #3: 既存データとの互換性確保

**Priority**: Critical  
**Labels**: `compatibility`, `data`, `migration`  
**GitHub Issue**: [#73](https://github.com/entaku0818/VoiceMemo/issues/73)

## Description
既存のVoiceMemosViewで作成されたデータがVoiceAppViewで表示されない。同じデータソース（CoreData）を使用して、既存データとの互換性を確保する。

## Tasks
- [ ] 同一のVoiceMemoReducer.Stateモデル使用
- [ ] 既存データの読み込み処理
- [ ] データ形式の統一
- [ ] マイグレーション処理（必要に応じて）

## Files to modify
- `VoiLog/Voice/VoiceMemoReducer.swift`
- `VoiLog/Playback/PlaybackFeature.swift`

## Acceptance Criteria
- 既存のVoiceMemosViewで作成したファイルがVoiceAppViewで表示される
- データの欠損や破損が発生しない
- 両方のビューで同じデータが正常に動作する

## Implementation Notes
- 既存のVoiceMemoReducer.Stateモデルを再利用
- CoreDataエンティティの互換性を確認
- 必要に応じてデータマイグレーション処理を実装 