#!/usr/bin/env python3
"""add-os.py MASTER.svg OUT.svg [COLOR_PLACEHOLDER]
Appends a hand-built capital "OS" to the traced "dorothy" wordmark so that the logo reads "dorothyOS".
The letters are geometry (an ellipse ring and one S built from two elliptical arcs) drawn with the stroke weight, cap height
and baseline MEASURED from the traced letters (units = viewBox units of the master).  Measurements:
  baseline y=1373 (flat letters), cap top y=235 / O bottom y=1385 (round overshoot) — all relative to the viewBox origin (add vy), stem weight ~335, tracking ~55
  'y' right edge x = 476 + 6732 = 7208, original right padding 160."""
import re, sys
src, out = sys.argv[1:3]
col = sys.argv[3] if len(sys.argv) > 3 else "@BLACK@"
svg = open(src).read()
m = re.search(r'viewBox="([\d.\-]+) ([\d.\-]+) ([\d.\-]+) ([\d.\-]+)"', svg)
vx, vy, vw, vh = (float(g) for g in m.groups())
TOP, BOT = vy + 235.0, vy + 1385.0   # measured relative to the viewBox origin, converted to absolute units
H = BOT - TOP
CY = (TOP + BOT) / 2
Y_RIGHT, GAP_YO, GAP_OS, PAD = 7208.0, 80.0, 55.0, 160.0
# ---- O: ring (outer ellipse minus inner ellipse), stem weight 335
OW, OSTROKE = 1060.0, 335.0
ox0 = Y_RIGHT + GAP_YO
ocx, orx, ory = ox0 + OW / 2, OW / 2, H / 2
irx, iry = orx - OSTROKE, ory - OSTROKE * 0.98
def ell(cx, cy, rx, ry):
    return f"M{cx - rx:.1f},{cy:.1f}a{rx:.1f},{ry:.1f} 0 1,0 {2 * rx:.1f},0a{rx:.1f},{ry:.1f} 0 1,0 {-2 * rx:.1f},0z"
o_path = f'<path id="os-O" fill="{col}" fill-rule="evenodd" d="{ell(ocx, CY, orx, ory)}{ell(ocx, CY, irx, iry)}"/>'
# ---- S: one stroked centre line, two 250-degree elliptical arcs (point-symmetric), butt caps
SW, SSTROKE = 860.0, 312.0
sx0 = ox0 + OW + GAP_OS
scx = sx0 + SW / 2
rx = (SW - SSTROKE) / 2
ry = (H - SSTROKE) / 4
import math
ang = math.radians(40)        # terminal position on the bowl, measured from the horizontal
c1y, c2y = CY - ry, CY + ry   # centres of the upper and lower bowl
p0 = (scx + rx * math.cos(ang), c1y - ry * math.sin(ang))      # top terminal (right)
pm = (scx, CY)                                                  # junction
p2 = (scx - rx * math.cos(ang), c2y + ry * math.sin(ang))      # bottom terminal (left)
s_path = (f'<path id="os-S" fill="none" stroke="{col}" stroke-width="{SSTROKE:.0f}" stroke-linecap="butt" '
          f'd="M{p0[0]:.1f},{p0[1]:.1f}A{rx:.1f},{ry:.1f} 0 1,0 {pm[0]:.1f},{pm[1]:.1f}'
          f'A{rx:.1f},{ry:.1f} 0 1,1 {p2[0]:.1f},{p2[1]:.1f}"/>')
new_right = sx0 + SW + PAD
nvw = new_right - vx
svg = svg.replace(m.group(0), f'viewBox="{vx:g} {vy:g} {nvw:g} {vh:g}"')
svg = re.sub(r'width="\d+" height="(\d+)"', lambda mm: f'width="{int(nvw // 4)}" height="{mm.group(1)}"', svg, count=1)
svg = svg.replace("</svg>", f'<g id="os">{o_path}{s_path}</g>\n</svg>')
open(out, "w").write(svg)
print("OS added: viewBox width", nvw, "O x", ox0, "S x", sx0, "rx/ry", rx, ry)
