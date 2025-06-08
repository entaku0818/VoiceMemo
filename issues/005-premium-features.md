# Issue #5: プレミアム機能管理の実装

**Priority**: High  
**Labels**: `enhancement`, `monetization`, `premium`  
**GitHub Issue**: [#75](https://github.com/entaku0818/VoiceMemo/issues/75)

## Description
既存のVoiceMemosViewにある課金機能（RevenueCat）とプレミアム機能の制御をVoiceAppViewにも実装する。

## Tasks
- [ ] RevenueCat統合
- [ ] プレミアム状態の管理
- [ ] 機能制限の実装
- [ ] Paywallの表示
- [ ] 購入状態の永続化

## Files to modify
- `VoiLog/Store/PaywallView.swift`
- `VoiLog/DebugMode/DebugModeFeature.swift`

## Acceptance Criteria
- プレミアム機能の購入・復元が動作する
- 無料ユーザーに適切な制限が適用される
- 購入状態がアプリ再起動後も保持される

## Implementation Notes
- 既存のRevenueCat設定を活用
- プレミアム状態をStateで管理
- 機能制限のロジックを適切に実装
