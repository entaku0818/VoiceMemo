# Issue #12: 詳細な音声情報表示

**Priority**: Low  
**Labels**: `enhancement`, `ui`, `metadata`  
**GitHub Issue**: [#82](https://github.com/entaku0818/VoiceMemo/issues/82)

## Description
録音ファイルの詳細情報（ファイル形式、サンプリング周波数、ビット深度等）を表示する機能を実装する。

## Tasks
- [ ] 音声ファイル詳細情報の表示
- [ ] ファイルサイズ表示
- [ ] 音質設定の表示
- [ ] メタデータ表示UI

## Files to modify
- `VoiLog/Playback/PlaybackFeature.swift`
- `VoiLog/Voice/VoiceMemoReducer.swift`

## Acceptance Criteria
- ファイルの詳細情報が表示される
- 情報が正確で読みやすい
- 技術的な情報が適切に表示される

## Implementation Notes
- AVAssetを使用してメタデータを取得
- ファイルサイズの計算と表示
- 技術的な情報の分かりやすい表示
