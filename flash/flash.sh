#!/bin/bash
# flash.sh — install a DorothyOS image on a Xiaomi Pad 6 (bootloader must already be UNLOCKED).
#
#   usage: flash.sh --panel tianma|csot --image IMAGE.sparse.img --uboot u-boot-xiaomi-pipa.img [--pin-boot-entry] [--serial SERIAL] [--yes]
#
#   --pin-boot-entry   patch the U-Boot you supply (a data-only edit of its default environment, tools/make-uboot-env-patch.py) so that
#                      it boots the DorothyOS image directly instead of scanning every disk for \EFI\BOOT\BOOTAA64.EFI. Use it when the
#                      tablet has ever run another Linux/bootloader (an old GRUB found first stops the tablet at "grub>"; seen on the
#                      reference tablet). The original file is not modified; the patched copy is flashed. See docs/BOOTLOADER.md.
#
# What it does (the same three steps as the postmarketOS builder's procedure, with guard rails):
#     fastboot erase dtbo_<slot>
#     fastboot flash boot_<slot> <U-Boot>
#     fastboot flash userdata <image>          <- THIS ERASES ALL DATA ON THE TABLET (Android + your files)
#     fastboot reboot
# What it never does: write persist / modem* / fsg / vbmeta* / vendor_boot* / super / firmware, set_active, relock, or touch the
# other slot. It refuses to run unless: product = pipa, bootloader unlocked, real bootloader fastboot (not fastbootd), one device,
# battery ok, image SHA-256 matches SHA256SUMS next to it, image fits userdata, the image name says the panel you asked for.
# Back up first (docs/ANDROID-ROLLBACK.md).  Flashing the WRONG panel variant is not verified to be harmless: use detect-panel.sh.
set -euo pipefail

PANEL=""; IMAGE=""; UBOOT=""; SERIAL=""; YES=0; PIN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --panel) PANEL=${2:-}; shift 2 ;;
    --image) IMAGE=${2:-}; shift 2 ;;
    --uboot) UBOOT=${2:-}; shift 2 ;;
    --pin-boot-entry) PIN=1; shift ;;
    --serial) SERIAL=${2:-}; shift 2 ;;
    --yes) YES=1; shift ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1"; exit 2 ;;
  esac
done
[ -n "$PANEL" ] && [ -n "$IMAGE" ] && [ -n "$UBOOT" ] || { sed -n '2,4p' "$0"; exit 2; }
case "$PANEL" in tianma|csot) ;; *) echo "--panel must be tianma or csot"; exit 2 ;; esac
command -v fastboot >/dev/null 2>&1 || { echo "fastboot not found (install android-platform-tools)"; exit 2; }
sha() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }
die() { echo "ABORT: $*" >&2; exit 1; }
log() { echo "[$(date +%T)] $*"; }

[ -f "$IMAGE" ] || die "image not found: $IMAGE"
[ -f "$UBOOT" ] || die "U-Boot image not found: $UBOOT (see docs/BOOTLOADER.md)"
case "$(basename "$IMAGE")" in *"-$PANEL.sparse.img") ;; *) die "the image file name does not end in -$PANEL.sparse.img: refusing to flash a panel variant you did not ask for" ;; esac

# --- optional: pin the EFI boot entry in a COPY of the U-Boot (before anything is written to the tablet)
if [ "$PIN" = 1 ]; then
  command -v python3 >/dev/null 2>&1 || die "--pin-boot-entry needs python3"
  command -v gzip >/dev/null 2>&1 || die "--pin-boot-entry needs gzip"
  TOOL="$(cd "$(dirname "$0")" && pwd)/tools/make-uboot-env-patch.py"
  [ -f "$TOOL" ] || die "patch tool not found: $TOOL"
  PINDIR=$(mktemp -d "${TMPDIR:-/tmp}/dorothyos-uboot.XXXXXX") || die "cannot create a temporary directory"
  trap 'rm -rf "$PINDIR"' EXIT
  log "--pin-boot-entry: patching a copy of $(basename "$UBOOT") (sha256 $(sha "$UBOOT"))"
  if ! python3 -I "$TOOL" "$UBOOT" "$PINDIR/u-boot-pinned.img" >"$PINDIR/tool.log" 2>&1; then
    tail -1 "$PINDIR/tool.log" | sed 's/^/    tool says: /'
    die "the patch tool does not recognise this U-Boot build (it only knows the layout described in docs/BOOTLOADER.md). Nothing was written. Flash without --pin-boot-entry, or use the build documented there."
  fi
  sed 's/^/    /' "$PINDIR/tool.log"
  UBOOT="$PINDIR/u-boot-pinned.img"
  log "patched U-Boot ready (sha256 $(sha "$UBOOT")); the original file is unchanged"
