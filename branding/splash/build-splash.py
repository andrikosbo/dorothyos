#!/usr/bin/env python3
"""build-splash.py OUTDIR — generates the DorothyOS boot-splash assets (rotation-proof: orange ring + light-orange spinner arc, no text, no white disc).
  ring.png           1024x1024  static mark (the orange ring only) on transparent
  arc-00..23.png     1024x1024  spinner arc with a fading tail, one image per 15 degrees (transparent background)
  preview.png        approval preview (landscape 16:10 and portrait, three animation states)
Needs: rsvg-convert, python3 + PIL."""
import os, subprocess, sys, math
from PIL import Image, ImageDraw
out = sys.argv[1] if len(sys.argv) > 1 else "out"
os.makedirs(out, exist_ok=True)
ORANGE, LIGHT, INK, PAPER = "#fd6d00", "#fca95e", "#0d0d0f", "#ffffff"
FRAMES, R, SW = 24, 330.0, 22.0

def svg_to_png(svg, png, size=1024):
    p = png + ".svg"; open(p, "w").write(svg)
    subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), p, "-o", png], check=True); os.remove(p)

# the mark is the orange ring of the logo's "o" ONLY (no white disc: a white disc plus ring plus dark hole reads as an eye)
ring = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024"><path fill="{ORANGE}" fill-rule="evenodd"
d="M512,282a230,230 0 1,0 0.01,0zM512,384a128,128 0 1,1 -0.01,0z"/></svg>'''
svg_to_png(ring, f"{out}/ring.png")

def arc_frame(k, ss=3):
    """spinner arc with a smoothly fading tail, drawn as 1-degree annular sectors on a supersampled canvas (no seams)"""
    N = 1024 * ss
    c = N / 2
    lr = (int(LIGHT[1:3], 16), int(LIGHT[3:5], 16), int(LIGHT[5:7], 16))
    im = Image.new("RGBA", (N, N), lr + (0,))
    d = ImageDraw.Draw(im)
    head = -90 + k * (360 / FRAMES)
    r_in, r_out = (R - SW / 2) * ss, (R + SW / 2) * ss
    TAIL = 170
    for i in range(TAIL, -1, -1):                       # draw from the tail to the head so the head is on top
        a0, a1 = head - i - 0.6, head - i + 0.6
        alpha = int(255 * (1 - i / TAIL) ** 1.6)
        pts = []
        for a, r in ((a0, r_out), (a1, r_out), (a1, r_in), (a0, r_in)):
            pts.append((c + r * math.cos(math.radians(a)), c + r * math.sin(math.radians(a))))
        d.polygon(pts, fill=lr + (alpha,))
    hx, hy = c + R * ss * math.cos(math.radians(head)), c + R * ss * math.sin(math.radians(head))
    d.ellipse((hx - SW / 2 * ss, hy - SW / 2 * ss, hx + SW / 2 * ss, hy + SW / 2 * ss), fill=lr + (255,))
    return im.resize((1024, 1024), Image.LANCZOS)
for k in range(FRAMES):
    arc_frame(k).save(f"{out}/arc-{k:02d}.png", optimize=True)

# ---- approval preview
def screen(w, h, k):
    im = Image.new("RGB", (w, h), INK)
    s = int(min(w, h) * 0.42)
    r = Image.open(f"{out}/ring.png").convert("RGBA").resize((s, s), Image.LANCZOS)
    a = Image.open(f"{out}/arc-{k:02d}.png").convert("RGBA").resize((s, s), Image.LANCZOS)
    im.paste(r, ((w - s) // 2, (h - s) // 2), r); im.paste(a, ((w - s) // 2, (h - s) // 2), a)
    return im
sheet = Image.new("RGB", (2460, 1000), (236, 236, 238))
x = 30
for k in (0, 8, 17):
    sheet.paste(screen(780, 487, k), (x, 40)); x += 810
sx = 30
for k in (4, 12):
    sheet.paste(screen(300, 480, k), (sx, 540)); sx += 330
sheet.save(f"{out}/preview.png")
print("splash assets in", out)
