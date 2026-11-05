"""Regenerates docs/assets/*.png for the README. Run from the repo root:
    pip install playwright && playwright install chromium
    python tool/readme-assets/render.py
Phone frames wrap docs/screenshots/*.png, so refresh those first (see docs/screenshots/README.md)."""
import pathlib
from playwright.sync_api import sync_playwright
repo = pathlib.Path(__file__).resolve().parents[2]
here = repo / "tool" / "readme-assets"
out = repo / "docs" / "assets"
out.mkdir(exist_ok=True)
with sync_playwright() as p:
    b = p.chromium.launch(args=["--allow-file-access-from-files"])
    def shot(url, name, w, h, full=False, transparent=False):
        pg = b.new_page(viewport={"width": w, "height": h}, device_scale_factor=2)
        pg.goto(url); pg.wait_for_timeout(600)
        pg.screenshot(path=str(out / name), full_page=full, omit_background=transparent); pg.close()
    shot((here / "hero.html").as_uri(), "hero.png", 1600, 440)
    for n in ["01-home", "02-theme-low-vision", "03-chat", "04-lessons", "05-quiz"]:
        src = (repo / "docs" / "screenshots" / f"{n}.png").as_posix()
        shot(f"{(here / 'phone.html').as_uri()}?src={src}", f"phone-{n}.png", 460, 940, transparent=True)
    for d in ["how", "live"]:
        shot(f"{(here / 'diagram.html').as_uri()}?d={d}", f"{d}.png", 1600, 600, full=True)
    b.close()
