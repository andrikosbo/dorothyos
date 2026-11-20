#!/bin/sh
# postprocess.sh RAW_IMAGE PANEL VERSION OUTDIR — makes the pmbootstrap rootfs image safe to publish. Runs INSIDE the
# privileged build container (needs loop devices + mount).  What it does, in order:
#   * removes the throw-away build account (and its group / home) — NO account, NO password ships in the image;
#     the account is created on the device by KDE's first-boot wizard (plasma-setup)
#   * locks root (no password, password login impossible)
#   * masks systemd-firstboot (it would otherwise ask for a root password on the console of a tablet that has no keyboard)
#   * removes anything host- or build-specific: ssh host keys, shell histories, machine-id (generated at first boot)
#   * writes /etc/dorothyos-release, a package manifest and the boot entry listing next to the image
#   * converts the raw image to an Android sparse image (fastboot) and writes SHA-256 sums
set -eu
RAW=${1:?raw image}; PANEL=${2:?panel}; VERSION=${3:?version}; OUT=${4:?outdir}
NAME=dorothyos-$VERSION-$PANEL
M=$(mktemp -d)
say() { echo "[$(date +%T)] $*"; }

LOOP=$(losetup --sector-size 4096 -P -f --show "$RAW")
cleanup() { umount "$M/boot" 2>/dev/null || :; umount "$M" 2>/dev/null || :; losetup -d "$LOOP" 2>/dev/null || :; rmdir "$M" 2>/dev/null || :; }
trap cleanup EXIT
# Docker Desktop has no udev: (re)make the partition nodes from sysfs (stale nodes of an earlier loop device are replaced)
L=${LOOP##*/}
rm -f /dev/"$L"p*
for d in /sys/block/"$L"/"$L"p*; do
  [ -e "$d/dev" ] || continue
  n=${d##*/}; IFS=: read -r maj min < "$d/dev"; mknod "/dev/$n" b "$maj" "$min"
done
[ -b "${LOOP}p2" ] || { echo "no root partition node ${LOOP}p2"; exit 1; }

e2fsck -fp "${LOOP}p2" >/dev/null || [ $? -le 1 ]
mount "${LOOP}p2" "$M"
mount "${LOOP}p1" "$M/boot"

say "removing the build account"
python3 - "$M" <<'PY'
import sys, os, re
root = sys.argv[1]
def rd(p):
    with open(os.path.join(root, p)) as f: return f.read().splitlines()
def wr(p, lines, mode=None):
    fp = os.path.join(root, p)
    st = os.stat(fp)
    with open(fp, "w") as f: f.write("\n".join(lines) + "\n")
    os.chmod(fp, st.st_mode & 0o7777); os.chown(fp, st.st_uid, st.st_gid)
passwd = rd("etc/passwd")
users = [l.split(":") for l in passwd if l.split(":")[2].isdigit() and 1000 <= int(l.split(":")[2]) < 60000]
names = {u[0] for u in users}; gids = {u[3] for u in users}
print("regular accounts found:", sorted(names))
wr("etc/passwd", [l for l in passwd if l.split(":")[0] not in names])
sh = rd("etc/shadow")
out = []
for l in sh:
    f = l.split(":")
    if f[0] in names: continue
    if f[0] == "root": f[1] = "!"          # locked
    out.append(":".join(f))
wr("etc/shadow", out)
def strip_group(l, names, gids):
    f = l.split(":")
    if f[0] in names or (len(f) > 2 and f[2] in gids): return None
    # member list is the last field of /etc/group; for /etc/gshadow members are fields 2 and 3
    idx = [3] if len(f) == 4 and f[2].isdigit() else [2, 3]
    for i in idx:
        if i < len(f): f[i] = ",".join(m for m in f[i].split(",") if m and m not in names)
    return ":".join(f)
for p in ("etc/group", "etc/gshadow"):
    if os.path.exists(os.path.join(root, p)):
        wr(p, [x for x in (strip_group(l, names, gids) for l in rd(p)) if x is not None])
for p in ("etc/subuid", "etc/subgid"):
    if os.path.exists(os.path.join(root, p)):
        wr(p, [l for l in rd(p) if l.split(":")[0] not in names])
PY
rm -rf "$M"/home/* "$M"/var/lib/AccountsService/users/* "$M"/var/spool/mail/* 2>/dev/null || :
if awk -F: '$3>=1000 && $3<60000' "$M/etc/passwd" | grep -q .; then echo "a regular account is still present"; exit 1; fi
grep -q '^root:!:' "$M/etc/shadow" || { echo "root is not locked"; exit 1; }

say "mask systemd-firstboot, clear host specific state"
ln -sf /dev/null "$M/etc/systemd/system/systemd-firstboot.service"
rm -f "$M"/etc/ssh/ssh_host_* "$M/etc/machine-id" "$M/var/lib/dbus/machine-id"
rm -f "$M"/root/.ash_history "$M"/root/.bash_history "$M"/root/.python_history 2>/dev/null || :
rm -rf "$M"/var/log/journal/* "$M"/var/cache/apk/* "$M"/tmp/* 2>/dev/null || :
[ ! -e "$M/etc/plasma-setup-done" ] || { echo "plasma-setup-done exists: the wizard would not run"; exit 1; }
[ -e "$M/usr/lib/systemd/system/multi-user.target.wants/plasma-setup.service" ] || { echo "plasma-setup is not enabled"; exit 1; }

say "branding assertions (package dorothyos-branding must have done its job)"
# /etc/os-release is a symlink to /usr/lib/os-release on stock images; our apply script makes it a real DorothyOS file
[ ! -L "$M/etc/os-release" ] && grep -q '^ID=dorothyos$' "$M/etc/os-release" \
  && grep -q '^PRETTY_NAME="DorothyOS ' "$M/etc/os-release" || { echo "os-release is not the DorothyOS one"; cat "$M/etc/os-release"; exit 1; }
grep -q '^ID_LIKE=.*alpine' "$M/etc/os-release" || { echo "os-release lost ID_LIKE (apk/tools rely on it)"; exit 1; }
[ -f "$M/etc/xdg/kcm-about-distrorc" ] && grep -q '^Name=DorothyOS' "$M/etc/xdg/kcm-about-distrorc" \
  || { echo "KDE 'About this System' file is missing or not DorothyOS"; exit 1; }
[ -f "$M/usr/share/plymouth/themes/dorothyos/dorothyos.script" ] || { echo "plymouth theme dorothyos missing"; exit 1; }
grep -q '^Theme=dorothyos$' "$M/etc/plymouth/plymouthd.conf" || { echo "plymouthd.conf does not select dorothyos"; exit 1; }
ls "$M"/usr/share/wallpapers/DorothyOS-*/contents/images/2880x1800.jpg >/dev/null 2>&1 || { echo "DorothyOS wallpapers missing"; exit 1; }
[ -f "$M/usr/share/icons/hicolor/scalable/apps/dorothyos.svg" ] || { echo "dorothyos icon missing"; exit 1; }
echo dorothyos > "$M/etc/hostname"
# boot menu title (systemd-boot): show DorothyOS instead of the base distribution name
for f in "$M"/boot/loader/entries/*.conf; do
  [ -f "$f" ] || continue
  sed -i -e 's/^title .*/title   DorothyOS/' -e 's/^sort-key .*/sort-key dorothyos/' "$f"
done
# the initramfs must carry the splash theme (it is the only place Plymouth can read it from during early boot)
for ir in $(find "$M/boot" -type f -name "initramfs*" ! -name "*fallback*" 2>/dev/null); do
  if ! { gzip -dc "$ir" 2>/dev/null || zstd -dc "$ir" 2>/dev/null || lz4 -dc "$ir" 2>/dev/null; } | cpio -t 2>/dev/null | grep -q 'usr/share/plymouth/themes/dorothyos/dorothyos.script'; then
    echo "WARNING: $ir does not contain the dorothyos plymouth theme (the stock splash will show)"; SPLASH_WARN=1
  fi
done
[ -z "${SPLASH_WARN:-}" ] || exit 1

say "release file + manifests"
mkdir -p "$OUT"
cat > "$M/etc/dorothyos-release" <<REL
NAME="DorothyOS"
VERSION="$VERSION"
PANEL="$PANEL"
VARIANT_ID="xiaomi-pipa-$PANEL"
BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BASE="postmarketOS systemd-edge + KDE Plasma 6"
HOME_URL="https://dorothy.gr/dorothyos"
REL
chmod 644 "$M/etc/dorothyos-release"
python3 - "$M" "$OUT/$NAME.packages.txt" <<'PY'
import sys, os
root, out = sys.argv[1:3]
rows = []
cur = {}
for blk in open(os.path.join(root, "lib/apk/db/installed")).read().split("\n\n"):
    d = {}
    for l in blk.splitlines():
        if len(l) > 2 and l[1] == ":": d[l[0]] = l[2:]
    if "P" in d: rows.append((d["P"], d.get("V", "?"), d.get("L", "?")))
rows.sort()
with open(out, "w") as f:
    f.write("# package version license  (from /lib/apk/db/installed of the image)\n")
    for p, v, l in rows: f.write(f"{p} {v} {l}\n")
print(len(rows), "packages")
PY
{ echo "== /boot (ESP) =="; (cd "$M/boot" && find . -type f | sort); echo; for f in "$M"/boot/loader/loader.conf "$M"/boot/loader/entries/*.conf; do [ -f "$f" ] && { echo "== ${f#$M} =="; cat "$f"; echo; }; done; } > "$OUT/$NAME.boot-entries.txt"
cat "$OUT/$NAME.boot-entries.txt" | sed -n 1,60p

sync
umount "$M/boot"; umount "$M"
e2fsck -fn "${LOOP}p2" >/dev/null && say "e2fsck: clean"
losetup -d "$LOOP"; trap - EXIT; rmdir "$M"

say "sparse image for fastboot"
img2simg "$RAW" "$OUT/$NAME.sparse.img"
ls -la "$OUT/$NAME.sparse.img"
( cd "$OUT" && sha256sum "$NAME.sparse.img" "$NAME.packages.txt" "$NAME.boot-entries.txt" > "$NAME.SHA256SUMS" && cat "$NAME.SHA256SUMS" )
