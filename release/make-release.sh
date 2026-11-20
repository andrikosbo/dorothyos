#!/bin/bash
# make-release.sh [VERSION] — turns dist/ (the build output) into release assets in release/out/ that fit GitHub's limits:
#   * every image is compressed with zstd (-19, long window) and, if the result is larger than 1.9 GiB, split into numbered parts;
#   * a SHA256SUMS file covers the ORIGINAL images and manifests (so `flash.sh` can verify after you reassemble) and a second one covers
#     the published files (what you download);
#   * RELEASE_NOTES.md is generated from docs/ and the validation logs.
# Nothing is uploaded: publishing is a separate, manual step.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=${1:-$(sed -n 's/^pkgver=//p' overlay/dorothyos-branding/APKBUILD | head -1)}
OUT=release/out
LIMIT=$((1900 * 1024 * 1024))
command -v zstd >/dev/null || { echo "zstd is needed (brew install zstd / apk add zstd)"; exit 2; }
ls dist/dorothyos-"$VERSION"-*.sparse.img >/dev/null 2>&1 || { echo "no images for version $VERSION in dist/"; exit 2; }
for p in tianma csot; do
  grep -q '^VALIDATION PASSED' "tests/logs/validate-$p.log" 2>/dev/null || { echo "tests/logs/validate-$p.log has no 'VALIDATION PASSED': run tests/validate.sh first"; exit 2; }
done
rm -rf "$OUT"; mkdir -p "$OUT"
sh tests/audit.sh >/dev/null || { echo "tests/audit.sh fails: fix that first"; exit 2; }
for p in tianma csot; do
  n=dorothyos-$VERSION-$p
  echo "== $n"
  # the checksum file of the build (covers the uncompressed image) is published as it is
  cp "dist/$n.SHA256SUMS" "dist/$n.packages.txt" "dist/$n.boot-entries.txt" "$OUT/"
  zstd -T0 -19 --long=27 -q -f -o "$OUT/$n.sparse.img.zst" "dist/$n.sparse.img"
  sz=$(stat -f %z "$OUT/$n.sparse.img.zst" 2>/dev/null || stat -c %s "$OUT/$n.sparse.img.zst")
  if [ "$sz" -gt "$LIMIT" ]; then
    split -b $LIMIT -d -a 2 "$OUT/$n.sparse.img.zst" "$OUT/$n.sparse.img.zst.part"
    rm "$OUT/$n.sparse.img.zst"
    echo "   split into $(ls "$OUT/$n.sparse.img.zst.part"* | wc -l | tr -d ' ') parts"
  fi
done
cat > "$OUT/REASSEMBLE.txt" <<TXT
DorothyOS $VERSION — how to get the image back from the release files
1. download every file of YOUR panel (tianma or csot), nothing from the other panel;
2. if there are '*.sparse.img.zst.partNN' files:   cat dorothyos-$VERSION-<panel>.sparse.img.zst.part* > dorothyos-$VERSION-<panel>.sparse.img.zst
3. zstd -d --long=27 dorothyos-$VERSION-<panel>.sparse.img.zst        (gives dorothyos-$VERSION-<panel>.sparse.img)
4. sha256sum -c dorothyos-$VERSION-<panel>.SHA256SUMS                  (macOS: shasum -a 256 -c ...)
5. flash with flash/flash.sh — read docs/INSTALL.md first.
TXT
# release notes from the template + the real validation result lines
val=""
for p in tianma csot; do val="$val* \`$p\`: $(grep '^RESULT' "tests/logs/validate-$p.log" | sed 's/^RESULT [^:]*: //') — $(grep '^VALIDATION' "tests/logs/validate-$p.log")
"; done
python3 - "$VERSION" "$val" > "$OUT/RELEASE_NOTES.md" <<'PY'
import sys
v, val = sys.argv[1:3]
print(open("release/RELEASE_NOTES.template.md").read().replace("@VERSION@", v).replace("@VALIDATION@", val.rstrip()))
PY
# firmware notices: the redistribution licences of the firmware inside the images must accompany them (docs/FIRMWARE.md)
{
  cat docs/FIRMWARE.md
  for f in docs/firmware-licenses/*; do
    case "$f" in *README.md) continue ;; esac
    printf '\n\n================================================================================\n%s\n================================================================================\n\n' "$(basename "$f")"
    cat "$f"
  done
} > "$OUT/FIRMWARE-NOTICES.txt"
( cd "$OUT" && { shasum -a 256 dorothyos-* REASSEMBLE.txt FIRMWARE-NOTICES.txt 2>/dev/null || sha256sum dorothyos-* REASSEMBLE.txt FIRMWARE-NOTICES.txt; } | grep -v 'SHA256SUMS$' > DOWNLOAD.SHA256SUMS )
ls -la "$OUT"
echo "release assets in $OUT (nothing uploaded)"
