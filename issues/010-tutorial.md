# Issue #10: チュートリアル機能の実装

**Priority**: Medium  
**Labels**: `enhancement`, `onboarding`, `ui`  
**GitHub Issue**: [#80](https://github.com/entaku0818/VoiceMemo/issues/80)

## Description
新規ユーザー向けのチュートリアル機能をVoiceAppViewに実装する。

## Tasks
- [ ] TutorialViewの統合
- [ ] チュートリアル表示制御
- [ ] 初回起動判定
- [ ] チュートリアルスキップ機能

## Files to modify
- `VoiLog/Voice/TutorialView.swift`
- `VoiLog/DebugMode/DebugModeFeature.swift`

## Acceptance Criteria
- 初回起動時にチュートリアルが表示される
- チュートリアルをスキップできる
- チュートリアル完了状態が保存される

## Implementation Notes
- 既存のTutorialViewを活用
- UserDefaultsで初回起動状態を管理
- 適切なタイミングでチュートリアルを表示
