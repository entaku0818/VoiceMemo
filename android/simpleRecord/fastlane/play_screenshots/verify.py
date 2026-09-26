#!/usr/bin/env python3
"""Google Play のスクリーンショット規格チェック（ja-JP phoneScreenshots）。

規格: JPEG または 24bit PNG（アルファなし）/ 各辺 320〜3840px / 長辺は短辺の2倍以下 / 8MB以下 / 2〜8枚
"""
import sys
from pathlib import Path

from PIL import Image

DIR = Path(__file__).resolve().parent.parent / "metadata" / "android" / "ja-JP" / "images" / "phoneScreenshots"


def main():
    files = sorted(p for p in DIR.iterdir() if p.suffix.lower() in (".png", ".jpg", ".jpeg"))
    errors = []
    if not 2 <= len(files) <= 8:
        errors.append(f"枚数 {len(files)} (2〜8枚)")
    for p in files:
        im = Image.open(p)
        w, h = im.size
        size = p.stat().st_size
        ok_fmt = (im.format == "PNG" and im.mode == "RGB") or im.format == "JPEG"
        ok_side = 320 <= min(w, h) and max(w, h) <= 3840
        ok_ratio = max(w, h) <= 2 * min(w, h)
        ok_size = size <= 8 * 1024 * 1024
        status = "OK" if all((ok_fmt, ok_side, ok_ratio, ok_size)) else "NG"
        print(f"{status} {p.name}: {w}x{h} {im.format}/{im.mode} {size / 1024:.0f}KB ratio={h / w:.3f}")
        if status == "NG":
            errors.append(p.name)
    if errors:
        print("FAILED:", ", ".join(errors))
        sys.exit(1)
    print(f"ALL OK ({len(files)} files)")


if __name__ == "__main__":
    main()
