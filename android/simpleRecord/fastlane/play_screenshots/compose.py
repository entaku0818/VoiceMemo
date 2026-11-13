#!/usr/bin/env python3
"""Google Play 用スクリーンショット合成スクリプト（17ロケール）。

raw/<lang>/ にあるエミュレータの実画面キャプチャ（1080x2400）に
背景グラデーション＋キャッチコピー＋端末フレームを合成し、
fastlane/metadata/android/<locale>/images/phoneScreenshots/ に 1080x1920 (9:16) PNG を書き出す。

依存: Pillow (libraqm有効) / macOS標準フォント
PLAY_SCREENSHOT_LOCALES=de-DE,fr-FR で対象を限定可能。
使い方: python3 fastlane/play_screenshots/compose.py
"""
from pathlib import Path
import json
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont, features

HERE = Path(__file__).resolve().parent
METADATA = HERE.parent / "metadata" / "android"

W, H = 1080, 1920
FONT_HEAVY = "/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc"
FONT_BOLD = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"

WHITE = (255, 255, 255)
ACCENT = (92, 60, 230)
INK = (20, 18, 40)
PILL_TEXT = (74, 50, 180)

# 画面ごとの共通設定: (出力名, 実画面, 背景上端色, 背景下端色)
SCREENS = [
    ("00_recording.png", "00_recording.png", (250, 248, 255), (232, 226, 255)),
    ("01_ai_transcription.png", "01_transcript.png", (250, 248, 255), (232, 226, 255)),
    ("02_ai_minutes.png", "02_minutes.png", (250, 248, 255), (232, 226, 255)),
    ("03_recordings.png", "03_list.png", (250, 248, 255), (232, 226, 255)),
    ("04_playback.png", "04_playback.png", (250, 248, 255), (232, 226, 255)),
    ("05_cloud_backup.png", "05_cloud.png", (250, 248, 255), (232, 226, 255)),
]

# ロケールごとの文言: (ラベル, キャッチ1行目, キャッチ2行目(アクセント色)) と文字起こし画像の拡大カード領域
LOCALES = {
    "ja-JP": {
        "raw": "ja",
        "zoom_box": (24, 480, 1056, 1120),
        "copy": [
            ("録音", "会議も講義も", "ワンタップで録音"),
            ("AI文字起こし", "録音するだけで", "AIが文字起こし"),
            ("AI議事録", "要約もTODOも", "自動でまとめる"),
            ("録音一覧", "会議も講義も", "すぐに見つかる"),
            ("再生", "倍速・区間リピートで", "聴き返しラクラク"),
            ("クラウドバックアップ", "Googleドライブに保存", "機種変更も安心"),
        ],
    },
    "en-US": {
        "raw": "en",
        "zoom_box": (24, 510, 1056, 1150),
        "copy": [
            ("Voice Recording", "Meetings & lectures", "Record with one tap"),
            ("AI Transcription", "Just hit record.", "AI writes it down"),
            ("AI Meeting Notes", "Summaries & to-dos", "done for you"),
            ("Recordings", "Meetings, lectures & more", "Find any in seconds"),
            ("Playback", "Speed control & A-B repeat", "Review with ease"),
            ("Cloud Backup", "Back up to Google Drive", "Keep recordings safe"),
        ],
    },
}


# The same localized sample data is consumed by the Android capture tests.
LOCALES.update(json.loads((HERE.parents[1] / "app/src/androidTest/assets/play-locales.json").read_text()))


def selected_locales():
    requested = os.environ.get("PLAY_SCREENSHOT_LOCALES")
    return requested.split(",") if requested else list(LOCALES)


def locale_fonts(conf):
    if conf.get("language") in ("ar", "hi-IN", "th") and not features.check("raqm"):
        raise RuntimeError("These scripts require a Pillow build with libraqm for correct text shaping.")
    if "font" in conf:
        path = "/System/Library/Fonts/" + conf["font"]
        return path, path
    return "/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc", "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"


def refined_background(size):
    width, height = size
    canvas = Image.new("RGB", size)
    draw = ImageDraw.Draw(canvas)
    top, bottom = (18, 20, 27), (37, 33, 47)
    for y in range(height):
        t = y / max(height - 1, 1)
        color = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        draw.line((0, y, width, y), fill=color)
    glow = Image.new("L", size, 0)
    ImageDraw.Draw(glow).ellipse((width * .1, height * .28, width * 1.1, height * 1.1), fill=40)
    glow = glow.filter(ImageFilter.GaussianBlur(width * .22))
    canvas.paste(Image.new("RGB", size, (122, 105, 153)), (0, 0), glow)
    return canvas


def place_device(canvas, raw_path, center_x, top, screen_width):
    shot = Image.open(raw_path).convert("RGB")
    height = round(shot.height * screen_width / shot.width)
    shot = shot.resize((screen_width, height), Image.Resampling.LANCZOS)
    bezel = max(12, round(screen_width * .022))
    radius = round(screen_width * .095)
    left = round(center_x - screen_width / 2 - bezel)
    box = (left, top, left + screen_width + bezel * 2, top + height + bezel * 2)
    shadow = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(shadow).rounded_rectangle((box[0], box[1] + 30, box[2], box[3] + 30), radius, fill=160)
    shadow = shadow.filter(ImageFilter.GaussianBlur(45))
    canvas.paste(Image.new("RGB", canvas.size, (0, 0, 0)), (0, 0), shadow)
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(box, radius, fill=(16, 17, 21), outline=(100, 98, 109), width=2)
    canvas.paste(shot, (left + bezel, top + bezel), rounded_mask(shot.size, radius - bezel))


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius, fill=255)
    return m


def fit_font(draw, text, path, size, max_w):
    while size > 20:
        f = ImageFont.truetype(path, size)
        if draw.textlength(text, font=f) <= max_w:
            return f
        size -= 4
    return ImageFont.truetype(path, size)


def compose(raw_dir, out_dir, out_name, raw_name, label, line1, line2):
    # Show one continuous app screen, without a floating magnification card.
    canvas = refined_background((W, H))
    draw = ImageDraw.Draw(canvas)
    label_font = fit_font(draw, label, FONT_BOLD, 30, W - 180)
    draw.text((W / 2, 86), label, font=label_font, fill=(184, 175, 200), anchor="mt")
    f1 = fit_font(draw, line1, FONT_HEAVY, 76, W - 160)
    f2 = fit_font(draw, line2, FONT_HEAVY, 88, W - 160)
    draw.text((W / 2, 170), line1, font=f1, fill=(250, 249, 252), anchor="mt")
    draw.text((W / 2, 282), line2, font=f2, fill=(202, 185, 231), anchor="mt")
    place_device(canvas, raw_dir / raw_name, W / 2, 444, 720)
    out_dir.mkdir(parents=True, exist_ok=True)
    canvas.save(out_dir / out_name, "PNG")
    return out_dir / out_name


def main():
    global FONT_HEAVY, FONT_BOLD
    for locale in selected_locales():
        conf = LOCALES[locale]
        FONT_HEAVY, FONT_BOLD = locale_fonts(conf)
        raw_dir = HERE / "raw" / conf["raw"]
        out_dir = METADATA / locale / "images" / "phoneScreenshots"
        for i, ((out_name, raw_name, top, bottom), (label, line1, line2)) in enumerate(zip(SCREENS, conf["copy"])):
            print(compose(raw_dir, out_dir, out_name, raw_name, label, line1, line2))


if __name__ == "__main__":
    main()
