#!/usr/bin/env python3
"""星图 App 图标生成器 —— 与原生界面共用的墨色、香槟金轨道符号。

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
        # Conventional source-over blending preserves the mineral background.
        for offset, channel in enumerate((r, g, b)):
            buf[i + offset] = round((buf[i + offset] * (255 - a) + channel * a) / 255)

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
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * size)
            i = (y * size + x) * 4
            buf[i:i + 4] = bytes((int(20 + 16 * t), int(31 + 14 * t), int(29 + 12 * t), 255))

    cx, cy = size * 0.5, size * 0.5
    brass = (221, 195, 154, 255)
    radius = size * 0.275
    fill_ring(buf, size, cx, cy, radius, size * 0.012, brass)

    # A tilted orbit matches AstraMark, without bitmap assets or external fonts.
    angle = math.radians(35)
    cs, sn = math.cos(angle), math.sin(angle)
    rx, ry = size * 0.135, radius
    thickness = size * 0.008
    for y in range(int(size * 0.2), int(size * 0.8)):
        for x in range(int(size * 0.2), int(size * 0.8)):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            u, v = dx * cs + dy * sn, -dx * sn + dy * cs
            f = (u / rx) ** 2 + (v / ry) ** 2 - 1
            gradient = math.hypot(2 * u / rx ** 2, 2 * v / ry ** 2)
            distance = abs(f) / gradient if gradient else size
            cover = max(0, min(1, thickness / 2 + 0.5 - distance))
            if cover: put_pixel(buf, size, x, y, *brass[:3], round(190 * cover))

    # Four-point astroid, a precise geometric counterpart to the native sparkle.
    extent = size * 0.126
    for y in range(int(cy - extent - 1), int(cy + extent + 2)):
        for x in range(int(cx - extent - 1), int(cx + extent + 2)):
            value = abs((x + 0.5 - cx) / extent) ** (2 / 3) + abs((y + 0.5 - cy) / extent) ** (2 / 3)
            cover = max(0, min(1, (1 - value) * extent * 0.5 + 0.5))
            if cover: put_pixel(buf, size, x, y, *brass[:3], round(255 * cover))
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
