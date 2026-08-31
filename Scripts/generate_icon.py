#!/usr/bin/env python3
"""星图 App 图标生成器 —— 私密、抽象的双轨相遇符号。

用法（在 Astra 目录下）：
    python Scripts/generate_icon.py

产物：
    App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-{size}.png
    App/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json
"""
import json
import math
import os
import struct
import sys
import zlib

# ---------------------------------------------------------------- PNG 编码

def write_png(path, width, height, rgba):
    """rgba: bytes，长度 width*height*4，行序自顶向下。"""
    def chunk(tag, payload):
        raw = tag + payload
        return struct.pack(">I", len(payload)) + raw + struct.pack(">I", zlib.crc32(raw) & 0xFFFFFFFF)

    stride = width * 4
    raw = b"".join(b"\x00" + rgba[y * stride:(y + 1) * stride] for y in range(height))
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )
    with open(path, "wb") as f:
        f.write(png)

# ---------------------------------------------------------------- 画布

def make_canvas(size):
    return bytearray(size * size * 4)

def put_pixel(buf, size, x, y, r, g, b, a=255):
    if 0 <= x < size and 0 <= y < size:
        i = (y * size + x) * 4
        buf[i] = min(255, buf[i] + int(r * a / 255))
        buf[i + 1] = min(255, buf[i + 1] + int(g * a / 255))
        buf[i + 2] = min(255, buf[i + 2] + int(b * a / 255))

# ---------------------------------------------------------------- 画布转 8 位缓冲

def to_rgba(buf, size):
    out = bytearray(size * size * 4)
    for i in range(0, len(buf), 4):
        if buf[i + 3] == 0:
            continue
        a = buf[i + 3]
        out[i] = buf[i] * 255 // a
        out[i + 1] = buf[i + 1] * 255 // a
        out[i + 2] = buf[i + 2] * 255 // a
        out[i + 3] = a
    return bytes(out)

# ---------------------------------------------------------------- 几何

def fill_disc(buf, size, cx, cy, radius, color):
    r, g, b, a = color
    x0, x1 = max(0, int(cx - radius - 1)), min(size - 1, int(cx + radius + 1))
    y0, y1 = max(0, int(cy - radius - 1)), min(size - 1, int(cy + radius + 1))
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            cover = max(0.0, min(1.0, radius + 0.5 - d))
            if cover > 0:
                put_pixel(buf, size, x, y, r, g, b, int(a * cover))

def fill_ring(buf, size, cx, cy, radius, thickness, color):
    r, g, b, a = color
    x0, x1 = max(0, int(cx - radius - thickness)), min(size - 1, int(cx + radius + thickness))
    y0, y1 = max(0, int(cy - radius - thickness)), min(size - 1, int(cy + radius + thickness))
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            inner = max(0.0, min(1.0, (radius + thickness / 2) - d))
            outer = max(0.0, min(1.0, d - (radius - thickness / 2)))
            cover = min(inner, outer)
            if cover > 0:
                put_pixel(buf, size, x, y, r, g, b, int(a * cover))

# ---------------------------------------------------------------- 双线性缩放

def resize(src, src_size, dst_size):
    out = bytearray(dst_size * dst_size * 4)
    scale = src_size / dst_size
    for y in range(dst_size):
        sy = (y + 0.5) * scale - 0.5
        y0 = max(0, min(src_size - 1, int(math.floor(sy))))
        y1 = max(0, min(src_size - 1, y0 + 1))
        fy = sy - y0
        for x in range(dst_size):
            sx = (x + 0.5) * scale - 0.5
            x0 = max(0, min(src_size - 1, int(math.floor(sx))))
            x1 = max(0, min(src_size - 1, x0 + 1))
            fx = sx - x0
            di = (y * dst_size + x) * 4
            for c in range(4):
                p00 = src[(y0 * src_size + x0) * 4 + c]
                p10 = src[(y0 * src_size + x1) * 4 + c]
                p01 = src[(y1 * src_size + x0) * 4 + c]
                p11 = src[(y1 * src_size + x1) * 4 + c]
                top = p00 * (1 - fx) + p10 * fx
                bot = p01 * (1 - fx) + p11 * fx
                out[di + c] = int(top * (1 - fy) + bot * fy)
    return bytes(out)

