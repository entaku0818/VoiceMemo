#!/bin/bash
# ScreenshotRenderTests が /tmp/voilog_screenshots/<code>/ に書き出した PNG を
# fastlane/screenshots/<App Store Connect のロケール>/ へコピーする。
#
# 使い方:
#   ios/ci/export_screenshots.sh              # コピーする
#   ios/ci/export_screenshots.sh --dry-run    # 何をコピーするか表示するだけ
#   SRC_DIR=... DEST_DIR=... ios/ci/export_screenshots.sh   # 入出力先を変える（検証用）
#
# 先にレンダリングしておくこと:
#   xcodebuild test -project ios/VoiLog.xcodeproj -scheme VoiLogTests \
#     -destination 'platform=iOS Simulator,id=<UDID>' -only-testing:VoiLogTests/ScreenshotRenderTests
#
# 守るもの（承認済みの実機キャプチャ版ヒーロー。絶対に上書きしない）:
#   ja/0_APP_IPHONE_67_0.png
#   en-US/0_APP_IPHONE_67_0.png（en-GB / en-CA / en-AU の 0 枚目には en-US の承認版をコピーする）
set -euo pipefail

cd "$(dirname "$0")/../.."

SRC_DIR=${SRC_DIR:-/tmp/voilog_screenshots}
DEST_DIR=${DEST_DIR:-fastlane/screenshots}
DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
fi

HERO=0_APP_IPHONE_67_0.png
APPROVED_EN_HERO="$DEST_DIR/en-US/$HERO"

# 言語コード（ScreenshotStrings/<code>.json）→ App Store Connect のロケール（空白区切り）
asc_locales() {
  case "$1" in
    en) echo "en-US en-GB en-CA en-AU" ;;
    es) echo "es-ES es-MX" ;;
    fr) echo "fr-FR fr-CA" ;;
    de) echo "de-DE" ;;
    nl) echo "nl-NL" ;;
    ar) echo "ar-SA" ;;
    nb) echo "no" ;;
    pt-BR) echo "pt-BR" ;;
    # App Store Connect は以下の言語だけ地域付きのロケール名（fastlane/metadata/ のフォルダ名と同じ）
    bn) echo "bn-BD" ;;
    gu) echo "gu-IN" ;;
    kn) echo "kn-IN" ;;
    ml) echo "ml-IN" ;;
    mr) echo "mr-IN" ;;
    or) echo "or-IN" ;;
    pa) echo "pa-IN" ;;
    sl) echo "sl-SI" ;;
    ta) echo "ta-IN" ;;
    te) echo "te-IN" ;;
    ur) echo "ur-PK" ;;
    *) echo "$1" ;;
  esac
}

# 承認済みヒーローなど、レンダリング結果で上書きしてはいけないファイルか
is_protected() {
  local locale=$1 file=$2
  [ "$file" = "$HERO" ] || return 1
  case "$locale" in
    ja | en-US | en-GB | en-CA | en-AU) return 0 ;;
    *) return 1 ;;
  esac
}

copy() {
  local src=$1 dest=$2
  if [ "$DRY_RUN" = 1 ]; then
    echo "copy  $src -> $dest"
  else
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
  fi
}

if [ ! -d "$SRC_DIR" ]; then
  echo "error: $SRC_DIR がありません。先に ScreenshotRenderTests を実行してください" >&2
  exit 1
fi

copied=0
skipped=0
for lang_dir in "$SRC_DIR"/*/; do
  code=$(basename "$lang_dir")
  case "$code" in _*) continue ;; esac # _extra など出荷しない描画
  for locale in $(asc_locales "$code"); do
    for src in "$lang_dir"*.png; do
      [ -e "$src" ] || continue
      file=$(basename "$src")
      dest="$DEST_DIR/$locale/$file"
      if is_protected "$locale" "$file"; then
        if [ "$locale" != "en-US" ] && [ "$locale" != "ja" ] && [ -f "$APPROVED_EN_HERO" ]; then
          copy "$APPROVED_EN_HERO" "$dest"
          copied=$((copied + 1))
        else
          echo "keep  ${dest} (approved hero, never overwritten)"
          skipped=$((skipped + 1))
        fi
        continue
      fi
      copy "$src" "$dest"
      copied=$((copied + 1))
    done
  done
done

echo "done: copied=$copied kept=$skipped (dest=$DEST_DIR)"
