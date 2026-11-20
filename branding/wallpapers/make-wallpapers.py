#!/usr/bin/env python3
"""make-wallpapers.py OUTDIR — generates the DorothyOS wallpaper set (own artwork, CC0): smooth gradient fields in the brand
colours with the ring motif.  2880x1800 JPEGs.  Needs numpy + PIL (the build container has both).  Deterministic (fixed seed)."""
import os, sys
import numpy as np
from PIL import Image
out = sys.argv[1] if len(sys.argv) > 1 else "wallpapers"
os.makedirs(out, exist_ok=True)
W, H = 2880, 1800
rng = np.random.default_rng(20261119)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
INK, ORANGE, LIGHT, ACCENT = (13, 13, 15), (253, 109, 0), (252, 169, 94), (232, 93, 0)

def rgb(c): return np.array(c, np.float32)
def vgrad(top, bottom):
    t = (yy / (H - 1))[..., None]
    return rgb(top) * (1 - t) + rgb(bottom) * t
def dgrad(a, b, angle=35):
    import math
    ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    t = ((xx * ca + yy * sa) / (W * ca + H * sa))[..., None]
    return rgb(a) * (1 - t) + rgb(b) * t
def glow(img, cx, cy, r, color, k=1.0, power=2.2):
    d = np.sqrt((xx - cx * W) ** 2 + (yy - cy * H) ** 2) / (r * H)
    a = np.clip(1 - d, 0, 1) ** power * k
    return img * (1 - a[..., None]) + rgb(color) * a[..., None]
def rings(img, cx, cy, radii, width, color, alpha):
    d = np.sqrt((xx - cx * W) ** 2 + (yy - cy * H) ** 2)
    for i, r in enumerate(radii):
        a = np.clip(1 - np.abs(d - r) / width, 0, 1)[..., None] * alpha * (1 - 0.12 * i)
        img = img * (1 - a) + rgb(color) * a
    return img
def save(name, img):
    img = img + rng.normal(0, 0.7, img.shape).astype(np.float32)          # dither: no banding
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(os.path.join(out, name), quality=90, optimize=True, subsampling=0)

save("ember-low.jpg",  glow(glow(vgrad((20, 18, 22), INK), .12, 1.08, 1.05, ORANGE, .95), .30, 1.15, .55, LIGHT, .35))
save("ember-high.jpg", glow(glow(vgrad(INK, (24, 20, 24)), .88, -.10, 1.0, ORANGE, .9), .72, -.18, .5, LIGHT, .3))
save("ring-night.jpg", rings(glow(vgrad((16, 16, 19), INK), .8, .5, .9, ACCENT, .28), .78, .5, [150, 300, 450, 600, 750, 900, 1050], 3.2, ORANGE, .55))
save("dusk.jpg",       glow(vgrad((26, 20, 36), (70, 28, 20)), .5, 1.25, 1.1, ORANGE, .85))
save("charcoal.jpg",   glow(vgrad((38, 38, 42), (18, 18, 21)), .5, 1.3, .8, ACCENT, .45))
save("sand.jpg",       glow(glow(vgrad((246, 242, 236), (232, 225, 216)), .1, -.05, .95, LIGHT, .85), .0, -.1, .5, ORANGE, .3))
save("paper-ring.jpg", rings(glow(vgrad((240, 240, 242), (222, 222, 226)), .8, .5, .8, LIGHT, .22), .78, .5, [200, 400, 600, 800, 1000], 4, ORANGE, .45))
save("ember-mid.jpg",  glow(dgrad((253, 120, 20), (28, 22, 24), 40), .9, 1.0, .7, INK, .25))
print("wallpapers in", out)
