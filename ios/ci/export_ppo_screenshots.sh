#!/bin/bash
# ScreenshotRenderTests/testRenderPPOVariants が /tmp/voilog_screenshots/_ppo/ に書き出した
# プロダクトページの最適化（A/B テスト）用の別案を fastlane/screenshots_ppo/ へコピーする。
#
# 公開用の fastlane/screenshots/ とは分けておく（launchpad ios screenshots でアップロードされないように）。
#
# 使い方:
#   xcodebuild test -project ios/VoiLog.xcodeproj -scheme VoiLogTests \
#     -destination 'platform=iOS Simulator,id=<UDID>' -only-testing:VoiLogTests/ScreenshotRenderTests/testRenderPPOVariants
#   ios/ci/export_ppo_screenshots.sh
set -euo pipefail

cd "$(dirname "$0")/../.."

SRC_DIR=${SRC_DIR:-/tmp/voilog_screenshots/_ppo}
DEST_DIR=${DEST_DIR:-fastlane/screenshots_ppo}

if [ ! -d "$SRC_DIR" ]; then
  echo "error: $SRC_DIR がありません。先に testRenderPPOVariants を実行してください" >&2
  exit 1
fi

copied=0
while IFS= read -r src; do
  dest="$DEST_DIR/${src#"$SRC_DIR"/}"
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  copied=$((copied + 1))
done < <(find "$SRC_DIR" -name '*.png' | sort)

echo "done: copied=$copied (dest=$DEST_DIR)"
