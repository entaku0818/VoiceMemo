#!/usr/bin/env python3
"""Google Play 用タブレットスクリーンショット合成スクリプト（17ロケール）。

スマホ用 (compose.py) と同じ実画面キャプチャ・配色・文言を使い、
16:9 横長レイアウト（左にキャッチコピー、右に端末フレーム）で書き出す。

- tenInchScreenshots:   2560x1440（10インチ。各辺 1080px 以上が必要）
- sevenInchScreenshots: 1920x1080（10インチ版を縮小）

使い方: python3 fastlane/play_screenshots/compose_tablet.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

from compose import (FONT_BOLD, FONT_HEAVY, LOCALES as PHONE_LOCALES, SCREENS,
                     fit_font, selected_locales, locale_fonts, refined_background, place_device)

HERE = Path(__file__).resolve().parent
METADATA = HERE.parent / "metadata" / "android"

W, H = 2560, 1440
SEVEN_INCH = (1920, 1080)

# 左側のコピー領域と右側の端末の中心
TEXT_X0, TEXT_X1 = 140, 1280
PHONE_CX = 1900


def compose(raw_dir, raw_name, label, line1, line2):
    canvas = refined_background((W, H))
    draw = ImageDraw.Draw(canvas)
    text_center_x = 745
    max_width = 1120
    label_font = fit_font(draw, label, FONT_BOLD, 36, max_width)
    draw.text((text_center_x, 435), label, font=label_font, fill=(184, 175, 200), anchor="mt")
    f1 = fit_font(draw, line1, FONT_HEAVY, 102, max_width)
    f2 = fit_font(draw, line2, FONT_HEAVY, 114, max_width)
    draw.text((text_center_x, 555), line1, font=f1, fill=(250, 249, 252), anchor="mt")
    draw.text((text_center_x, 720), line2, font=f2, fill=(202, 185, 231), anchor="mt")
    place_device(canvas, raw_dir / raw_name, 1900, 110, 540)
    return canvas


def main():
    global FONT_HEAVY, FONT_BOLD
    for locale in selected_locales():
        conf = PHONE_LOCALES[locale]
        FONT_HEAVY, FONT_BOLD = locale_fonts(conf)
        raw_dir = HERE / "raw" / conf["raw"]
        ten_dir = METADATA / locale / "images" / "tenInchScreenshots"
        seven_dir = METADATA / locale / "images" / "sevenInchScreenshots"
        ten_dir.mkdir(parents=True, exist_ok=True)
        seven_dir.mkdir(parents=True, exist_ok=True)
        for i, ((out_name, raw_name, top, bottom), (label, line1, line2)) in enumerate(zip(SCREENS, conf["copy"])):
            img = compose(raw_dir, raw_name, label, line1, line2)
            img.save(ten_dir / out_name, "PNG")
            img.resize(SEVEN_INCH, Image.LANCZOS).save(seven_dir / out_name, "PNG")
            print(ten_dir / out_name)
            print(seven_dir / out_name)


if __name__ == "__main__":
    main()
