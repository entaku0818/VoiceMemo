#!/usr/bin/env bash
# 2枚目スクリーンショット（useCase）をfastlane/screenshots/に配置するスクリプト
# 使用前提: /tmp/voilog_screenshots/ の *_02_usecase.png が 1290x2796px で生成済みであること
#
# 使い方:
#   chmod +x scripts/place_screenshot2.sh
#   ./scripts/place_screenshot2.sh            # dry-run（コピーせず確認のみ）
#   ./scripts/place_screenshot2.sh --apply    # 実際にコピー実行

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="/tmp/voilog_screenshots"
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

echo "=== 2枚目スクリーンショット配置チェック ==="
$DRY_RUN && echo "[DRY RUN モード: --apply を付けると実際にコピーします]"
echo ""

for pair in "${LANG_PAIRS[@]}"; do
  lang_key="${pair%%:*}"
  lang_dir="${pair##*:}"

  src="$SRC_DIR/${lang_key}_02_usecase.png"
  dst_dir="$DST_ROOT/$lang_dir"
  dst="$dst_dir/2_APP_IPHONE_69_2.png"

  if [[ ! -f "$src" ]]; then
    echo "❌ MISSING: $src"
    errors=$((errors + 1))
    continue
  fi

  width=$(sips -g pixelWidth "$src" | awk '/pixelWidth/ {print $2}')
  height=$(sips -g pixelHeight "$src" | awk '/pixelHeight/ {print $2}')

  if [[ "$width" != "$REQUIRED_WIDTH" || "$height" != "$REQUIRED_HEIGHT" ]]; then
    echo "❌ SIZE ERROR: ${lang_key}_02_usecase.png → ${width}x${height}px (必要: ${REQUIRED_WIDTH}x${REQUIRED_HEIGHT})"
    errors=$((errors + 1))
    continue
  fi

  if $DRY_RUN; then
    echo "✅ OK: $lang_key → ${lang_dir}/2_APP_IPHONE_69_2.png (${width}x${height})"
  else
    mkdir -p "$dst_dir"
    cp "$src" "$dst"
    echo "✅ COPIED: ${lang_key}_02_usecase.png → fastlane/screenshots/${lang_dir}/2_APP_IPHONE_69_2.png"
  fi
  successes=$((successes + 1))
done

echo ""
echo "=== 結果: ${successes}言語成功 / ${errors}言語エラー ==="

if [[ $errors -gt 0 ]]; then
  echo ""
  echo "⚠️  エラーあり。/tmp/voilog_screenshots/ に ${REQUIRED_WIDTH}x${REQUIRED_HEIGHT}px ファイルがあるか確認してください。"
  exit 1
fi

if $DRY_RUN; then
  echo ""
  echo "チェック通過。実際に配置するには:"
  echo "  ./scripts/place_screenshot2.sh --apply"
fi
