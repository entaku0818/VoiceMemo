#!/usr/bin/env python3
"""Google Play 用スクリーンショット合成スクリプト（ja-JP）。

raw/ にあるエミュレータの実画面キャプチャ（1080x2400）に
背景グラデーション＋キャッチコピー＋端末フレームを合成し、
fastlane/metadata/android/ja-JP/images/phoneScreenshots/ に 1080x1920 (9:16) PNG を書き出す。

依存: Pillow / macOS 標準のヒラギノ角ゴシック
使い方: python3 fastlane/play_screenshots/compose.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
RAW = HERE / "raw"
OUT = HERE.parent / "metadata" / "android" / "ja-JP" / "images" / "phoneScreenshots"

W, H = 1080, 1920
FONT_HEAVY = "/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc"
FONT_BOLD = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"

WHITE = (255, 255, 255)
ACCENT = (255, 216, 77)
PILL_TEXT = (74, 50, 180)

# (出力名, 実画面, ラベル, キャッチ1行目, キャッチ2行目(アクセント色), 背景上端色, 背景下端色, 拡大カード領域)
SHOTS = [
    ("01_ai_transcription.png", "01_transcript.png", "AI文字起こし",
     "録音するだけで", "AIが文字起こし", (108, 76, 240), (40, 22, 110), (24, 596, 1056, 1430)),
    ("02_ai_minutes.png", "02_minutes.png", "AI議事録",
     "要約もTODOも", "自動でまとめる", (88, 70, 220), (30, 24, 96), None),
    ("03_recordings.png", "03_list.png", "録音一覧",
     "会議も講義も", "すぐに見つかる", (70, 88, 214), (24, 30, 92), None),
    ("04_playback.png", "04_playback.png", "再生",
     "倍速・区間リピートで", "聴き返しラクラク", (96, 64, 206), (34, 20, 88), None),
    ("05_presets.png", "05_settings.png", "録音設定",
     "用途別プリセットで", "音質設定もかんたん", (84, 72, 200), (28, 24, 84), None),
]


def gradient(top, bottom):
    img = Image.new("RGB", (W, H), top)
    px = ImageDraw.Draw(img)
    for y in range(H):
        t = y / (H - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        px.line([(0, y), (W, y)], fill=c)
    # 右上にやわらかい光
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((W - 620, -420, W + 380, 520), fill=90)
    glow = glow.filter(ImageFilter.GaussianBlur(160))
    img.paste(Image.new("RGB", (W, H), (255, 255, 255)), (0, 0), glow)
    return img


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius, fill=255)
    return m


def drop_shadow(canvas, box, radius, blur=40, offset=(0, 24), alpha=120):
    x0, y0, x1, y1 = box
    sh = Image.new("L", (W, H), 0)
    ImageDraw.Draw(sh).rounded_rectangle(
        (x0 + offset[0], y0 + offset[1], x1 + offset[0], y1 + offset[1]), radius, fill=alpha)
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    canvas.paste(Image.new("RGB", (W, H), (8, 4, 30)), (0, 0), sh)


def centered_text(draw, y, text, font, fill):
    w = draw.textlength(text, font=font)
    draw.text(((W - w) / 2, y), text, font=font, fill=fill)


def fit_font(draw, text, path, size, max_w):
    while size > 40:
        f = ImageFont.truetype(path, size)
        if draw.textlength(text, font=f) <= max_w:
            return f
        size -= 4
    return ImageFont.truetype(path, size)


def compose(out_name, raw_name, label, line1, line2, top, bottom, zoom_box):
    canvas = gradient(top, bottom)
    d = ImageDraw.Draw(canvas)

    # ラベル（ピル）
    pill_font = ImageFont.truetype(FONT_BOLD, 40)
    pw = d.textlength(label, font=pill_font) + 72
    px0 = (W - pw) / 2
    d.rounded_rectangle((px0, 96, px0 + pw, 168), 36, fill=WHITE)
    centered_text(d, 110, label, pill_font, PILL_TEXT)

    # キャッチコピー
    f1 = fit_font(d, line1, FONT_HEAVY, 92, W - 120)
    f2 = fit_font(d, line2, FONT_HEAVY, 112, W - 100)
    centered_text(d, 214, line1, f1, WHITE)
    centered_text(d, 336, line2, f2, ACCENT)

    # 端末フレーム（下端ははみ出させる）
    shot = Image.open(RAW / raw_name).convert("RGB")
    screen_w = 780
    screen_h = int(shot.height * screen_w / shot.width)
    shot = shot.resize((screen_w, screen_h), Image.LANCZOS)
    bezel = 22
    fx0 = (W - screen_w) // 2 - bezel
    fy0 = 540
    frame_box = (fx0, fy0, fx0 + screen_w + bezel * 2, fy0 + screen_h + bezel * 2)
    drop_shadow(canvas, frame_box, 96)
    d.rounded_rectangle(frame_box, 96, fill=(18, 18, 22))
    d.rounded_rectangle(frame_box, 96, outline=(70, 70, 80), width=3)
    canvas.paste(shot, (fx0 + bezel, fy0 + bezel), rounded_mask(shot.size, 76))

    # 1枚目: 文字起こし結果の要部を拡大カードで重ねて、検索結果サムネでも読めるようにする
    if zoom_box:
        src = Image.open(RAW / raw_name).convert("RGB").crop(zoom_box)
        card_w = 960
        card = src.resize((card_w, int(src.height * card_w / src.width)), Image.LANCZOS)
        cx0 = (W - card_w) // 2
        cy0 = 985
        cbox = (cx0, cy0, cx0 + card_w, cy0 + card.height)
        drop_shadow(canvas, cbox, 40, blur=36, offset=(0, 20), alpha=150)
        canvas.paste(card, (cx0, cy0), rounded_mask(card.size, 40))
        ImageDraw.Draw(canvas).rounded_rectangle(cbox, 40, outline=ACCENT, width=6)

    OUT.mkdir(parents=True, exist_ok=True)
    canvas.save(OUT / out_name, "PNG")
    return OUT / out_name


def main():
    for s in SHOTS:
        print(compose(*s))


if __name__ == "__main__":
    main()
