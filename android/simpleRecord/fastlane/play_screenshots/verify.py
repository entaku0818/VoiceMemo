#!/usr/bin/env python3
"""Google Play のスクリーンショット規格チェック（ja-JP / en-US）。

共通規格: JPEG または 24bit PNG（アルファなし）/ 長辺は短辺の2倍以下 / 8MB以下 / 2〜8枚
- phoneScreenshots / sevenInchScreenshots: 各辺 320〜3840px
- tenInchScreenshots: 各辺 1080〜7680px
タブレット用はディレクトリがあるロケールだけチェックする。
"""
import sys
from pathlib import Path

from PIL import Image

METADATA = Path(__file__).resolve().parent.parent / "metadata" / "android"
LOCALES = ("ja-JP", "en-US")
# 種別ごとの (短辺の下限, 長辺の上限, 必須か)
KINDS = {
    "phoneScreenshots": (320, 3840, True),
    "sevenInchScreenshots": (320, 3840, False),
    "tenInchScreenshots": (1080, 7680, False),
}


def check(locale, kind, errors):
    min_side, max_side, required = KINDS[kind]
    d = METADATA / locale / "images" / kind
    if not d.is_dir():
        if required:
            errors.append(f"{locale}/{kind}: ディレクトリなし")
        return 0
    files = sorted(p for p in d.iterdir() if p.suffix.lower() in (".png", ".jpg", ".jpeg"))
    print(f"[{locale} {kind}]")
    if not 2 <= len(files) <= 8:
        errors.append(f"{locale}/{kind}: 枚数 {len(files)} (2〜8枚)")
    for p in files:
        im = Image.open(p)
        w, h = im.size
        size = p.stat().st_size
        ok_fmt = (im.format == "PNG" and im.mode == "RGB") or im.format == "JPEG"
        ok_side = min_side <= min(w, h) and max(w, h) <= max_side
        ok_ratio = max(w, h) <= 2 * min(w, h)
        ok_size = size <= 8 * 1024 * 1024
        status = "OK" if all((ok_fmt, ok_side, ok_ratio, ok_size)) else "NG"
        print(f"{status} {p.name}: {w}x{h} {im.format}/{im.mode} {size / 1024:.0f}KB ratio={max(w, h) / min(w, h):.3f}")
        if status == "NG":
            errors.append(f"{locale}/{kind}/{p.name}")
    return len(files)


def main():
    errors = []
    total = sum(check(locale, kind, errors) for locale in LOCALES for kind in KINDS)
    if errors:
        print("FAILED:", ", ".join(errors))
        sys.exit(1)
    print(f"ALL OK ({total} files)")


if __name__ == "__main__":
    main()
