# Issue #13: Live Activities対応

**Priority**: Low  
**Labels**: `enhancement`, `ios16`, `live-activities`  
**GitHub Issue**: [#83](https://github.com/entaku0818/VoiceMemo/issues/83)

## Description
録音中にiOS 16.1以降のLive Activities機能を使用して、ロック画面やDynamic Islandに録音状態を表示する。

## Tasks
- [ ] recordActivityAttributesの統合
- [ ] Live Activities開始・終了処理
- [ ] 録音時間の動的更新
- [ ] iOS バージョン対応

## Files to modify
- `recordActivity/` ディレクトリ
- `VoiLog/Recording/RecordingFeature.swift`

## Acceptance Criteria
- 録音中にLive Activitiesが表示される
- 録音時間がリアルタイムで更新される
- iOS 16.1未満でもエラーが発生しない

## Implementation Notes
- 既存のrecordActivityAttributesを活用
- iOS バージョンチェックの実装
- Live Activitiesの適切な開始・終了タイミング
