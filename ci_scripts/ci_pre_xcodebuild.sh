#!/bin/sh

echo "Starting pre-build script..."

# プロジェクトのルートディレクトリに移動
cd $CI_PRIMARY_REPOSITORY_PATH/VoiLog/

# 必要な環境変数のチェック
REQUIRED_VARS=(
    "ROLLBAR_KEY"
    "ADMOB_KEY"
    "RECORD_ADMOB_KEY"
    "REVENUECAT_KEY"
    "PLAYLIST_ADMOB_KEY"
)

# 未設定の環境変数をチェック
MISSING_VARS=()
for VAR in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!VAR}" ]; then
        MISSING_VARS+=($VAR)
    fi
done

# 未設定の環境変数があればビルドを失敗させる
if [ ${#MISSING_VARS[@]} -ne 0 ]; then
    echo "Error: 以下の環境変数が設定されていません:"
    printf '%s\n' "${MISSING_VARS[@]}"
    exit 1
fi

# 環境変数が正しく設定されている場合、Info.plistに書き込み
plutil -replace ROLLBAR_KEY -string "$ROLLBAR_KEY" Info.plist
plutil -replace ADMOB_KEY -string "$ADMOB_KEY" Info.plist
plutil -replace RECORD_ADMOB_KEY -string "$RECORD_ADMOB_KEY" Info.plist
plutil -replace REVENUECAT_KEY -string "$REVENUECAT_KEY" Info.plist
plutil -replace PLAYLIST_ADMOB_KEY -string "$PLAYLIST_ADMOB_KEY" Info.plist

# 結果を確認
echo "Info.plistの更新を確認中..."
plutil -p Info.plist

echo "環境変数の設定が完了しました"
exit 0