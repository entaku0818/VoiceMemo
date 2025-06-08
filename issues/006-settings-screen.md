# Issue #6: 設定画面の実装

**Priority**: High  
**Labels**: `enhancement`, `settings`, `ui`  
**GitHub Issue**: [#76](https://github.com/entaku0818/VoiceMemo/issues/76)

## Description
音声品質設定（サンプリング周波数、ビット深度等）やアプリ設定を行う画面をVoiceAppViewに追加する。

## Tasks
- [ ] SettingViewの統合
- [ ] 録音品質設定
- [ ] アプリ設定項目
- [ ] 設定の永続化
- [ ] 設定画面へのナビゲーション

## Files to modify
- `VoiLog/Setting/SettingView.swift`
- `VoiLog/Setting/SettingReducer.swift`
- `VoiLog/Recording/RecordingFeature.swift`

## Acceptance Criteria
- 録音品質を変更できる
- 設定がアプリ再起動後も保持される
- 設定画面にアクセスできる

## Implementation Notes
- 既存のSettingViewを活用
- UserDefaultsまたはCoreDataで設定を永続化
- 設定変更時にRecordingFeatureに反映
