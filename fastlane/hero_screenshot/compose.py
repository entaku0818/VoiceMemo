#!/usr/bin/env python3
"""App Store 1枚目（ヒーロー）スクリーンショット合成スクリプト。

raw/<lang>/ のシミュレータ実画面（iPhone 17 Pro Max, 1320x2868）から、
6.9インチ用 1320x2868 の1枚目を案ごとに書き出す。

使い方:
  python3 fastlane/hero_screenshot/compose.py            # 全案を out/ に書き出し（採用は v5 = 白版）
依存: Pillow / macOS 標準のヒラギノ角ゴシック
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
W, H = 1320, 2868
FONT_HEAVY = "/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc"
FONT_BOLD = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"

WHITE = (255, 255, 255)
ACCENT = (255, 216, 77)
PURPLE = (92, 60, 230)
INK = (20, 18, 40)

COPY = {
    "ja": {
        "pill": "AI文字起こし",
        "v1": ("録音するだけで", "AIが文字起こし"),
        "v2": ("録音するだけで", "要約まで自動で"),
        "v3": ("録るだけで、", "文字になる。"),
        "badge": "要約つき",
        "before": "録音",
        "after": "文字起こし＋要約",
        "recorder": ("かんたん・きれいに", "録れるボイスレコーダー"),
        "recorder_pill": "シンプル録音",
        "chips": ["ワンタップ録音", "用途別の音質プリセット", "AI文字起こし"],
    },
    "en": {
        "recorder": ("Record clearly,", "simply."),
        "recorder_pill": "Simple Voice Recorder",
        "chips": ["One-tap recording", "Quality presets", "AI transcription"],
    },
}

# 実画面上の領域 (1320x2868 基準)
WAVE_BOX = (0, 480, 1320, 1590)  # 録音中画面の「録音中・タイマー・目盛り・波形」
SUMMARY_BOX = (0, 505, 1320, 978)
SEGMENTS_BOX = (24, 985, 1296, 2085)


def gradient(top, bottom, glow=True):
    img = Image.new("RGB", (W, H), top)
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / (H - 1)
        d.line([(0, y), (W, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    if glow:
        g = Image.new("L", (W, H), 0)
        ImageDraw.Draw(g).ellipse((W - 760, -520, W + 460, 640), fill=90)
        g = g.filter(ImageFilter.GaussianBlur(200))
        img.paste(Image.new("RGB", (W, H), WHITE), (0, 0), g)
    return img


def rounded_mask(size, r):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), r, fill=255)
    return m


def shadow(canvas, box, r, blur=50, off=(0, 30), alpha=120, color=(8, 4, 30)):
    x0, y0, x1, y1 = box
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).rounded_rectangle((x0 + off[0], y0 + off[1], x1 + off[0], y1 + off[1]), r, fill=alpha)
    canvas.paste(Image.new("RGB", (W, H), color), (0, 0), m.filter(ImageFilter.GaussianBlur(blur)))


def centered(d, y, text, font, fill):
    d.text(((W - d.textlength(text, font=font)) / 2, y), text, font=font, fill=fill)


def fit(d, text, path, size, max_w):
    while size > 40:
        f = ImageFont.truetype(path, size)
        if d.textlength(text, font=f) <= max_w:
            return f
        size -= 4
    return ImageFont.truetype(path, size)


def pill(d, y, text, bg, fg, size=50):
    f = ImageFont.truetype(FONT_BOLD, size)
    w = d.textlength(text, font=f) + 90
    x0 = (W - w) / 2
    d.rounded_rectangle((x0, y, x0 + w, y + size + 44), (size + 44) / 2, fill=bg)
    centered(d, y + 18, text, f, fg)


def phone(canvas, shot, x, y, screen_w, bezel=26, radius=120, dark=True):
    screen_h = int(shot.height * screen_w / shot.width)
    s = shot.resize((screen_w, screen_h), Image.LANCZOS)
    box = (x, y, x + screen_w + bezel * 2, y + screen_h + bezel * 2)
    shadow(canvas, box, radius)
    d = ImageDraw.Draw(canvas)
    d.rounded_rectangle(box, radius, fill=(18, 18, 22) if dark else (235, 235, 240))
    d.rounded_rectangle(box, radius, outline=(70, 70, 80), width=4)
    canvas.paste(s, (x + bezel, y + bezel), rounded_mask(s.size, radius - bezel))
    return box


def card(canvas, src, box, x, y, width, outline=ACCENT, r=48):
    c = src.crop(box)
    c = c.resize((width, int(c.height * width / c.width)), Image.LANCZOS)
    cbox = (x, y, x + width, y + c.height)
    shadow(canvas, cbox, r, blur=44, off=(0, 24), alpha=150)
    canvas.paste(c, (x, y), rounded_mask(c.size, r))
    ImageDraw.Draw(canvas).rounded_rectangle(cbox, r, outline=outline, width=8)
    return cbox


def load(lang, name):
    return Image.open(HERE / "raw" / lang / f"{name}.png").convert("RGB")


def v1(lang):
    """Android と同じ路線: 紫グラデ＋黄色アクセント＋文字起こし本文の拡大カード"""
    c = COPY[lang]
    img = gradient((108, 76, 240), (40, 22, 110))
    d = ImageDraw.Draw(img)
    pill(d, 130, c["pill"], WHITE, (74, 50, 180))
    l1, l2 = c["v1"]
    centered(d, 290, l1, fit(d, l1, FONT_HEAVY, 116, W - 140), WHITE)
    centered(d, 440, l2, fit(d, l2, FONT_HEAVY, 140, W - 120), ACCENT)
    tr = load(lang, "transcript")
    phone(img, tr, (W - 960) // 2 - 26, 700, 960)
    card(img, tr, SEGMENTS_BOX, 60, 1330, W - 120)
    return img


def v2(lang):
    """既存2〜8枚目の白基調に寄せる: 白背景＋紫アクセント＋「要約」を拡大して見せる"""
    c = COPY[lang]
    img = gradient((250, 248, 255), (232, 226, 255), glow=False)
    d = ImageDraw.Draw(img)
    pill(d, 130, c["pill"], PURPLE, WHITE)
    l1, l2 = c["v2"]
    centered(d, 290, l1, fit(d, l1, FONT_HEAVY, 116, W - 140), INK)
    centered(d, 440, l2, fit(d, l2, FONT_HEAVY, 140, W - 120), PURPLE)
    tr = load(lang, "transcript")
    phone(img, tr, (W - 960) // 2 - 26, 700, 960)
    cbox = card(img, tr, SUMMARY_BOX, 50, 1120, W - 100, outline=PURPLE)
    # 「要約つき」バッジ
    f = ImageFont.truetype(FONT_HEAVY, 52)
    t = c["badge"]
    bw = d.textlength(t, font=f) + 80
    bx, by = W - 60 - bw, cbox[1] - 50
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((bx, by, bx + bw, by + 96), 48, fill=ACCENT)
    d.text((bx + 40, by + 20), t, font=f, fill=INK)
    return img


def v3(lang):
    """ビフォー・アフター: 録音画面 → AI → 文字起こし＋要約"""
    c = COPY[lang]
    img = gradient((108, 76, 240), (40, 22, 110))
    d = ImageDraw.Draw(img)
    l1, l2 = c["v3"]
    centered(d, 150, l1, fit(d, l1, FONT_HEAVY, 124, W - 140), WHITE)
    centered(d, 310, l2, fit(d, l2, FONT_HEAVY, 150, W - 120), ACCENT)
    rec = load(lang, "recording").crop((0, 0, 1320, 1000))
    tr = load(lang, "transcript")
    # 左上: 録音画面（上部だけ切り出し）
    small_w = 560
    rs = rec.resize((small_w, int(rec.height * small_w / rec.width)), Image.LANCZOS)
    rbox = (70, 640, 70 + small_w, 640 + rs.height)
    shadow(img, rbox, 40)
    img.paste(rs, (70, 640), rounded_mask(rs.size, 40))
    lf = ImageFont.truetype(FONT_BOLD, 46)
    d = ImageDraw.Draw(img)
    d.text((70, 640 + rs.height + 24), c["before"], font=lf, fill=WHITE)
    # 矢印＋AIバッジ
    ax, ay = 820, 700
    d.polygon([(ax - 150, ay + 70), (ax - 60, ay + 110), (ax - 150, ay + 150)], fill=WHITE)
    d.ellipse((ax, ay, ax + 220, ay + 220), fill=ACCENT)
    af = ImageFont.truetype(FONT_HEAVY, 92)
    d.text((ax + 110 - d.textlength("AI", font=af) / 2, ay + 56), "AI", font=af, fill=INK)
    d.polygon([(ax + 60, ay + 260), (ax + 160, ay + 260), (ax + 110, ay + 350)], fill=WHITE)
    # 下: 文字起こし結果（要約＋本文）の大きいカード
    body = tr.crop((0, 505, 1320, 2085))
    bw = W - 120
    bs = body.resize((bw, int(body.height * bw / body.width)), Image.LANCZOS)
    by = 1180
    bbox = (60, by, 60 + bw, by + bs.height)
    shadow(img, bbox, 56, alpha=160)
    img.paste(bs, (60, by), rounded_mask(bs.size, 56))
    ImageDraw.Draw(img).rounded_rectangle(bbox, 56, outline=ACCENT, width=8)
    d = ImageDraw.Draw(img)
    d.text((60, bbox[3] + 28), c["after"], font=lf, fill=WHITE)
    return img


def chips(d, y, labels, bg, fg, size=40, gap=20):
    while True:
        f = ImageFont.truetype(FONT_BOLD, size)
        widths = [d.textlength(t, font=f) + 56 for t in labels]
        total = sum(widths) + gap * (len(labels) - 1)
        if total <= W - 140 or size <= 30:
            break
        size -= 2
    x = (W - total) / 2
    for t, w in zip(labels, widths):
        d.rounded_rectangle((x, y, x + w, y + size + 36), (size + 36) / 2, fill=bg)
        d.text((x + 28, y + 16), t, font=f, fill=fg)
        x += w + gap


def recorder(lang, dark_bg):
    """ボイスレコーダー訴求: 録音中の波形画面を主役にし、波形部分を拡大カードで見せる"""
    c = COPY[lang]
    if dark_bg:
        img = gradient((108, 76, 240), (40, 22, 110))
        text, accent, pill_bg, pill_fg, chip_bg, chip_fg, outline = WHITE, ACCENT, WHITE, (74, 50, 180), (255, 255, 255), (74, 50, 180), ACCENT
    else:
        img = gradient((250, 248, 255), (232, 226, 255), glow=False)
        text, accent, pill_bg, pill_fg, chip_bg, chip_fg, outline = INK, PURPLE, PURPLE, WHITE, (255, 255, 255), PURPLE, PURPLE
    d = ImageDraw.Draw(img)
    pill(d, 120, c["recorder_pill"], pill_bg, pill_fg)
    l1, l2 = c["recorder"]
    centered(d, 270, l1, fit(d, l1, FONT_HEAVY, 120, W - 140), text)
    centered(d, 420, l2, fit(d, l2, FONT_HEAVY, 124, W - 100), accent)
    chips(d, 600, c["chips"], chip_bg, chip_fg)
    rec = load(lang, "recording_wave")
    phone(img, rec, (W - 900) // 2 - 26, 760, 900)
    card(img, rec, WAVE_BOX, 50, 1110, W - 100, outline=outline)
    return img


def v4(lang):
    return recorder(lang, dark_bg=True)


def v5(lang):
    return recorder(lang, dark_bg=False)


VARIANTS = {"v4": v4, "v5": v5}


def main():
    out = HERE / "out"
    out.mkdir(exist_ok=True)
    for lang in COPY:
        for name, fn in VARIANTS.items():
            p = out / f"{lang}_{name}.png"
            fn(lang).save(p, "PNG")
            print(p)


if __name__ == "__main__":
    main()
