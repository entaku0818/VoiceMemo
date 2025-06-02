# VoiLog アプリ リリース作業手順書

## 現在の状況
- **アプリ名**: VoiLog (Simple Voice Recorder)
- **現在のバージョン**: 0.16.8
- **Bundle ID**: com.entaku.VoiLog
- **開発チーム**: 4YZQY4C47E
- **Apple ID**: entaku19890818@gmail.com

## 前提条件

### 必要な環境変数
リリース作業を実行する前に、以下の環境変数を設定する必要があります：

```bash
export APP_STORE_CONNECT_API_KEY_KEY_ID="your_key_id"
export APP_STORE_CONNECT_API_KEY_ISSUER_ID="your_issuer_id"
export APP_STORE_CONNECT_API_KEY_CONTENT="your_api_key_content"
```

### App Store Connect APIキーの取得方法
1. [App Store Connect](https://appstoreconnect.apple.com/) にログイン
2. 「ユーザーとアクセス」→「キー」→「App Store Connect API」
3. 新しいキーを作成または既存のキーを使用
4. キーID、発行者ID、キーファイルの内容を取得

## リリース手順

### 1. 環境準備
```bash
# 作業ディレクトリに移動
cd /workspace

# 環境変数を設定（実際の値に置き換えてください）
export APP_STORE_CONNECT_API_KEY_KEY_ID="your_key_id"
export APP_STORE_CONNECT_API_KEY_ISSUER_ID="your_issuer_id"
export APP_STORE_CONNECT_API_KEY_CONTENT="your_api_key_content"

# PATHを設定
export PATH="$HOME/.local/share/gem/ruby/3.3.0/bin:$PATH"
```

### 2. バージョン確認
現在のプロジェクトバージョンを確認：
```bash
grep -r "MARKETING_VERSION.*0\.16\.8" VoiLog.xcodeproj/project.pbxproj
```

### 3. CHANGELOGの更新
`CHANGELOG.md` を更新して、バージョン 0.16.8 の変更内容を記載してください。

### 4. メタデータとスクリーンショットの準備
- `fastlane/metadata/` ディレクトリにアプリの説明文を配置
- `fastlane/screenshots/` ディレクトリにスクリーンショットを配置

### 5. リリース実行
```bash
bundle exec fastlane ios upload_metadata
```

## fastlane upload_metadata の動作内容

このlaneは以下の処理を自動実行します：

1. **バージョン番号の取得**: Xcodeプロジェクトから自動取得
2. **メタデータのアップロード**: アプリの説明文、キーワードなど
3. **スクリーンショットのアップロード**: 各デバイスサイズ対応
4. **審査提出**: App Store審査への自動提出
5. **設定内容**:
   - IDFA使用なし
   - 暗号化なし
   - 審査通過後の自動リリースは無効（手動リリース）

## トラブルシューティング

### 環境変数が設定されていない場合
```
Error: APP_STORE_CONNECT_API_KEY_KEY_ID environment variable not set
```
→ 上記の環境変数を正しく設定してください。

### バージョン番号が取得できない場合
```
Error: バージョン番号をXcodeプロジェクトから取得できませんでした。
```
→ Xcodeプロジェクトの設定を確認してください。

### 権限エラーが発生した場合
```
Error: You don't have permission to access this resource
```
→ App Store Connect APIキーの権限を確認してください。

## 注意事項

1. **審査提出前の確認**
   - アプリが正常に動作することを確認
   - スクリーンショットが最新であることを確認
   - メタデータが正確であることを確認

2. **リリース後の作業**
   - 審査状況の監視
   - 審査通過後の手動リリース実行
   - ユーザーフィードバックの監視

3. **バックアップ**
   - 重要な設定ファイルのバックアップを取得
   - 以前のバージョンのアーカイブを保持

## 関連ファイル

- `fastlane/Fastfile`: fastlaneの設定ファイル
- `fastlane/Appfile`: アプリの基本情報
- `fastlane/metadata/`: アプリストアのメタデータ
- `fastlane/screenshots/`: スクリーンショット
- `VoiLog.xcodeproj/project.pbxproj`: Xcodeプロジェクト設定