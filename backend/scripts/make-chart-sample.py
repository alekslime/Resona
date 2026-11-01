"""Draws sample/chart.png and writes sample/chart.json (pure stdlib, no PIL).

A 5-bar rainfall chart with HAND-AUTHORED rectangular regions. NOT model output.
The chart exists so the value-readout prototype ("slide along the bars, hear the
numbers") can be developed and demoed offline, without API credits.

Mirrors backend/scripts/make-sample.py: same JSON shape, same 96-cell mask cap.
"""
import base64
import binascii
import json
import os
import struct
import zlib

W, H = 800, 600
OUT = os.path.join(os.path.dirname(__file__), "..", "sample")
os.makedirs(OUT, exist_ok=True)

BG = (255, 255, 255)
INK = (20, 20, 20)
BAR_COLORS = [(36, 114, 200), (230, 126, 34), (46, 160, 67), (200, 60, 60), (128, 88, 200)]

# (month, millimetres)
BARS = [("January", 30), ("February", 55), ("March", 40), ("April", 80), ("May", 65)]

BASE_Y, TOP_Y = 500, 80
BAR_W = 90
STEP = 125
X0 = 115


def bar_rect(i, value):
    h = round(value / 80 * (BASE_Y - TOP_Y))
    x = X0 + i * STEP
    return (x, BASE_Y - h, x + BAR_W, BASE_Y)


def write_png(path, rows):
    """rows: list of bytes, each W*3 RGB. Filter 0, no interlace."""
    raw = b"".join(b"\x00" + r for r in rows)
    def chunk(typ, data):
        return struct.pack(">I", len(data)) + typ + data + struct.pack(">I", binascii.crc32(typ + data) & 0xFFFFFFFF)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))


def paint():
    rows = [bytearray(BG * W) for _ in range(H)]
    rects = [bar_rect(i, v) for i, (_, v) in enumerate(BARS)]
    for (l, t, r, b), color in zip(rects, BAR_COLORS):
        rgb = bytes(color)
        for y in range(t, b):
            row = rows[y]
            row[l * 3:r * 3] = rgb * (r - l)
    # axes: vertical line at x=80, horizontal baseline
    for y in range(TOP_Y, BASE_Y + 2):
        rows[y][80 * 3:82 * 3] = bytes(INK) * 2
    for y in range(BASE_Y, BASE_Y + 3):
        rows[y][80 * 3:740 * 3] = bytes(INK) * 660
    return [bytes(r) for r in rows], rects


def mask_b64(w, h):
    scale = min(1.0, 96 / max(w, h))
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    return nw, nh, base64.b64encode(bytes([1]) * nw * nh).decode()


TEXT = {
    "January": ("January: 30 millimetres of rain.",
                "January got 30 millimetres of rain, the least of these five months. Its bar is the shortest, about a third of April, the tallest."),
    "February": ("February: 55 millimetres of rain.",
                 "February got 55 millimetres of rain, almost twice January. Its bar is the middle height of the five."),
    "March": ("March: 40 millimetres of rain.",
              "March got 40 millimetres of rain, a drier month between two wetter ones. Its bar is the second shortest."),
    "April": ("April: 80 millimetres of rain.",
              "April got 80 millimetres of rain, the most of these five months. Its bar is the tallest — the one to compare the rest against."),
    "May": ("May: 65 millimetres of rain.",
            "May got 65 millimetres of rain, the second wettest month. Its bar is tall, but shorter than April."),
}

rows, rects = paint()
write_png(os.path.join(OUT, "chart.png"), rows)

regions = []
for order, ((month, value), (l, t, r, b)) in enumerate(zip(BARS, rects)):
    spoken, detail = TEXT[month]
    nw, nh, b64 = mask_b64(r - l, b - t)
    regions.append({
        "id": f"{month.lower()}-1", "order": order, "label": f"{month} bar",
        "spoken": spoken, "detail": detail, "box": [l, t, r, b],
        "mask": {"w": nw, "h": nh, "b64": b64},
        "area": (r - l) * (b - t), "confidence": None,
    })

with open(os.path.join(OUT, "chart.json"), "w") as f:
    json.dump({
        "width": W, "height": H, "title": "Spring rainfall",
        "kind": "chart",
        "overview": ("A bar chart of spring rainfall, January to May. Five bars stand on a flat line. "
                     "April is the tallest at 80 millimetres, January the shortest at 30."),
        "regions": regions, "skipped": [], "synthetic": True,
    }, f, indent=1)
print("wrote", OUT)
