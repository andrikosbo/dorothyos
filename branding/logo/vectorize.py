#!/usr/bin/env python3
"""vectorize.py SRC.png OUT.svg — turns the supplied raster logo (transparent PNG: black 'doro', orange 'thy', light-orange chevron)
into a clean vector master with colour placeholders (@BLACK@ @ORANGE@ @LIGHT@).
  * the letters d o r t h y are traced with potrace (supersampled, smoothed, specks removed)
  * the ring 'o' and the chevron '>' are rebuilt as exact geometry (circles / polygon) measured from the raster
One-off tool; the committed result is dorothy-master.svg.   Needs: python3, PIL, numpy, potrace."""
import subprocess, sys, os, re, tempfile
import numpy as np
from PIL import Image

src, out = sys.argv[1:3]
im = Image.open(src).convert("RGBA")
a = np.asarray(im).astype(np.float32)
rgb, alpha = a[..., :3], a[..., 3] / 255.0
H, W = alpha.shape
palette = {"black": (0, 0, 0), "orange": (253, 109, 0), "light": (252, 169, 94)}
names = list(palette)
d = np.stack([((rgb - np.array(palette[n])) ** 2).sum(-1) for n in names], -1)
cls = d.argmin(-1)
# colour of partially transparent edge pixels is unreliable: take the class of the nearest opaque pixel
op = alpha > 0.98
cls = np.where(op, cls, -1)
for _ in range(4):
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        sh = np.roll(np.roll(cls, dy, 0), dx, 1)
        cls = np.where((cls == -1) & (sh != -1), sh, cls)
xs_all = np.arange(W)[None, :].repeat(H, 0)
ys_all = np.arange(H)[:, None].repeat(W, 1)

def bbox(mask):
    ys, xs = np.where(mask)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1

# ---- exact chevron
chev = (cls == 2) & (alpha > 0.5) & (xs_all < 320)
x0c, y0c, x1c, y1c = bbox(chev)
col = chev[:, x0c + 3]; rows = np.where(col)[0]
gaps = np.where(np.diff(rows) > 1)[0]
yA, yD = rows[0], rows[gaps[0]]; yC, yB = rows[gaps[0] + 1], rows[-1] + 1
yT = (y0c + y1c) / 2.0
xT = x1c
rowT = np.where(chev[int(round(yT))])[0]; xN = rowT.min()
chev_pts = [(x0c, yA), (xT, yT), (x0c, yB), (x0c, yC), (xN, yT), (x0c, yD + 1)]
# ---- exact ring 'o' (second o): black disc, orange ring, hole
win = (xs_all > 940) & (xs_all < 1190)
blk = (cls == 0) & (alpha > 0.5) & win
ora = (cls == 1) & (alpha > 0.5) & win & (xs_all < 1160)
bx0, by0, bx1, by1 = bbox(blk); ox0, oy0, ox1, oy1 = bbox(ora)
cx, cy = (bx0 + bx1) / 2, (by0 + by1) / 2
R = ((bx1 - bx0) + (by1 - by0)) / 4
Ro = ((ox1 - ox0) + (oy1 - oy0)) / 4
cxo, cyo = (ox0 + ox1) / 2, (oy0 + oy1) / 2
hole = (alpha < 0.5) & win & (((xs_all - cxo) ** 2 + (ys_all - cyo) ** 2) < (Ro * 0.9) ** 2)
hx0, hy0, hx1, hy1 = bbox(hole)
Rh = ((hx1 - hx0) + (hy1 - hy0)) / 4
print("ring o: centre", cx, cy, "R", R, "orange", Ro, (cxo, cyo), "hole", Rh)

# ---- traced letters (exclude chevron + ring o)
S = 4
body = ""
tmp = tempfile.mkdtemp()
for i, n in enumerate(("black", "orange")):
    m = ((cls == i) & (alpha > 0.0)).astype(np.float32) * alpha
    m[chev] = 0
    m[win & (xs_all < 1185)] = 0 if i == 0 else m[win & (xs_all < 1185)]
    if i == 1: m[(xs_all < 1185) & (xs_all > 940)] = 0
    big = Image.fromarray((m * 255).astype(np.uint8)).resize((W * S, H * S), Image.BICUBIC)
    bw = np.asarray(big) >= 128
    pbm = os.path.join(tmp, n + ".pbm"); Image.fromarray((~bw * 255).astype(np.uint8)).convert("1").save(pbm)
    svg = os.path.join(tmp, n + ".svg")
    subprocess.run(["potrace", "-s", "-t", "120", "-a", "1.25", "-O", "1.0", "-u", "1", "-o", svg, pbm], check=True)
    g = re.search(r"<g[^>]*>(.*?)</g>", open(svg).read(), re.S).group(1)
    g = re.sub(r"\s+", " ", g).strip()
    body += f'<g id="{n}-letters" transform="translate(0,{H * S}) scale(1,-1)" fill="@{n.upper()}@" stroke="none">{g}</g>\n'
# ---- assemble in output units (source pixels * S), crop to artwork
ys, xs = np.where(alpha > 0.04)
pad = 40
vx0, vy0, vx1, vy1 = (xs.min() - pad) * S, (ys.min() - pad) * S, (xs.max() + pad) * S, (ys.max() + pad) * S
def c(x, y): return f"{x * S:.1f},{y * S:.1f}"
def circ(cx, cy, r): return f"M{(cx - r) * S:.1f},{cy * S:.1f}a{r * S:.1f},{r * S:.1f} 0 1,0 {2 * r * S:.1f},0a{r * S:.1f},{r * S:.1f} 0 1,0 {-2 * r * S:.1f},0z"
extra = (f'<path id="ring-outer" fill="@BLACK@" fill-rule="evenodd" d="{circ(cx, cy, R)}{circ(cxo, cyo, Ro)}"/>\n'
         f'<path id="ring-orange" fill="@ORANGE@" fill-rule="evenodd" d="{circ(cxo, cyo, Ro)}{circ(cxo, cyo, Rh)}"/>\n'
         f'<polygon id="chevron" fill="@LIGHT@" points="{" ".join(c(*p) for p in chev_pts)}"/>\n')
vw, vh = vx1 - vx0, vy1 - vy0
svgout = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vx0} {vy0} {vw} {vh}" width="{vw // S}" height="{vh // S}">\n'
          f'{body}{extra}</svg>\n')
open(out, "w").write(svgout)
print("written", out, "viewBox", vx0, vy0, vw, vh)
