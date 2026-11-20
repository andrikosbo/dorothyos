#!/usr/bin/env python3
"""make-assets.py — regenerates the images of the landing page from the artwork sources in this repository.

    python3 website/tools/make-assets.py          # needs Pillow (PIL); run from anywhere

Reads   branding/logo/dist/*  and  overlay/dorothyos-branding/src/wallpapers/*/contents/images/2880x1800.jpg
Writes  website/dorothyos/assets/img/*  (logos, favicons, Open Graph image, wallpaper previews and downloads)
Everything is the project's own artwork (see overlay/dorothyos-branding/src/ARTWORK-LICENSE.txt); no fonts or photographs are used.
"""
import glob, math, os, shutil
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
LOGO = ROOT / "branding/logo/dist"
WALLS = ROOT / "overlay/dorothyos-branding/src/wallpapers"
OUT = ROOT / "website/dorothyos/assets/img"
OUT.mkdir(parents=True, exist_ok=True)
(OUT / "wallpapers").mkdir(exist_ok=True)

INK, ORANGE = (13, 13, 15), (253, 109, 0)

# --- logos (vector copies) ------------------------------------------------------------------------------------------------
for src, dst in [("dorothyos-symbol.svg", "symbol.svg"), ("dorothyos-symbol-onDark.svg", "symbol-on-dark.svg"),
                 ("dorothyos-wordmark-dark.svg", "wordmark-on-dark.svg"), ("dorothyos-wordmark-light.svg", "wordmark-on-light.svg")]:
    shutil.copyfile(LOGO / src, OUT / dst)

# --- favicons / app icons -------------------------------------------------------------------------------------------------
tile = Image.open(LOGO / "symbol-512.png").convert("RGBA")
tile.resize((32, 32), Image.LANCZOS).save(OUT / "favicon-32.png", optimize=True)
flat = Image.new("RGBA", (512, 512), (243, 243, 245, 255)); flat.alpha_composite(tile)       # iOS wants an opaque square
flat.resize((180, 180), Image.LANCZOS).convert("RGB").save(OUT / "apple-touch-icon.png", optimize=True)
tile.save(OUT / "favicon.ico", sizes=[(16, 16), (32, 32), (48, 48)])

# --- rings (decorative background, vector) ---------------------------------------------------------------------------------
rings = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 1200" fill="none" stroke="#fd6d00">']
for i, r in enumerate([70, 150, 240, 340, 450, 570]):
    rings.append(f'<circle cx="600" cy="600" r="{r}" stroke-width="{2 if i < 4 else 1.5}" stroke-opacity="{0.55 - i * 0.07:.2f}"/>')
rings.append("</svg>")
(OUT / "rings.svg").write_text("\n".join(rings) + "\n")

# --- wallpapers: preview (480x300), hero (1280x800) and the full file for download ---------------------------------------------
for d in sorted(glob.glob(str(WALLS / "DorothyOS-*"))):
    name = os.path.basename(d).replace("DorothyOS-", "").lower()
    im = Image.open(os.path.join(d, "contents/images/2880x1800.jpg")).convert("RGB")
    im.resize((480, 300), Image.LANCZOS).save(OUT / "wallpapers" / f"{name}-thumb.jpg", quality=82, optimize=True, progressive=True)
    im.resize((1280, 800), Image.LANCZOS).save(OUT / "wallpapers" / f"{name}-1280.jpg", quality=84, optimize=True, progressive=True)
    shutil.copyfile(os.path.join(d, "contents/images/2880x1800.jpg"), OUT / "wallpapers" / f"{name}.jpg")

# --- Open Graph image 1200x630: wordmark on ink with the ring motif ----------------------------------------------------------
S = 2                                                          # supersample for smooth rings
W, H = 1200 * S, 630 * S
img = Image.new("RGB", (W, H), INK)
glow = Image.new("RGB", (W, H), INK)
gd = ImageDraw.Draw(glow)
cx, cy = int(W * 0.86), int(H * 0.52)
for k in range(60, 0, -1):                                    # soft orange glow behind the rings
    r = int(H * 0.95 * k / 60)
    t = (1 - k / 60) ** 2.2 * 0.55
    gd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=tuple(int(INK[j] * (1 - t) + ORANGE[j] * t) for j in range(3)))
img = glow.filter(ImageFilter.GaussianBlur(24 * S))
d = ImageDraw.Draw(img, "RGBA")
for i, r in enumerate([90, 170, 260, 360, 470, 590]):
    a = int(255 * (0.62 - i * 0.08))
    d.ellipse([cx - r * S, cy - r * S, cx + r * S, cy + r * S], outline=ORANGE + (a,), width=(3 if i < 4 else 2) * S)
wm = Image.open(LOGO / "dorothyos-wordmark-dark.png").convert("RGBA")
wm_w = 700 * S
wm = wm.resize((wm_w, int(wm.height * wm_w / wm.width)), Image.LANCZOS)
img = img.convert("RGBA")
img.alpha_composite(wm, (72 * S, (H - wm.height) // 2))
img.convert("RGB").resize((1200, 630), Image.LANCZOS).save(OUT / "og.png", optimize=True)

# --- boot splash, rendered with the layout of the Plymouth script (dorothyos.script): background #0d0d0f, ring = 42 % of the short side,
#     centred, with one frame of the turning arc.  The Pad 6 panel boots in portrait (1800x2880).  This is a render of the theme files,
#     not a photograph of the tablet.
THEME = ROOT / "overlay/dorothyos-branding/src/plymouth/dorothyos"
(OUT / "screens").mkdir(exist_ok=True)
W2, H2 = 1800, 2880
size = int(min(W2, H2) * 0.42)
sp = Image.new("RGBA", (W2, H2), (13, 13, 15, 255))
for name in ("ring.png", "arc-07.png"):
    layer = Image.open(THEME / name).convert("RGBA").resize((size, size), Image.LANCZOS)
    sp.alpha_composite(layer, ((W2 - size) // 2, (H2 - size) // 2))
sp.convert("RGB").resize((750, 1200), Image.LANCZOS).save(OUT / "screens" / "boot-splash.png", optimize=True)
print("assets written to", OUT)
