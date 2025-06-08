# Issue #16: エクスポート・共有機能

**Priority**: Low  
**Labels**: `enhancement`, `export`, `sharing`  
**GitHub Issue**: [#86](https://github.com/entaku0818/VoiceMemo/issues/86)

## Description
録音ファイルを他のアプリに共有したり、異なる形式でエクスポートする機能を実装する。

## Tasks
- [ ] ファイル共有機能
- [ ] 形式変換機能
- [ ] クラウドストレージ連携
- [ ] 一括エクスポート機能

## Files to modify
- `VoiLog/Playback/PlaybackFeature.swift`

## Acceptance Criteria
- ファイルを他のアプリに共有できる
- 異なる形式でエクスポートできる
- 共有が簡単で直感的

## Implementation Notes
- UIActivityViewControllerを使用した共有
- AVAssetExportSessionを使用した形式変換
- 一括操作のUI実装
