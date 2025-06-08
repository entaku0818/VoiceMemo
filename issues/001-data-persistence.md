# Issue #1: データ永続化機能の実装

**Priority**: Critical  
**Labels**: `enhancement`, `data`, `core-feature`  
**GitHub Issue**: [#71](https://github.com/entaku0818/VoiceMemo/issues/71)

## Description
新しいVoiceAppViewでは録音したデータが保存されず、アプリを再起動すると消えてしまう。既存のVoiceMemosViewと同様にCoreDataを使用したデータ永続化を実装する必要がある。

## Tasks
- [ ] VoiceAppFeatureにVoiceMemoRepositoryの統合
- [ ] 録音完了時の自動保存処理
- [ ] アプリ起動時の既存データ読み込み
- [ ] データ削除・更新処理

## Files to modify
- `VoiLog/DebugMode/DebugModeFeature.swift`
- `VoiLog/data/VoiceMemoRepository.swift`
- `VoiLog/data/VoiceMemoCoredataAccessor.swift`

## Acceptance Criteria
- 録音したデータがアプリ再起動後も保持される
- 既存のVoiceMemosViewのデータと互換性がある
- データの作成・読み取り・更新・削除が正常に動作する

## Implementation Notes
- 既存のCoreDataスキーマを活用する
- VoiceMemoRepositoryの依存関係注入パターンを使用
- エラーハンドリングを適切に実装する 