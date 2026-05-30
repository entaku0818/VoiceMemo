#!/usr/bin/env python3
"""
シンプル録音 アルターネートアイコン生成スクリプト
黒背景を各カラーに置き換えて色違いアイコンを生成する
"""

from PIL import Image
import os

SOURCE = "VoiLog/Assets.xcassets/AppIcon.appiconset/1024.png"
OUTPUT_DIR = "VoiLog/Assets.xcassets"

COLORS = {
    "Blue":   (0,   102, 204),
    "Red":    (204,  0,   0),
    "Green":  (0,   153,  68),
    "Purple": (102,  0,  204),
    "Orange": (255, 102,  0),
    "Pink":   (204,  0,  102),
}

SIZES = [29, 40, 57, 58, 60, 80, 87, 114, 120, 180, 1024]

def recolor(src_path: str, color: tuple) -> Image.Image:
    img = Image.open(src_path).convert("RGBA")
    pixels = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            # 黒〜暗いピクセルを対象色に置換
            brightness = (r + g + b) / 3
            if brightness < 80:
                blend = brightness / 80  # 0(完全黒)→1(明るい端)
                nr = int(color[0] * (1 - blend) + r * blend)
                ng = int(color[1] * (1 - blend) + g * blend)
                nb = int(color[2] * (1 - blend) + b * blend)
                pixels[x, y] = (nr, ng, nb, a)
    return img

def generate():
    for name, rgb in COLORS.items():
        appiconset_dir = os.path.join(OUTPUT_DIR, f"AppIcon_{name}.appiconset")
        os.makedirs(appiconset_dir, exist_ok=True)

        base = recolor(SOURCE, rgb)

        files = {}
        for size in SIZES:
            filename = f"{size}.png"
            out_path = os.path.join(appiconset_dir, filename)
            base.resize((size, size), Image.LANCZOS).save(out_path)
            files[size] = filename

        # Contents.json 生成
        contents = generate_contents_json(files)
        with open(os.path.join(appiconset_dir, "Contents.json"), "w") as f:
            f.write(contents)

        print(f"✅ {name}: {appiconset_dir}")

    print("\n完了！")

def generate_contents_json(files: dict) -> str:
    images = [
        {"size": "20x20",   "scale": "2x", "filename": files[40]},
        {"size": "20x20",   "scale": "3x", "filename": files[60]},
        {"size": "29x29",   "scale": "1x", "filename": files[29]},
        {"size": "29x29",   "scale": "2x", "filename": files[58]},
        {"size": "29x29",   "scale": "3x", "filename": files[87]},
        {"size": "40x40",   "scale": "2x", "filename": files[80]},
        {"size": "40x40",   "scale": "3x", "filename": files[120]},
        {"size": "57x57",   "scale": "1x", "filename": files[57]},
        {"size": "57x57",   "scale": "2x", "filename": files[114]},
        {"size": "60x60",   "scale": "2x", "filename": files[120]},
        {"size": "60x60",   "scale": "3x", "filename": files[180]},
        {"size": "1024x1024", "scale": "1x", "idiom": "ios-marketing", "filename": files[1024]},
    ]

    entries = []
    for img in images:
        idiom = img.get("idiom", "iphone")
        filename = img["filename"]
        entries.append(
            f'    {{\n'
            f'      "filename" : "{filename}",\n'
            f'      "idiom" : "{idiom}",\n'
            f'      "scale" : "{img["scale"]}",\n'
            f'      "size" : "{img["size"]}"\n'
            f'    }}'
        )

    return (
        '{\n'
        '  "images" : [\n'
        + ',\n'.join(entries) + '\n'
        '  ],\n'
        '  "info" : {\n'
        '    "author" : "xcode",\n'
        '    "version" : 1\n'
        '  }\n'
        '}\n'
    )

if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    generate()
