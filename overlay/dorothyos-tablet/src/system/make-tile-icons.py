#!/usr/bin/env python3
"""make-tile-icons.py SRC_DIR OUT_DIR — iPad-style home-screen icons for the Xiaomi Pad 6 (runs on the Mac).

Three styles are written, to OUT_DIR/<style>/{512,256}/pipa-tile-<name>.png:
  light  the default look described below
  dark   iOS "dark mode" icons: near-black plates, the app tile art keeps its glyph but its background colour is darkened
  glass  translucent icons: frosted see-through plate, specular top edge and glass rim, glyphs stay solid

Every output is a 512x512 PNG (+ 256x256) with the same superellipse ("squircle") footprint and a soft drop shadow:
  * tool tiles  (keyboard, overview, close, controls): colour tile + vertical light, drawn here
  * everything else: light plate (white -> pale grey-blue) with the app's own icon at 68 %
SRC_DIR: <icon-name>.svg|png collected on the tablet. Requires rsvg-convert + Pillow.
"""
import io, os, subprocess, sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
C = 1024                      # supersampled canvas
S = int(C * 0.86)             # tile size (room for shadow)
OFF = (C - S) // 2
N = 5.0                       # superellipse exponent (iOS-like continuous corner)

def squircle_mask(size, n=N):
    m = Image.new("L", (size * 2, size * 2), 0)
    px = m.load(); r = size - 1
    import math
    # polygon of the superellipse, drawn at 2x for anti-aliasing
    pts = []
    for i in range(720):
        t = 2 * math.pi * i / 720
        c, s = math.cos(t), math.sin(t)
        x = (abs(c) ** (2 / n)) * (1 if c >= 0 else -1)
        y = (abs(s) ** (2 / n)) * (1 if s >= 0 else -1)
        pts.append((size + x * (size - 1), size + y * (size - 1)))
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return m.resize((size, size), Image.LANCZOS)

MASK = squircle_mask(S)

def rsvg(svg_bytes, px):
    r = subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px), "--keep-aspect-ratio", "-f", "png"], input=svg_bytes, capture_output=True, check=True)
    return Image.open(io.BytesIO(r.stdout)).convert("RGBA")

def load(path, px):
    if path.endswith(".svg"): return rsvg(open(path, "rb").read(), px)
    im = Image.open(path).convert("RGBA"); w, h = im.size; k = px / max(w, h)
    return im.resize((max(1, round(w * k)), max(1, round(h * k))), Image.LANCZOS)

