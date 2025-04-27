# シンプル録音

- インストールいただけたら大変嬉しいです！

  <img src="https://github.com/entaku0818/VoiceMemo/assets/9211010/48fc8bcd-f50c-45c5-81ef-fc57f12ffd0d" width="30%" />

  https://apps.apple.com/us/app/%E3%82%B7%E3%83%B3%E3%83%97%E3%83%AB%E9%8C%B2%E9%9F%B3/id6443528409

## 開発リソース

- `VoiLog/Template/` - ComposableArchitectureを使用した機能開発用のテンプレートが含まれています。詳細は[テンプレートREADME](VoiLog/Template/README.md)を参照してください。

## Fastlane

プロジェクトはFastlaneを使用して自動化されています。以下のコマンドを使用できます：

### セットアップ

```
bundle install
```

### 使用可能なレーン

- テスト実行:
  ```
  bundle exec fastlane tests
  ```

- 開発用ビルド:
  ```
  bundle exec fastlane build
  ```

- TestFlightへのアップロード:
  ```
  bundle exec fastlane beta
  ```

- App Storeへのリリース:
  ```
  bundle exec fastlane release
  ```

詳細については、`fastlane/Fastfile`を参照してください。