fi

# --- image integrity
SUMS="$(dirname "$IMAGE")/$(basename "$IMAGE" .sparse.img).SHA256SUMS"
[ -f "$SUMS" ] || die "checksum file not found: $SUMS"
want=$(grep " $(basename "$IMAGE")\$" "$SUMS" | cut -d' ' -f1)
[ -n "$want" ] || die "no checksum line for $(basename "$IMAGE") in $SUMS"
[ "$(sha "$IMAGE")" = "$want" ] || die "image SHA-256 does not match $SUMS (corrupt download?)"
log "image SHA-256 ok ($want)"
# Android sparse header: magic 0xED26FF3A, blk_sz at 12, total_blks at 16 (little endian)
magic=$(od -An -tx1 -N4 "$IMAGE" | tr -d ' \n'); [ "$magic" = "3aff26ed" ] || die "not an Android sparse image"
blk=$(od -An -tu4 -j12 -N4 "$IMAGE" | tr -d ' '); tot=$(od -An -tu4 -j16 -N4 "$IMAGE" | tr -d ' ')
IMG_BYTES=$((blk * tot))

# --- device
FB=(fastboot); [ -n "$SERIAL" ] && FB=(fastboot -s "$SERIAL")
if [ -z "$SERIAL" ]; then n=$(fastboot devices | grep -c fastboot || true); [ "$n" = 1 ] || die "expected exactly one fastboot device, found $n (use --serial)"; fi
gv() { "${FB[@]}" getvar "$1" 2>&1 | sed -n "s/^$1: *//p" | head -1 | tr -d '\r'; }
[ "$(gv product)" = pipa ]       || die "product is not pipa: this is not a Xiaomi Pad 6"
[ "$(gv unlocked)" = yes ]       || die "bootloader is not unlocked (see docs/INSTALL.md)"
[ "$(gv is-userspace)" = no ]    || die "this is fastbootd; reboot into the bootloader fastboot (Power + Volume Down)"
SLOT=$(gv current-slot); case "$SLOT" in a|b) ;; *) die "cannot read current-slot (got '$SLOT')" ;; esac
[ "$(gv battery-soc-ok)" = yes ] || die "battery too low to flash safely, charge first"
bsz=$(( $(gv "partition-size:boot_$SLOT") )); [ "$(stat -c %s "$UBOOT" 2>/dev/null || stat -f %z "$UBOOT")" -le "$bsz" ] || die "U-Boot image does not fit boot_$SLOT"
usz=$(( $(gv partition-size:userdata) )); [ "$usz" -gt "$IMG_BYTES" ] || die "userdata ($usz B) is smaller than the image ($IMG_BYTES B)"
log "device ok: product=pipa slot=$SLOT userdata=$usz B image=$IMG_BYTES B panel variant=$PANEL"

if [ "$YES" != 1 ]; then
  cat <<MSG

About to ERASE ALL DATA on this Xiaomi Pad 6 and install DorothyOS ($PANEL panel variant):
    erase dtbo_$SLOT, flash boot_$SLOT <- $UBOOT, flash userdata <- $IMAGE
Is this tablet's panel really $PANEL?  (run detect-panel.sh while it still runs Android)
Did you make a backup?  (docs/ANDROID-ROLLBACK.md)
MSG
  read -r -p "Type the word ERASE to continue: " a; [ "$a" = ERASE ] || die "not confirmed"
fi

"${FB[@]}" erase "dtbo_$SLOT"
"${FB[@]}" flash "boot_$SLOT" "$UBOOT"
"${FB[@]}" flash userdata "$IMAGE"
log "flashed. Rebooting with 'fastboot reboot' (do not force a reboot with the buttons while it is writing)."
"${FB[@]}" reboot
log "First boot: KDE's setup wizard asks for language, time zone, Wi-Fi and creates YOUR account. This can take a minute or two after the logo."