def vgrad(size, top, bot):
    g = Image.new("RGBA", (size, size)); px = g.load()
    for y in range(size):
        t = y / (size - 1)
        col = tuple(round(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,)
        for x in range(size): px[x, y] = col
    return g

def finish(body, style="light"):
    """body: RGBA SxS tile art (unmasked). Mask, add top sheen, rim, shadow; return a 512 px canvas."""
    tile = Image.new("RGBA", (S, S), (0, 0, 0, 0)); tile.paste(body, (0, 0)); tile.putalpha(ImageChops.multiply(tile.getchannel("A"), MASK))
    glass = style == "glass"
    peak = {"light": 46, "dark": 30, "glass": 120}[style]
    sheen = Image.new("RGBA", (S, S), (255, 255, 255, 0)); sd = ImageDraw.Draw(sheen)
    for y in range(S // 2 if not glass else int(S * 0.55)):
        sd.line([(0, y), (S, y)], fill=(255, 255, 255, int(peak * (1 - y / ((S / 2) if not glass else (S * 0.55))) ** 2)))
    sheen.putalpha(ImageChops.multiply(sheen.getchannel("A"), MASK)); tile = Image.alpha_composite(tile, sheen)
    # rim: a thin light edge (dark mode / light mode: subtle; glass: bright at the top, fading to the bottom like a lit bevel)
    edge = ImageChops.subtract(MASK, MASK.filter(ImageFilter.MinFilter(9 if not glass else 13)))
    if glass:
        grad = Image.new("L", (S, S)); gp = grad.load()
        for y in range(S):
            v = int(235 * max(0.0, 1 - y / (S * 0.95)) ** 1.3 + 40)
            for x in range(S): gp[x, y] = min(255, v)
        ra = ImageChops.multiply(edge, grad)
    else:
        ra = edge.point(lambda v: v * (38 if style == "light" else 46) // 255)
    rim = Image.merge("RGBA", (Image.new("L", (S, S), 255),) * 3 + (ra,))
    tile = Image.alpha_composite(tile, rim)
    if glass:  # a faint dark hairline just outside the bevel so the glass reads on pale wallpapers
        out = ImageChops.subtract(MASK.filter(ImageFilter.MaxFilter(3)), MASK)
        hair = Image.merge("RGBA", (Image.new("L", (S, S), 0),) * 3 + (out.point(lambda v: v * 70 // 255),))
        tile = Image.alpha_composite(tile, hair)
    canvas = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    sh = Image.new("RGBA", (C, C), (0, 0, 0, 0)); m = Image.new("L", (C, C), 0); m.paste(MASK, (OFF, OFF + 18))
    amt = {"light": 120, "dark": 150, "glass": 70}[style]
    sa = m.filter(ImageFilter.GaussianBlur(20)).point(lambda v: v * amt // 255)
    if glass:  # keep the shadow out from under the see-through plate
        k = Image.new("L", (C, C), 0); k.paste(MASK, (OFF, OFF)); sa = ImageChops.multiply(sa, k.point(lambda v: 255 - v))
    sh.putalpha(sa)
    canvas = Image.alpha_composite(canvas, sh); canvas.alpha_composite(tile, (OFF, OFF))
    return canvas.resize((512, 512), Image.LANCZOS)

FONT = "Helvetica Neue, Arial, DejaVu Sans, sans-serif"
WEB = {  # name -> (top colour, bottom colour, inner svg in 256 box)
}
# dock / tool tiles (drawn here, no source file needed)
KB = '<g fill="#fff"><rect x="62" y="100" width="18" height="18" rx="4"/><rect x="92" y="100" width="18" height="18" rx="4"/><rect x="122" y="100" width="18" height="18" rx="4"/><rect x="152" y="100" width="18" height="18" rx="4"/><rect x="182" y="100" width="18" height="18" rx="4"/><rect x="76" y="128" width="18" height="18" rx="4"/><rect x="106" y="128" width="18" height="18" rx="4"/><rect x="136" y="128" width="18" height="18" rx="4"/><rect x="166" y="128" width="18" height="18" rx="4"/><rect x="84" y="156" width="88" height="16" rx="4"/></g><rect x="40" y="80" width="176" height="106" rx="16" fill="none" stroke="#fff" stroke-width="10"/>'
WEB["pipa-keyboard"] = ((0x56, 0x5f, 0x72), (0x2d, 0x33, 0x40), KB)
WEB["pipa-overview"] = ((0x5a, 0xa2, 0xff), (0x2d, 0x6b, 0xe0), '<rect x="48" y="70" width="116" height="88" rx="14" fill="none" stroke="#fff" stroke-width="11"/><rect x="92" y="100" width="116" height="88" rx="14" fill="#3a7fee" stroke="#fff" stroke-width="11"/>')
WEB["pipa-close"] = ((0xff, 0x77, 0x6b), (0xe0, 0x42, 0x38), '<path d="M86 86 L170 170 M170 86 L86 170" stroke="#fff" stroke-width="20" stroke-linecap="round"/>')
WEB["pipa-controls"] = ((0x8a, 0x7b, 0xff), (0x4c, 0x3f, 0xe0), '<g stroke="#fff" stroke-width="12" stroke-linecap="round"><path d="M62 92 H194 M62 128 H194 M62 164 H194"/></g><g fill="#fff" stroke="#4c3fe0" stroke-width="6"><circle cx="160" cy="92" r="19"/><circle cx="96" cy="128" r="19"/><circle cx="146" cy="164" r="19"/></g>')
TILE = set()   # apps that ship their own full-bleed tile art (none by default)
DARK_PLATE = {}   # icon name -> (top, bottom) plate colours that replace the light plate
SCALE = {"firefox": 0.72, "org.kde.dolphin": 0.74, "org.gnome.Weather": 0.76, "utilities-terminal": 0.70}

def bg_mask(art, edge, tol=34, soft=10):
    """255 where the tile art is (nearly) its flat background colour, fading to 0 on the glyph."""
    r, g, b, _ = art.split(); er, eg, eb = edge[:3]
    d = ImageChops.lighter(ImageChops.lighter(ImageChops.difference(r, Image.new("L", art.size, er)), ImageChops.difference(g, Image.new("L", art.size, eg))), ImageChops.difference(b, Image.new("L", art.size, eb)))
    return d.point(lambda v: 255 if v <= tol else max(0, 255 - (v - tol) * 255 // soft))

def darken(img, k):
    return Image.merge("RGBA", tuple(c.point(lambda v: int(v * k)) for c in img.split()[:3]) + (img.getchannel("A"),))

def lum(ic):
    """mean luminance (0..1) of the visible pixels of a glyph"""
    px = ic.convert("RGBA"); a = px.getchannel("A"); l = px.convert("L")
    tot = sum(a.getdata()); 
    return sum(p * q for p, q in zip(l.getdata(), a.getdata())) / (255.0 * tot) if tot else 0.5

def flip_value(ic):
    """dark glyph -> light glyph on a dark plate: invert HSV value, keep hue and alpha"""
    a = ic.getchannel("A"); h, sat, v = ic.convert("RGB").convert("HSV").split()
    rgb = Image.merge("HSV", (h, sat, v.point(lambda x: 255 - x))).convert("RGB")
    return Image.merge("RGBA", rgb.split() + (a,))

DARK_GRAD = ((0x3c, 0x3d, 0x44), (0x17, 0x18, 0x1c))
GLASS_ALPHA = 0.74            # background opacity of coloured tiles in the glass style
LIFT_DARK = {"preferences-system": 2.2, "utilities-terminal": 1.7}   # glyphs that are dark on dark plates: brightness lift for the dark style

def with_alpha(img, k):
    return Image.merge("RGBA", img.split()[:3] + (img.getchannel("A").point(lambda v: int(v * k)),))

def build(name, path, style):
    if name in TILE:
        art = load(path, S); edge = art.getpixel((S // 2, 6))
        body = Image.new("RGBA", (S, S), edge[:3] + (255,)); body.alpha_composite(art)
        if style == "light": return body
        m = bg_mask(body, edge)
        if style == "dark":
            return Image.composite(darken(body, 0.38), body, m)
        a = Image.composite(Image.new("L", (S, S), int(255 * GLASS_ALPHA)), Image.new("L", (S, S), 255), m)
        b = body.copy(); b.putalpha(a); return b
    if name in WEB:
        top, bot, inner = WEB[name]
        glyph = rsvg(('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">%s</svg>' % inner).encode(), S)
        if style == "dark":
            top = tuple(int(c * 0.42) for c in top); bot = tuple(int(c * 0.36) for c in bot)
        body = vgrad(S, top, bot)
        if style == "glass": body = with_alpha(body, GLASS_ALPHA)
        body.alpha_composite(glyph); return body
    ic = load(path, int(S * SCALE.get(name, 0.68)))
    if style == "light":
        top, bot = DARK_PLATE.get(name, ((0xff, 0xff, 0xff), (0xe3, 0xe8, 0xef)))
        body = vgrad(S, top, bot)
    elif style == "dark":
        body = vgrad(S, *DARK_GRAD)
    else:
        body = Image.new("RGBA", (S, S), (255, 255, 255, 0)); px = body.load()
        for y in range(S):
            t = y / (S - 1); al = int(255 * (0.56 - 0.26 * t))
            for x in range(S): px[x, y] = (255, 255, 255, al)
    if style == "dark" and name in LIFT_DARK: ic = Image.merge("RGBA", tuple(c.point(lambda v: min(255, int(v * LIFT_DARK[name]))) for c in ic.split()[:3]) + (ic.getchannel("A"),))
    if style == "glass":  # soft shadow under the glyph so pale glyphs stay readable on a pale wallpaper
        sh = Image.new("RGBA", (S, S), (0, 0, 0, 0)); g = Image.new("RGBA", ic.size, (0, 0, 0, 0)); g.putalpha(ic.getchannel("A").point(lambda v: v * 110 // 255))
        sh.alpha_composite(g, ((S - ic.width) // 2, (S - ic.height) // 2 + 10)); body.alpha_composite(sh.filter(ImageFilter.GaussianBlur(14)))
    body.alpha_composite(ic, ((S - ic.width) // 2, (S - ic.height) // 2))
    return body

STYLES = ("light", "dark", "glass")
only = os.environ.get("ONLY_STYLE")
made = []
names = {os.path.splitext(f)[0]: f for f in os.listdir(src) if f.endswith((".svg", ".png"))}
for k in WEB: names.setdefault(k, None)
for style in STYLES:
    if only and style != only: continue
    for sz in (512, 256): os.makedirs(os.path.join(out, style, str(sz)), exist_ok=True)
    for name in sorted(names):
        f = names[name]; path = os.path.join(src, f) if f else None
        img = finish(build(name, path, style), style)
        img.save(os.path.join(out, style, "512", "pipa-tile-%s.png" % name))
        img.resize((256, 256), Image.LANCZOS).save(os.path.join(out, style, "256", "pipa-tile-%s.png" % name)); made.append((style, name))
print("made %d tiles -> %s" % (len(made), out))
