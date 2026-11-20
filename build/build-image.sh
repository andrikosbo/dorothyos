#!/bin/sh
# build-image.sh PANEL — builds the flashable DorothyOS image for one panel variant. Runs INSIDE the
# privileged Alpine edge container (build/build.sh starts it).  PANEL = tianma | csot  (see docs/PANELS.md: the two
# variants differ only in the kernel device tree; a Tianma image must not be flashed on a CSOT tablet and vice versa).
#
#   1. packages overlay/dorothyos-tablet (tablet UI + device support) and overlay/dorothyos-branding (identity, boot splash,
#      wallpapers, About page) as apks
#   2. pmbootstrap install  -> raw rootfs image (postmarketOS systemd-edge, KDE Plasma 6, device-xiaomi-pipa-kernel-<panel>)
#   3. build/postprocess.sh -> removes the throw-away build account, locks root, empties machine-id, writes the release
#                              file, package manifest, then converts to a sparse image for fastboot and writes SHA-256 sums
set -eu
PANEL=${1:?usage: build-image.sh tianma|csot}
case "$PANEL" in tianma|csot) ;; *) echo "panel must be tianma or csot"; exit 2 ;; esac
REPO=${REPO:-/repo}
WORK=${WORK:-/work}
export HOME=$WORK/home
PMW=$HOME/.local/var/pmbootstrap
OUT=${OUT:-$WORK/out}
VERSION=$(sed -n 's/^pkgver=//p' "$REPO/overlay/dorothyos-tablet/APKBUILD")
PMB="python3 $REPO/build/pmb-pinned.py --as-root --details-to-stdout"
mkdir -p "$OUT" "$OUT/logs"
LOG=$OUT/logs/build-$PANEL.log
say() { echo "[$(date +%T)] $*"; }

sh "$REPO/build/container-setup.sh"

say "pmbootstrap configuration ($PANEL)"
cfg() { $PMB config "$1" "$2" >/dev/null; }
# first run: create the pmaports checkout + config non-interactively
if [ ! -d "$PMW/cache_git/pmaports/.git" ]; then yes "" | $PMB init >/dev/null 2>&1 || true; fi
cfg device xiaomi-pipa
cfg kernel "$PANEL"
cfg ui plasma-desktop
cfg ui_extras True
cfg service_manager systemd
cfg hostname dorothyos
cfg locale en_US
cfg timezone UTC
cfg user user
cfg build_pkgs_on_install False
cfg boot_size 512
# apps of the image (same set as the reference tablet); build/packages.txt is the single list
EXTRA=$(sed 's/#.*//; s/^[[:space:]]*//; s/[[:space:]]*$//' "$REPO/build/packages.txt" | grep -v '^$' | paste -sd, -)
cfg extra_packages "$EXTRA"

say "1/3 apks: dorothyos-tablet + dorothyos-branding $VERSION"
build_apk() {   # NAME — overlay/NAME/{APKBUILD,NAME.*scriptlets,src/}
  n=$1; src=$REPO/overlay/$n
  v=$(sed -n 's/^pkgver=//p' "$src/APKBUILD")
  [ "$v" = "$VERSION" ] || { echo "version mismatch: $n has $v, expected $VERSION"; exit 1; }
  pk=$PMW/cache_git/pmaports/temp/$n
  rm -rf "$pk"; mkdir -p "$pk"
  cp -a "$src/APKBUILD" "$pk/APKBUILD"
  for f in "$src"/$n.*; do [ -f "$f" ] && cp -a "$f" "$pk/"; done
  python3 "$REPO/build/make-source-tarball.py" "$src/src" "$REPO/LICENSE" "$pk/$n-$v.tar.gz" "$n-$v"
  $PMB checksum "$n"
  $PMB build --force "$n"
}
build_apk dorothyos-tablet
build_apk dorothyos-branding

say "2/3 pmbootstrap install ($PANEL)  — log: $LOG"
# stale partition nodes of an earlier loop device would be "found" by pmbootstrap before the right ones exist: remove them
rm -f /dev/loop[0-9]*p[0-9]*
sh "$REPO/build/loop-partnodes.sh" & NODES=$!
trap 'kill $NODES 2>/dev/null || :' EXIT
# throw-away password: pmbootstrap insists on one; the account is deleted again by postprocess.sh
PW=$(head -c 24 /dev/urandom | base64 | tr -d '/+=' | cut -c1-20)
set +e
$PMB install --zap --no-sshd --no-split --no-sparse --password "$PW" --add dorothyos-tablet,dorothyos-branding > "$LOG" 2>&1
rc=$?
set -e
[ $rc -eq 0 ] || { echo "pmbootstrap install failed (exit $rc), see $LOG"; tail -15 "$LOG"; exit $rc; }
RAW=$PMW/chroot_native/home/pmos/rootfs/xiaomi-pipa.img
[ -f "$RAW" ] || { echo "image not found: $RAW"; exit 1; }

say "3/3 post-processing"
sh "$REPO/build/postprocess.sh" "$RAW" "$PANEL" "$VERSION" "$OUT"
say "done: $OUT"
