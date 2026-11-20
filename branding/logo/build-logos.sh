#!/bin/sh
# build-logos.sh — renders the DorothyOS logo set from dorothyos-master-template.svg (placeholders @BLACK@ @ORANGE@ @LIGHT@).
# Pipeline: vectorize.py (one-off trace of the supplied artwork) -> master-dorothy-template.svg -> add-os.py -> dorothyos-master-template.svg
# Needs: rsvg-convert, python3 + PIL (the build container has both).  Usage: sh build-logos.sh OUTDIR
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-"$HERE/out"}
T="$HERE/dorothyos-master-template.svg"
mkdir -p "$OUT"

ORANGE='#fd6d00'     # brand orange (from the supplied artwork)
LIGHT='#fca95e'      # light orange (the chevron)
INK='#0d0d0f'        # near-black used for splash / icon tiles
PAPER='#ffffff'

paint() { sed -e "s/@BLACK@/$2/g" -e "s/@ORANGE@/$ORANGE/g" -e "s/@LIGHT@/$LIGHT/g" "$T" > "$OUT/$1.svg"; }
paint dorothyos-wordmark-light '#000000'      # for light backgrounds
paint dorothyos-wordmark-dark  "$PAPER"       # for dark backgrounds

# --- symbol: the ring "o" as a perfectly concentric mark (outer disc, orange ring, hole)
# geometry in a 1024 grid:  outer R=455 · orange ring R=245 · hole R=133  (measured from the artwork, 4x supersampled)
sym() { # name disc-colour hole-colour background(optional tile colour)
  tile=""; [ -n "${4:-}" ] && tile="<rect width=\"1024\" height=\"1024\" rx=\"230\" fill=\"$4\"/>"
  cat > "$OUT/$1.svg" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
$tile<circle cx="512" cy="512" r="400" fill="$2"/>
<circle cx="512" cy="512" r="215" fill="$ORANGE"/>
<circle cx="512" cy="512" r="117" fill="$3"/>
</svg>
EOF
}
sym dorothyos-symbol        '#000000'  "$PAPER"  '#f3f3f5'  # app/distro icon: light tile, black disc, orange ring, white hole
sym dorothyos-symbol-light  '#000000'  "$PAPER"  ''          # bare mark for light backgrounds
sym dorothyos-symbol-onDark "$PAPER"   "$INK"    ''          # bare mark for dark backgrounds

# --- PNGs
for n in dorothyos-wordmark-light dorothyos-wordmark-dark; do rsvg-convert -w 1800 "$OUT/$n.svg" -o "$OUT/$n.png"; done
for s in 16 22 24 32 48 64 96 128 256 512; do rsvg-convert -w $s -h $s "$OUT/dorothyos-symbol.svg" -o "$OUT/symbol-$s.png"; done
echo "logo set written to $OUT"
