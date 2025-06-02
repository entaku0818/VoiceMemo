#!/bin/bash

# VoiLog アプリ リリーススクリプト
# 使用方法: ./release.sh

set -e  # エラーが発生したら停止

echo "🚀 VoiLog アプリ リリース作業を開始します..."

# 環境変数の確認
if [ -z "$APP_STORE_CONNECT_API_KEY_KEY_ID" ]; then
    echo "❌ エラー: APP_STORE_CONNECT_API_KEY_KEY_ID 環境変数が設定されていません"
    echo "以下のコマンドで環境変数を設定してください:"
    echo "export APP_STORE_CONNECT_API_KEY_KEY_ID=\"your_key_id\""
    echo "export APP_STORE_CONNECT_API_KEY_ISSUER_ID=\"your_issuer_id\""
    echo "export APP_STORE_CONNECT_API_KEY_CONTENT=\"your_api_key_content\""
    exit 1
fi

if [ -z "$APP_STORE_CONNECT_API_KEY_ISSUER_ID" ]; then
    echo "❌ エラー: APP_STORE_CONNECT_API_KEY_ISSUER_ID 環境変数が設定されていません"
    exit 1
fi

if [ -z "$APP_STORE_CONNECT_API_KEY_CONTENT" ]; then
    echo "❌ エラー: APP_STORE_CONNECT_API_KEY_CONTENT 環境変数が設定されていません"
    exit 1
fi

echo "✅ 環境変数の確認完了"

# PATHの設定
export PATH="$HOME/.local/share/gem/ruby/3.3.0/bin:$PATH"

# 現在のバージョンを確認
echo "📋 現在のバージョン情報を確認中..."
CURRENT_VERSION=$(grep -o "MARKETING_VERSION = [0-9.]*" VoiLog.xcodeproj/project.pbxproj | head -1 | cut -d' ' -f3 | tr -d ';')
echo "現在のバージョン: $CURRENT_VERSION"

# 確認プロンプト
echo ""
echo "⚠️  以下の内容でリリース作業を実行します:"
echo "   - アプリ名: VoiLog (Simple Voice Recorder)"
echo "   - バージョン: $CURRENT_VERSION"
echo "   - Bundle ID: com.entaku.VoiLog"
echo ""
read -p "続行しますか？ (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ リリース作業をキャンセルしました"
    exit 1
fi

echo ""
echo "🔄 fastlane upload_metadata を実行中..."

# fastlane実行
if bundle exec fastlane ios upload_metadata; then
    echo ""
    echo "🎉 リリース作業が正常に完了しました！"
    echo ""
    echo "📝 次のステップ:"
    echo "1. App Store Connect で審査状況を確認"
    echo "2. 審査通過後、手動でリリースを実行"
    echo "3. ユーザーフィードバックを監視"
    echo ""
    echo "🔗 App Store Connect: https://appstoreconnect.apple.com/"
else
    echo ""
    echo "❌ リリース作業中にエラーが発生しました"
    echo "詳細なエラー情報を確認して、問題を解決してください"
    exit 1
fi