# ---------------------------------------------------------------- 星点

def rng(seed):
    state = seed
    while True:
        state = (state * 6364136223846793005 + 1442695040888963407) & 0xFFFFFFFFFFFFFFFF
        yield (state >> 33) / float(1 << 31)

# ---------------------------------------------------------------- 主图

def render_icon(size):
    buf = make_canvas(size)

    # 夜色渐变：左上午夜紫 → 右下酒红
    for y in range(size):
        t = y / size
        for x in range(size):
            tt = (t + x / size) / 2
            r = int(12 + 24 * tt)
            g = int(8 + 2 * tt)
            b = int(34 + 12 * (1 - tt))
            i = (y * size + x) * 4
            buf[i] = r
            buf[i + 1] = g
            buf[i + 2] = b
            buf[i + 3] = 255

    # 星点
    gen = rng(0xA57A)
    for _ in range(76):
        x = next(gen) * size
        y = next(gen) * size
        radius = 0.7 + next(gen) * 1.8
        alpha = int(45 + next(gen) * 120)
        fill_disc(buf, size, x, y, radius, (255, 255, 255, alpha))

    # 交会光晕：紫与莓红各自成团，但在中心叠加。
    glow_r = size * 0.42
    fill_disc(buf, size, size * 0.39, size * 0.56, glow_r, (121, 56, 236, 34))
    fill_disc(buf, size, size * 0.66, size * 0.43, glow_r, (245, 64, 126, 34))

    # 两条轨道与两个相遇点。符号保持抽象，桌面上不暴露 App 用途。
    cx, cy = size * 0.5, size * 0.5
    outer_r = size * 0.245
    inner_r = size * 0.138
    fill_ring(buf, size, cx, cy, outer_r, size * 0.047, (255, 255, 255, 226))
    fill_ring(buf, size, cx, cy, inner_r, size * 0.024, (202, 158, 255, 178))

    angle_a = -0.66
    angle_b = math.pi - 0.66
    ax = cx + math.cos(angle_a) * outer_r
    ay = cy + math.sin(angle_a) * outer_r
    bx = cx + math.cos(angle_b) * outer_r
    by = cy + math.sin(angle_b) * outer_r

    fill_disc(buf, size, ax, ay, size * 0.065, (247, 68, 127, 255))
    fill_disc(buf, size, ax - size * 0.015, ay - size * 0.020, size * 0.021, (255, 221, 232, 150))
    fill_disc(buf, size, bx, by, size * 0.050, (151, 88, 246, 255))
    fill_disc(buf, size, bx - size * 0.011, by - size * 0.015, size * 0.016, (232, 215, 255, 140))

    # 中心的低调实心点让图标在小尺寸下仍有清晰焦点。
    fill_disc(buf, size, cx, cy, size * 0.042, (255, 255, 255, 220))

    return to_rgba(buf, size)

# ---------------------------------------------------------------- 入口

def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(root, "App", "Resources", "Assets.xcassets", "AppIcon.appiconset")
    os.makedirs(out_dir, exist_ok=True)

    base = render_icon(1024)
    write_png(os.path.join(out_dir, "AppIcon-1024.png"), 1024, 1024, base)

    for size in (120, 152, 167, 180):
        small = resize(base, 1024, size)
        write_png(os.path.join(out_dir, f"AppIcon-{size}.png"), size, size, small)

    contents = {
        "images": [
            {"filename": "AppIcon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
            {"filename": "AppIcon-120.png", "idiom": "iphone", "scale": "2x", "size": "60x60"},
            {"filename": "AppIcon-180.png", "idiom": "iphone", "scale": "3x", "size": "60x60"},
            {"filename": "AppIcon-152.png", "idiom": "ipad", "scale": "2x", "size": "76x76"},
            {"filename": "AppIcon-167.png", "idiom": "ipad", "scale": "2x", "size": "83.5x83.5"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    with open(os.path.join(out_dir, "Contents.json"), "w", encoding="utf-8") as f:
        json.dump(contents, f, ensure_ascii=False, indent=2)

    print(f"OK: {out_dir}")

if __name__ == "__main__":
    sys.exit(main())
