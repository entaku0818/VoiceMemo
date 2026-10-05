#!/usr/bin/env python3
"""Google Play 用タブレットスクリーンショット合成スクリプト（en-US）。

スマホ用 (compose.py) と同じ実画面キャプチャ・配色・文言を使い、
16:9 横長レイアウト（左にキャッチコピー、右に端末フレーム）で書き出す。

- tenInchScreenshots:   2560x1440（10インチ。各辺 1080px 以上が必要）
- sevenInchScreenshots: 1920x1080（10インチ版を縮小）

ja-JP は Play 上にタブレット用スクショが無いので対象外（LOCALES に足せば生成できる）。

使い方: python3 fastlane/play_screenshots/compose_tablet.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

from compose import (ACCENT, FONT_BOLD, FONT_HEAVY, LOCALES as PHONE_LOCALES, PILL_TEXT, SCREENS,
                     WHITE, fit_font, rounded_mask)

HERE = Path(__file__).resolve().parent
METADATA = HERE.parent / "metadata" / "android"

W, H = 2560, 1440
SEVEN_INCH = (1920, 1080)
TARGET_LOCALES = ("en-US",)

# 左側のコピー領域と右側の端末の中心
TEXT_X0, TEXT_X1 = 140, 1280
PHONE_CX = 1900


def gradient(top, bottom):
    img = Image.new("RGB", (W, H), top)
    px = ImageDraw.Draw(img)
    for y in range(H):
        t = y / (H - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        px.line([(0, y), (W, y)], fill=c)
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((W - 1100, -700, W + 500, 700), fill=90)
    glow = glow.filter(ImageFilter.GaussianBlur(220))
    img.paste(Image.new("RGB", (W, H), WHITE), (0, 0), glow)
    return img


def drop_shadow(canvas, box, radius, blur=40, offset=(0, 24), alpha=120):
    x0, y0, x1, y1 = box
    sh = Image.new("L", (W, H), 0)
    ImageDraw.Draw(sh).rounded_rectangle(
        (x0 + offset[0], y0 + offset[1], x1 + offset[0], y1 + offset[1]), radius, fill=alpha)
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    canvas.paste(Image.new("RGB", (W, H), (8, 4, 30)), (0, 0), sh)


def text_center(draw, y, text, font, fill):
    w = draw.textlength(text, font=font)
    draw.text(((TEXT_X0 + TEXT_X1 - w) / 2, y), text, font=font, fill=fill)


def compose(raw_dir, raw_name, label, line1, line2, top, bottom, zoom_box):
    canvas = gradient(top, bottom)
    d = ImageDraw.Draw(canvas)
    max_w = TEXT_X1 - TEXT_X0

    # 1枚目は拡大カードを下に置くのでコピーを上寄せ、それ以外は縦中央
    ty = 230 if zoom_box else 440

    pill_font = ImageFont.truetype(FONT_BOLD, 52)
    pw = d.textlength(label, font=pill_font) + 96
    px0 = (TEXT_X0 + TEXT_X1 - pw) / 2
    d.rounded_rectangle((px0, ty, px0 + pw, ty + 94), 47, fill=WHITE)
    text_center(d, ty + 18, label, pill_font, PILL_TEXT)

    f1 = fit_font(d, line1, FONT_HEAVY, 112, max_w)
    f2 = fit_font(d, line2, FONT_HEAVY, 136, max_w)
    text_center(d, ty + 150, line1, f1, WHITE)
    text_center(d, ty + 300, line2, f2, ACCENT)

    # 端末フレーム（下端ははみ出させる）
    shot = Image.open(raw_dir / raw_name).convert("RGB")
    screen_w = 640
    screen_h = int(shot.height * screen_w / shot.width)
    shot = shot.resize((screen_w, screen_h), Image.LANCZOS)
    bezel = 20
    fx0 = PHONE_CX - screen_w // 2 - bezel
    fy0 = 130
    frame_box = (fx0, fy0, fx0 + screen_w + bezel * 2, fy0 + screen_h + bezel * 2)
    drop_shadow(canvas, frame_box, 84, blur=48, offset=(0, 28))
    d.rounded_rectangle(frame_box, 84, fill=(18, 18, 22))
    d.rounded_rectangle(frame_box, 84, outline=(70, 70, 80), width=3)
    canvas.paste(shot, (fx0 + bezel, fy0 + bezel), rounded_mask(shot.size, 66))

    # 1枚目: 文字起こし結果の要部を拡大カードでコピーの下に置く
    if zoom_box:
        src = Image.open(raw_dir / raw_name).convert("RGB").crop(zoom_box)
        card_w = 820
        card = src.resize((card_w, int(src.height * card_w / src.width)), Image.LANCZOS)
        cx0 = (TEXT_X0 + TEXT_X1 - card_w) // 2
        cy0 = ty + 500
        cbox = (cx0, cy0, cx0 + card_w, cy0 + card.height)
        drop_shadow(canvas, cbox, 40, blur=36, offset=(0, 20), alpha=150)
        canvas.paste(card, (cx0, cy0), rounded_mask(card.size, 40))
        ImageDraw.Draw(canvas).rounded_rectangle(cbox, 40, outline=ACCENT, width=6)

    return canvas


def main():
    for locale in TARGET_LOCALES:
        conf = PHONE_LOCALES[locale]
        raw_dir = HERE / "raw" / conf["raw"]
        ten_dir = METADATA / locale / "images" / "tenInchScreenshots"
        seven_dir = METADATA / locale / "images" / "sevenInchScreenshots"
        ten_dir.mkdir(parents=True, exist_ok=True)
        seven_dir.mkdir(parents=True, exist_ok=True)
        for i, ((out_name, raw_name, top, bottom), (label, line1, line2)) in enumerate(zip(SCREENS, conf["copy"])):
            zoom_box = conf["zoom_box"] if i == 0 else None
            img = compose(raw_dir, raw_name, label, line1, line2, top, bottom, zoom_box)
            img.save(ten_dir / out_name, "PNG")
            img.resize(SEVEN_INCH, Image.LANCZOS).save(seven_dir / out_name, "PNG")
            print(ten_dir / out_name)
            print(seven_dir / out_name)


if __name__ == "__main__":
    main()
