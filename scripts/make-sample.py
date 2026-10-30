"""Draws public/sample/sample.png and writes public/sample/sample.json.

The regions in sample.json are HAND-AUTHORED from the shapes drawn below. They are NOT model output.
The sample exists so the touch interface can be developed and demoed offline, without API credits.
"""
import base64
import json
import math
import os

from PIL import Image, ImageDraw

W, H = 800, 600
OUT = os.path.join(os.path.dirname(__file__), "..", "public", "sample")
os.makedirs(OUT, exist_ok=True)

SKY, SEA, ROCK, SNOW, SUN, CLOUD = (190, 222, 240), (24, 94, 160), (110, 104, 98), (245, 245, 245), (250, 196, 36), (252, 252, 252)

shapes = {}  # label -> function(draw, fill) that paints the shape

def sun(d, fill):
    d.ellipse((600, 50, 740, 190), fill=fill)

def cloud(d, fill):
    for box in [(150, 90, 290, 180), (230, 60, 390, 170), (330, 100, 470, 185), (180, 120, 440, 195)]:
        d.ellipse(box, fill=fill)

def mountain(d, fill):
    d.polygon([(330, 440), (520, 190), (710, 440)], fill=fill)

def sea(d, fill):
    d.rectangle((0, 440, W, H), fill=fill)

shapes = {"sun": (sun, SUN), "cloud": (cloud, CLOUD), "mountain": (mountain, ROCK), "sea": (sea, SEA)}

img = Image.new("RGB", (W, H), SKY)
d = ImageDraw.Draw(img)
for name in ["sun", "cloud", "mountain", "sea"]:
    fn, color = shapes[name]
    fn(d, color)
d.polygon([(480, 250), (520, 190), (560, 250), (535, 238), (520, 255), (500, 240)], fill=SNOW)  # snow cap, part of the mountain
# rain under the cloud (decorative, not a region)
for x in range(190, 440, 28):
    d.line((x, 205, x - 8, 245), fill=SEA, width=4)
img.save(os.path.join(OUT, "sample.png"))

text = {
    "sun": ("The sun, top right.", "The sun heats the sea. Warm water turns into invisible vapor and rises. The sun is what drives the whole water cycle."),
    "cloud": ("A cloud with rain falling from it.", "Vapor cools high in the air and gathers into drops, which form a cloud. When the drops get heavy they fall as rain."),
    "mountain": ("A mountain with a snowy peak.", "Rain and melting snow run down the mountain in streams. Gravity carries this water back toward the sea."),
    "sea": ("The sea, along the bottom.", "The sea holds most of the planet's water. It is where the cycle starts and where the streams end up."),
}
overview = (
    "A simple picture of the water cycle. The sun is at the top right, a cloud with rain is at the top left, "
    "a snowy mountain stands in the middle, and the sea fills the bottom."
)

regions = []
for order, name in enumerate(["sun", "cloud", "mountain", "sea"]):
    fn, _ = shapes[name]
    mask = Image.new("L", (W, H), 0)
    fn(ImageDraw.Draw(mask), 255)
    l, t, r, b = mask.getbbox()
    crop = mask.crop((l, t, r, b))
    w, h = crop.size
    scale = min(1.0, 96 / max(w, h))
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    small = crop.resize((nw, nh), Image.NEAREST)
    bits = bytes(1 if v > 127 else 0 for v in small.tobytes())
    area = sum(1 for v in crop.tobytes() if v > 127)
    spoken, detail = text[name]
    regions.append({
        "id": f"{name}-1", "order": order, "label": name, "spoken": spoken, "detail": detail,
        "box": [l, t, r, b], "mask": {"w": nw, "h": nh, "b64": base64.b64encode(bits).decode()},
        "area": area, "confidence": None,
    })

with open(os.path.join(OUT, "sample.json"), "w") as f:
    json.dump({
        "width": W, "height": H, "title": "The water cycle", "kind": "diagram", "overview": overview,
        "regions": regions, "skipped": [], "synthetic": True,
    }, f, indent=1)
print("wrote", OUT)
