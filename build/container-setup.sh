#!/bin/sh
# container-setup.sh — prepares a fresh Alpine edge (aarch64, privileged) container for the image build. Idempotent.
# Runs INSIDE the container as root; build/build.sh starts it.
set -eu
WORK=${WORK:-/work}
export HOME=$WORK/home
mkdir -p "$HOME/.local/var/pmbootstrap"

apk add --no-cache pmbootstrap git parted dosfstools e2fsprogs kpartx losetup util-linux util-linux-misc sudo openssl \
  android-tools-img2simg curl ca-certificates xz zstd coreutils python3 bash

# --- pinned apk-tools-static (see build/pmb-pinned.py for the reason). Alpine v3.24 ships 3.0.9; verified by SHA-256.
APK_URL=https://dl-cdn.alpinelinux.org/alpine/v3.24/main/aarch64/apk-tools-static-3.0.9-r0.apk
APK_SHA256=1f4c822fd14e8eb51ba27e17d5a1649aef33c91611c77eddeb318e8f2cb57fb1
BIN=$HOME/.local/var/pmbootstrap/apk.static
if [ ! -x "$BIN" ] || ! "$BIN" --version | grep -q 'apk-tools 3.0.9'; then
  t=$(mktemp -d)
  curl -fsSL -o "$t/a.apk" "$APK_URL"
  echo "$APK_SHA256  $t/a.apk" | sha256sum -c -
  tar -xzf "$t/a.apk" -C "$t" sbin/apk.static 2>/dev/null || tar -xzf "$t/a.apk" -C "$t"
  install -m755 "$t/sbin/apk.static" "$BIN"
  rm -rf "$t"
fi
"$BIN" --version
echo "container-setup: ok"
