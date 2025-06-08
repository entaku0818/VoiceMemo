# Issue #15: 検索機能の強化

**Priority**: Low  
**Labels**: `enhancement`, `search`, `ui`  
**GitHub Issue**: [#85](https://github.com/entaku0818/VoiceMemo/issues/85)

## Description
音声ファイルの検索機能を強化し、タイトル、文字起こしテキスト、日付などで検索できるようにする。

## Tasks
- [ ] 高度な検索フィルター
- [ ] 検索履歴機能
- [ ] 検索結果のハイライト
- [ ] 検索パフォーマンスの最適化

## Files to modify
- `VoiLog/Playback/PlaybackFeature.swift`

## Acceptance Criteria
- 複数の条件で検索できる
- 検索が高速で動作する
- 検索結果が分かりやすい

## Implementation Notes
- Core Dataの述語を使用した高度な検索
- 検索履歴の永続化
- 検索結果のハイライト表示
