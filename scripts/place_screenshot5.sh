#!/usr/bin/env bash
# 5枚目スクリーンショット（プレイリスト）をfastlane/screenshots/に配置するスクリプト
# 使用前提: temp/screenshots/iphone_new/ の *_05_playlist.png が 1290x2796px で再生成済みであること
#
# 使い方:
#   chmod +x scripts/place_screenshot5.sh
#   ./scripts/place_screenshot5.sh            # dry-run（コピーせず確認のみ）
#   ./scripts/place_screenshot5.sh --apply    # 実際にコピー実行

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$REPO_ROOT/temp/screenshots/iphone_new"
DST_ROOT="$REPO_ROOT/fastlane/screenshots"
REQUIRED_WIDTH=1290
REQUIRED_HEIGHT=2796
DRY_RUN=true

[[ "${1:-}" == "--apply" ]] && DRY_RUN=false

# "temp言語キー:fastlane言語ディレクトリ" のペアリスト
LANG_PAIRS=(
  "ja:ja"
  "en:en-US"
  "de:de-DE"
  "es:es-ES"
  "fr:fr-FR"
  "it:it"
  "pt:pt-PT"
  "ru:ru"
  "tr:tr"
  "vi:vi"
  "zh_hans:zh-Hans"
  "zh_hant:zh-Hant"
)

errors=0
successes=0

echo "=== 5枚目スクリーンショット配置チェック ==="
$DRY_RUN && echo "[DRY RUN モード: --apply を付けると実際にコピーします]"
echo ""

for pair in "${LANG_PAIRS[@]}"; do
  lang_key="${pair%%:*}"
  lang_dir="${pair##*:}"

  src="$SRC_DIR/${lang_key}_05_playlist.png"
  dst_dir="$DST_ROOT/$lang_dir"
  dst="$dst_dir/5_APP_IPHONE_69_5.png"

  if [[ ! -f "$src" ]]; then
    echo "❌ MISSING: $src"
    errors=$((errors + 1))
    continue
  fi

  width=$(sips -g pixelWidth "$src" | awk '/pixelWidth/ {print $2}')
  height=$(sips -g pixelHeight "$src" | awk '/pixelHeight/ {print $2}')

  if [[ "$width" != "$REQUIRED_WIDTH" || "$height" != "$REQUIRED_HEIGHT" ]]; then
    echo "❌ SIZE ERROR: ${lang_key}_05_playlist.png → ${width}x${height}px (必要: ${REQUIRED_WIDTH}x${REQUIRED_HEIGHT})"
    errors=$((errors + 1))
    continue
  fi

  if $DRY_RUN; then
    echo "✅ OK: $lang_key → ${lang_dir}/5_APP_IPHONE_69_5.png (${width}x${height})"
  else
    mkdir -p "$dst_dir"
    cp "$src" "$dst"
    echo "✅ COPIED: ${lang_key}_05_playlist.png → fastlane/screenshots/${lang_dir}/5_APP_IPHONE_69_5.png"
  fi
  successes=$((successes + 1))
done

echo ""
echo "=== 結果: ${successes}言語成功 / ${errors}言語エラー ==="

if [[ $errors -gt 0 ]]; then
  echo ""
  echo "⚠️  エラーあり。エンジニアに ${REQUIRED_WIDTH}x${REQUIRED_HEIGHT}px での再生成を依頼してください。"
  exit 1
fi

if $DRY_RUN; then
  echo ""
  echo "チェック通過。実際に配置するには:"
  echo "  ./scripts/place_screenshot5.sh --apply"
  echo ""
  echo "配置後のアップロード:"
  echo "  bundle exec fastlane upload_screenshots"
fi
