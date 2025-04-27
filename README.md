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

### Xcode Cloudと併用する場合

ビルドはXcode Cloudで行い、メタデータとスクリーンショットの更新のみFastlaneで管理する場合は以下のレーンを使用できます：

- スクリーンショット生成:
  ```
  bundle exec fastlane screenshots
  ```

- メタデータのみ更新:
  ```
  bundle exec fastlane update_metadata
  ```

- スクリーンショットのみ更新:
  ```
  bundle exec fastlane update_screenshots
  ```

- メタデータとスクリーンショット両方を更新:
  ```
  bundle exec fastlane update_store
  ```

メタデータは `fastlane/metadata` ディレクトリ内で管理します。各言語ごとに説明文、キーワード、リリースノートなどを編集できます。

詳細については、`fastlane/Fastfile`を参照してください。
