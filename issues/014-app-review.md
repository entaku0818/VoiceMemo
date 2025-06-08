# Issue #14: アプリ評価・フィードバック機能

**Priority**: Low  
**Labels**: `enhancement`, `feedback`, `app-store`  
**GitHub Issue**: [#84](https://github.com/entaku0818/VoiceMemo/issues/84)

## Description
アプリの評価促進とユーザーフィードバック収集機能を実装する。

## Tasks
- [ ] SKStoreReviewController統合
- [ ] メール送信機能
- [ ] フィードバック収集フロー
- [ ] 評価促進タイミングの最適化

## Files to modify
- `VoiLog/DebugMode/DebugModeFeature.swift`

## Acceptance Criteria
- 適切なタイミングで評価が促進される
- フィードバックを送信できる
- ユーザー体験を阻害しない

## Implementation Notes
- SKStoreReviewControllerの適切な使用
- 評価促進の頻度制限
- メール送信機能の実装
