#!/usr/bin/env python3
"""pipa_dock_theme.py — writes a tiny Plasma desktop theme that only replaces the panel background.
   usage: pipa_dock_theme.py OUT_DIR NAME DOCK_ALPHA DOCK_RADIUS BAR_ALPHA [debug]
     DOCK_ALPHA / BAR_ALPHA  0..100 (% opacity of the panel background), DOCK_RADIUS corner radius in px (0 = square).
   The dock uses the "translucent" panel mode, the status bar the "adaptive" one (see pipa-dock), so the two get separate SVGs:
     translucent/widgets/panel-background.svg  = dock,   widgets/ and opaque/widgets/ = status bar.
   Everything else of the look falls back to the default (Breeze) theme and its colours (class ColorScheme-Background)."""
import json, os, sys

def panel_svg(variants, mask_radius):
    """variants: list of (prefix, radius, alpha, colour or None, left/right margin or None = from the radius, top/bottom margin). A prefix ("north-" top panel, "south-" bottom panel, "" any) gets its own frame
    (9-patch pieces + content margins), so the status bar and the dock can differ inside the same file. mask_radius: corner of the blur mask."""
    out = []
    X = 0
    maxh = 0
    def one(prefix, radius, alpha, color, ox, oy, ml=None, mt=3):
        c = max(int(radius), 1); e = 4; W = 2 * c + e
        fill = ('fill:%s;fill-opacity:%.3f' % (color, alpha)) if color else ('fill:currentColor;fill-opacity:%.3f' % alpha)
        cls = '' if color else ' class="ColorScheme-Background"'
        if ml is None: ml = max(4, int(round(radius * 0.5)))
        g = []
        def a(i, body): g.append('<g id="%s%s" transform="translate(%d,%d)">%s</g>' % (prefix, i, ox, oy, body))
        a("topleft",     '<path d="M0,%d A%d,%d 0 0 1 %d,0 L%d,%d Z" style="%s"%s/>' % (c, c, c, c, c, c, fill, cls))
        a("top",         '<rect x="%d" y="0" width="%d" height="%d" style="%s"%s/>' % (c, e, c, fill, cls))
        a("topright",    '<path d="M%d,0 A%d,%d 0 0 1 %d,%d L%d,%d Z" style="%s"%s/>' % (c + e, c, c, W, c, c + e, c, fill, cls))
        a("left",        '<rect x="0" y="%d" width="%d" height="%d" style="%s"%s/>' % (c, c, e, fill, cls))
        a("center",      '<rect x="%d" y="%d" width="%d" height="%d" style="%s"%s/>' % (c, c, e, e, fill, cls))
        a("right",       '<rect x="%d" y="%d" width="%d" height="%d" style="%s"%s/>' % (c + e, c, c, e, fill, cls))
        a("bottomleft",  '<path d="M0,%d A%d,%d 0 0 0 %d,%d L%d,%d Z" style="%s"%s/>' % (c + e, c, c, c, W, c, c + e, fill, cls))
        a("bottom",      '<rect x="%d" y="%d" width="%d" height="%d" style="%s"%s/>' % (c, c + e, e, c, fill, cls))
        a("bottomright", '<path d="M%d,%d A%d,%d 0 0 1 %d,%d L%d,%d Z" style="%s"%s/>' % (W, c + e, c, c, c + e, W, c + e, c + e, fill, cls))
        hx = ox + W + 12
        g.append('<rect id="%shint-left-margin" x="%d" y="%d" width="%d" height="4" style="fill:#f0f"/>' % (prefix, hx, oy, ml))
        g.append('<rect id="%shint-right-margin" x="%d" y="%d" width="%d" height="4" style="fill:#f0f"/>' % (prefix, hx, oy + 10, ml))
        g.append('<rect id="%shint-top-margin" x="%d" y="%d" width="4" height="%d" style="fill:#f0f"/>' % (prefix, hx + 40, oy, mt))
        g.append('<rect id="%shint-bottom-margin" x="%d" y="%d" width="4" height="%d" style="fill:#f0f"/>' % (prefix, hx + 60, oy, mt))
        return "".join(g), W
    Y = 0
    for (prefix, radius, alpha, color, ml, mt) in variants:
        body, W = one(prefix, radius, alpha, color, 0, Y, ml, mt)
        out.append(body); Y += W + 10
    mbody, MW = one("mask-", mask_radius, 1.0, "#000", 0, Y)
    out.append(mbody)
    H = Y + MW
    return ('<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" width="400" height="%d" viewBox="0 0 400 %d">'
            '<defs><style type="text/css" id="current-color-scheme">.ColorScheme-Background{color:#232629}</style></defs>%s</svg>\n' % (H, H, "".join(out)))

def write(out, name, dock_a, dock_r, bar_a, debug=False):
    for d in ("widgets", "translucent/widgets", "opaque/widgets"):
        os.makedirs(os.path.join(out, name, d), exist_ok=True)
    cd, cb, cp = ("#2e55ff", "#ff2e2e", "#2eff55") if debug else (None, None, None)
    svg = panel_svg([("south-", dock_r, dock_a / 100.0, cd, None, 3), ("north-", 0, bar_a / 100.0, cb, 10, 0), ("", dock_r, dock_a / 100.0, cp, None, 3)], dock_r)
    for d in ("widgets", "translucent/widgets", "opaque/widgets"):
        open(os.path.join(out, name, d, "panel-background.svg"), "w").write(svg)
    json.dump({"KPlugin": {"Id": name, "Name": name, "Description": "Panel background of the dock and the status bar (made by pipa-dock)",
                           "Authors": [{"Name": "pipa project"}], "License": "MIT", "Version": "1.0"},
               "X-Plasma-API-Minimum-Version": "6.0"}, open(os.path.join(out, name, "metadata.json"), "w"), indent=2)
    open(os.path.join(out, name, "plasmarc"), "w").write("[AdaptiveTransparency]\nenabled=true\n")

if __name__ == "__main__":
    out, name = sys.argv[1], sys.argv[2]
    write(out, name, float(sys.argv[3]), int(sys.argv[4]), float(sys.argv[5]), len(sys.argv) > 6)
