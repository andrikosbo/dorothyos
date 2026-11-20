#!/bin/sh
# validate-image.sh SPARSE_IMAGE PANEL — OFFLINE validation of a finished DorothyOS image. Nothing here touches a tablet: it unpacks the
# Android sparse image (what `fastboot flash` receives), mounts the two partitions read-only in a loop device and checks the result.
#
# Needs root + loop devices, i.e. run it in the privileged arm64 build container, or let `tests/validate.sh` (host wrapper) start one:
#     tests/validate.sh dist/dorothyos-0.1.0-tianma.sparse.img tianma
#
# What a PASS means: the files, accounts, services, boot entries and branding that the build is supposed to produce ARE in the image, and
# the filesystems are clean. What it can NOT tell you: whether the image boots on a tablet, whether the splash looks right, whether the
# touch UI behaves — see docs/VALIDATION.md ("not verified on hardware").
set -u
IMG=${1:?sparse image}; PANEL=${2:?tianma|csot}
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=${VALIDATE_WORK:-/scratch}
case "$PANEL" in tianma) OTHER=csot ;; csot) OTHER=tianma ;; *) echo "panel must be tianma or csot"; exit 2 ;; esac
pass=0; fail=0; warn=0
ok()   { pass=$((pass + 1)); echo "ok    $*"; }
bad()  { fail=$((fail + 1)); echo "FAIL  $*"; }
note() { warn=$((warn + 1)); echo "WARN  $*"; }
info() { echo "info  $*"; }
sect() { echo; echo "== $*"; }

if command -v apk >/dev/null 2>&1; then
  need=""
  for p in python3:python3 e2fsck:e2fsprogs losetup:util-linux blkid:blkid fsck.vfat:dosfstools cpio:cpio gzip:gzip zstd:zstd find:findutils; do
    command -v "${p%%:*}" >/dev/null 2>&1 || need="$need ${p##*:}"
  done
  # BusyBox's losetup cannot set the 4096-byte sector size of the tablet's UFS-style image
  losetup --help 2>&1 | grep -q sector-size || need="$need losetup"
  [ -z "$need" ] || { echo "installing:$need"; apk add --no-cache $need >/dev/null || { echo "cannot install$need"; exit 2; }; }
fi
mkdir -p "$WORK"
RAW=$WORK/$(basename "$IMG" .sparse.img).raw
M=$WORK/mnt-$PANEL
LOOP=""
cleanup() { umount "$M/boot" 2>/dev/null; umount "$M" 2>/dev/null; [ -z "$LOOP" ] || losetup -d "$LOOP" 2>/dev/null; rm -f "$RAW"; rmdir "$M" 2>/dev/null; }
trap cleanup EXIT INT TERM

sect "unpack"
[ -f "$IMG" ] || { echo "no such file: $IMG"; exit 2; }
sumfile=${IMG%.sparse.img}.SHA256SUMS
if [ -f "$sumfile" ]; then
  if (cd "$(dirname "$IMG")" && sha256sum -c "$(basename "$sumfile")" >/dev/null 2>&1); then ok "SHA-256 of image and manifests matches $(basename "$sumfile")"; else bad "SHA-256 mismatch ($(basename "$sumfile"))"; fi
else note "no SHA256SUMS next to the image"; fi
python3 -I "$HERE/unsparse.py" "$IMG" "$RAW" >/dev/null || { bad "not a valid Android sparse image"; echo "VALIDATION FAILED"; exit 1; }
ok "valid Android sparse image, raw size $(( $(stat -c %s "$RAW") / 1048576 )) MiB"
LOOP=$(losetup --sector-size 4096 -P -f --show "$RAW") || { echo "no loop device (needs a privileged container)"; exit 2; }
L=${LOOP##*/}
rm -f /dev/"$L"p*
for d in /sys/block/"$L"/"$L"p*; do
  [ -e "$d/dev" ] || continue
  n=${d##*/}; IFS=: read -r maj min < "$d/dev"; mknod "/dev/$n" b "$maj" "$min"
done
np=$(ls /dev/"$L"p* 2>/dev/null | wc -l)
[ "$np" = 2 ] && ok "two partitions (ESP + root)" || bad "expected 2 partitions, found $np"
# (BusyBox blkid ignores -s/-o, so parse its plain output)
bv() { blkid "$1" 2>/dev/null | sed -n "s/.*[ ]$2=\"\([^\"]*\)\".*/\1/p"; }
l1=$(bv "${LOOP}p1" LABEL); t1=$(bv "${LOOP}p1" TYPE); l2=$(bv "${LOOP}p2" LABEL); t2=$(bv "${LOOP}p2" TYPE)
[ "$(echo "$l1" | tr A-Z a-z)" = pmos_boot ] && [ "$t1" = vfat ] && ok "p1 = vfat '$l1' (ESP)" || bad "p1 is not the vfat pmOS_boot ESP (label '$l1', type '$t1')"
[ "$(echo "$l2" | tr A-Z a-z)" = pmos_root ] && [ "$t2" = ext4 ] && ok "p2 = ext4 '$l2' (root)" || bad "p2 is not the ext4 pmOS_root (label '$l2', type '$t2')"
e2fsck -fn "${LOOP}p2" >/dev/null 2>&1 && ok "e2fsck: root filesystem clean" || bad "e2fsck reports problems on the root filesystem"
fsck.vfat -n "${LOOP}p1" >/dev/null 2>&1 && ok "fsck.vfat: ESP clean" || bad "fsck.vfat reports problems on the ESP"
mkdir -p "$M"
mount -o ro,noload "${LOOP}p2" "$M" 2>/dev/null || mount -o ro "${LOOP}p2" "$M" || { echo "cannot mount root"; exit 2; }
mount -o ro "${LOOP}p1" "$M/boot" || { echo "cannot mount ESP"; exit 2; }

sect "accounts, secrets, host-specific state"
n=$(awk -F: '$3>=1000 && $3<60000' "$M/etc/passwd" | wc -l)
[ "$n" = 0 ] && ok "no regular user account in /etc/passwd (the first-boot wizard creates it)" || bad "$n regular account(s) in /etc/passwd"
grep -q '^root:!' "$M/etc/shadow" && ok "root is locked" || bad "root is not locked"
awk -F: '$2!="" && $2!="!" && $2!="*" && $2!~/^!/ && $2!~/^\*/ {print $1}' "$M/etc/shadow" | grep -q . && bad "an account in /etc/shadow has a password hash: $(awk -F: '$2!="" && $2!="!" && $2!="*" && $2!~/^[!*]/ {print $1}' "$M/etc/shadow" | tr '\n' ' ')" || ok "no password hash anywhere in /etc/shadow"
[ -z "$(ls -A "$M/home" 2>/dev/null)" ] && ok "/home is empty" || bad "/home is not empty: $(ls "$M/home")"
ls "$M"/etc/ssh/ssh_host_* >/dev/null 2>&1 && bad "ssh host keys are baked in" || ok "no ssh host keys"
[ ! -e "$M/etc/machine-id" ] || [ ! -s "$M/etc/machine-id" ] && ok "no machine-id (generated at first boot)" || bad "machine-id is baked in"
keyfiles=$(find "$M" -xdev \( -name authorized_keys -o -name 'id_rsa*' -o -name 'id_e''d2551''9*' -o -name 'id_ecdsa*' -o -name '.ash_history' -o -name '.bash_history' -o -name '*.key' -o -name '*.p12' \) ! -path "$M/usr/*" 2>/dev/null | head -5)
[ -z "$keyfiles" ] && ok "no ssh keys, authorized_keys, private keys or shell histories" || bad "key / history files present: $keyfiles"
[ -z "$(ls -A "$M/etc/NetworkManager/system-connections" 2>/dev/null)" ] && ok "no saved Wi-Fi / network profile" || bad "NetworkManager profiles present"
[ -z "$(ls -A "$M/var/lib/bluetooth" 2>/dev/null)" ] && ok "no Bluetooth pairing data" || bad "Bluetooth data present"
ls "$M"/var/lib/AccountsService/users/* >/dev/null 2>&1 && bad "AccountsService user data present" || ok "no AccountsService user data"
# personal data must not appear in configuration, in the tablet package or in the plasmoids
# (postmarketOS's stock USB-network address is not personal data and is deliberately not searched for);
# add your own names / host names / key directories through the environment variable PRIVATE_PATTERNS (regex, separated by |)
PII="/Users/|/Volumes/${PRIVATE_PATTERNS:+|$PRIVATE_PATTERNS}"
hits=$(grep -rInE "$PII" "$M/etc" "$M/root" "$M/var/lib" "$M/usr/share/dorothyos-tablet" "$M/usr/share/dorothyos-branding" "$M/usr/share/plasma/plasmoids" "$M/usr/bin" "$M/usr/lib/systemd" "$M/boot/loader" 2>/dev/null | grep -v '/var/lib/apk/' | head)
[ -z "$hits" ] && ok "no personal identifiers in /etc, /var/lib, the tablet package and the plasmoids" || { echo "$hits" | cut -c1-220 | sed 's/^/        /'; bad "personal data in the image (files above)"; }

sect "services"
[ -e "$M/usr/lib/systemd/system/multi-user.target.wants/plasma-setup.service" ] && ok "plasma-setup (first-boot wizard) enabled" || bad "plasma-setup not enabled"
[ ! -e "$M/etc/plasma-setup-done" ] && ok "wizard has not been marked done" || bad "/etc/plasma-setup-done exists, the wizard would be skipped"
[ "$(readlink "$M/etc/systemd/system/systemd-firstboot.service")" = /dev/null ] && ok "systemd-firstboot masked (no console prompt on a keyboard-less tablet)" || bad "systemd-firstboot is not masked"
ssh_on=$(find "$M/etc/systemd/system" "$M/usr/lib/systemd/system" -name 'sshd*.service' -path '*.wants/*' 2>/dev/null)
[ -z "$ssh_on" ] && ok "sshd is not enabled" || bad "sshd is enabled: $ssh_on"
[ -e "$M/usr/lib/systemd/system/multi-user.target.wants/pipa-sensors-registry.service" ] && ok "sensor-registry service enabled" || bad "pipa-sensors-registry not enabled"
[ -e "$M/usr/lib/systemd/user/graphical-session.target.wants/pipa-autorotate-kick.service" ] && ok "auto-rotate kick user service enabled" || bad "pipa-autorotate-kick not enabled"
dm=$(find "$M/etc/systemd/system" "$M/usr/lib/systemd/system" \( -name 'plasmalogin*.service' -o -name 'plasma-login*.service' -o -name 'sddm*.service' -o -name display-manager.service \) 2>/dev/null | head -3 | tr '\n' ' ')
[ -n "$dm" ] && ok "login manager unit(s): $(for u in $dm; do printf '%s ' "${u#$M}"; done)" || note "no login manager unit found"
for u in $(find "$M/etc/systemd/system" "$M/usr/lib/systemd/system" -path '*.wants/*' \( -name 'plasmalogin*' -o -name 'plasma-login*' -o -name 'sddm*' -o -name display-manager.service \) 2>/dev/null | head -3); do info "enabled: ${u#$M}"; done

sect "panel: $PANEL (the only difference between the two images)"
BE=$(ls "$M"/boot/loader/entries/*.conf 2>/dev/null | head -1)
[ -n "$BE" ] || bad "no boot entry"
dt=$(awk '$1=="devicetree"{print $2}' "$BE")
[ "$dt" = "sm8250-xiaomi-pipa-$PANEL.dtb" ] && ok "boot entry selects $dt" || bad "boot entry devicetree is '$dt'"
[ -f "$M/boot/$dt" ] && ok "device tree file present on the ESP" || bad "$dt missing on the ESP"
[ -f "$M/boot/vmlinuz" ] && [ -f "$M/boot/initramfs" ] && ok "kernel + initramfs on the ESP" || bad "kernel or initramfs missing"
[ -f "$M/boot/EFI/BOOT/BOOTAA64.EFI" ] && ok "systemd-boot EFI binary on the ESP" || bad "EFI/BOOT/BOOTAA64.EFI missing"
grep -q "^P:device-xiaomi-pipa-kernel-$PANEL\$" "$M/lib/apk/db/installed" && ok "package device-xiaomi-pipa-kernel-$PANEL installed" || bad "kernel variant package for $PANEL missing"
grep -q "^P:device-xiaomi-pipa-kernel-$OTHER\$" "$M/lib/apk/db/installed" && bad "kernel variant package for the OTHER panel ($OTHER) is installed" || ok "no kernel variant package of the other panel"
grep -q "^PANEL=\"$PANEL\"" "$M/etc/dorothyos-release" && ok "/etc/dorothyos-release says PANEL=$PANEL" || bad "/etc/dorothyos-release has the wrong panel"
grep -q '^title   DorothyOS$' "$BE" && ok "boot menu title is DorothyOS" || bad "boot entry title is not DorothyOS"
grep -q 'splash' "$BE" && ok "kernel command line enables the splash" || note "no 'splash' on the kernel command line"

sect "branding"
grep -q '^ID=dorothyos$' "$M/etc/os-release" && [ ! -L "$M/etc/os-release" ] && ok "/etc/os-release is DorothyOS (real file, ID=dorothyos)" || bad "/etc/os-release is not DorothyOS"
# the interface leads with DorothyOS: nothing the user sees may name the base system (credits live in CREDITS.md, quietly)
shown="$M/etc/xdg/kcm-about-distrorc $M/etc/issue $M/etc/motd"
grep -qiE 'nura|postmarketos|alpine' $shown 2>/dev/null && bad "the About page / login banner names the base system: $(grep -liE 'nura|postmarketos|alpine' $shown | tr '\n' ' ')" || ok "About page, /etc/issue and /etc/motd show DorothyOS only"
grep -qE '^(NAME|PRETTY_NAME)=.*(Nura|postmarketOS|Alpine)' "$M/etc/os-release" && bad "os-release NAME / PRETTY_NAME names the base system" || ok "os-release NAME and PRETTY_NAME are DorothyOS"
[ -f "$M/usr/share/doc/dorothyos-branding/CREDITS.md" ] && ok "CREDITS.md installed (/usr/share/doc/dorothyos-branding)" || bad "CREDITS.md missing in the image"
# the redistribution licences of the firmware in the image must travel with it (docs/FIRMWARE.md)
fw="$M/usr/share/licenses/dorothyos-branding/firmware"
n=$(ls "$fw" 2>/dev/null | wc -l | tr -d ' ')
[ -s "$fw/LICENSE.qcom" ] && [ -s "$fw/NOTICE.qcom" ] && [ -s "$fw/LICENSE.QualcommAtheros_ath10k" ] && [ -f "$M/usr/share/doc/dorothyos-branding/FIRMWARE.md" ] && ok "firmware licence texts and FIRMWARE.md installed ($n files in /usr/share/licenses/dorothyos-branding/firmware)" || bad "firmware licence texts / FIRMWARE.md missing in the image"
grep -q '^ID_LIKE=.*alpine' "$M/etc/os-release" && ok "ID_LIKE keeps alpine (apk tooling)" || bad "ID_LIKE lost"
grep -q '^Name=DorothyOS' "$M/etc/xdg/kcm-about-distrorc" && ok "KDE 'About this System' says DorothyOS" || bad "kcm-about-distrorc is not DorothyOS"
[ "$(cat "$M/etc/hostname")" = dorothyos ] && ok "hostname dorothyos" || bad "hostname is '$(cat "$M/etc/hostname")'"
grep -q '^Theme=dorothyos$' "$M/etc/plymouth/plymouthd.conf" && [ -f "$M/usr/share/plymouth/themes/dorothyos/dorothyos.script" ] && ok "Plymouth theme dorothyos selected and installed" || bad "plymouth theme not selected / missing"
cnt=0
for ir in "$M"/boot/initramfs; do
  if { gzip -dc "$ir" 2>/dev/null || zstd -dc "$ir" 2>/dev/null; } | cpio -t 2>/dev/null | grep -q 'usr/share/plymouth/themes/dorothyos/dorothyos.script'; then cnt=1; fi
done
[ $cnt = 1 ] && ok "initramfs contains the dorothyos splash theme" || bad "initramfs does not contain the splash theme (stock splash would show)"
nwp=$(ls -d "$M"/usr/share/wallpapers/DorothyOS-* 2>/dev/null | wc -l)
[ "$nwp" -ge 8 ] && ok "$nwp DorothyOS wallpaper packages" || bad "only $nwp wallpaper packages"
for s in 16 22 32 48 64 128 256 512; do [ -f "$M/usr/share/icons/hicolor/${s}x${s}/apps/dorothyos.png" ] || miss="$miss $s"; done
[ -f "$M/usr/share/icons/hicolor/scalable/apps/dorothyos.svg" ] && [ -z "${miss:-}" ] && ok "app icon in all sizes + SVG" || bad "app icon incomplete (missing sizes:${miss:-none})"
ls "$M"/usr/share/licenses/dorothyos-branding/* >/dev/null 2>&1 && ok "licence files of the branding package installed" || note "no licence files under /usr/share/licenses/dorothyos-branding"

sect "touch UI (dorothyos-tablet)"
for f in usr/bin/pipa-first-login usr/bin/dorothyos-settings usr/bin/dorothyos-settings-helper usr/bin/pipa-sensors-registry usr/bin/pipa-autorotate-kick \
         usr/share/applications/dorothyos-settings.desktop usr/share/applications/pipa-camera.desktop etc/xdg/autostart/pipa-first-login.desktop \
         usr/share/dorothyos-tablet/phase18-branding-user.sh usr/share/dorothyos-tablet/phase19-start-menu-user.sh usr/share/dorothyos-tablet/camera/pipa-camera; do
  [ -e "$M/$f" ] || { bad "missing /$f"; continue; }
done
notx=$(cd "$M" && for f in usr/bin/pipa-first-login usr/bin/dorothyos-settings usr/bin/dorothyos-settings-helper usr/share/dorothyos-tablet/phase1*-user.sh; do [ -x "$f" ] || echo "$f"; done)
[ -z "$notx" ] && ok "commands and phase scripts present and executable" || bad "not executable / missing: $notx"
# status-bar guard: Plasma 6.8 resets the top panel to 54 px on every plasmashell start; the unit puts 32 px back and is wired in for every user
gl="$M/usr/lib/systemd/user"
if [ -x "$M/usr/bin/pipa-statusbar-guard" ] && grep -q '^ExecStart=/usr/bin/pipa-statusbar-guard' "$gl/pipa-statusbar-guard.service" 2>/dev/null \
   && [ -L "$gl/plasma-plasmashell.service.wants/pipa-statusbar-guard.service" ]; then ok "status-bar guard installed and wired into plasma-plasmashell"
else bad "status-bar guard missing or not wired (usr/bin/pipa-statusbar-guard, user unit, .wants link)"; fi
for id in org.pipa.homegrid org.pipa.controlcenter org.dorothyos.launcher org.dorothyos.settings; do
  if [ -d "$M/usr/share/plasma/plasmoids/$id" ]; then d="$M/usr/share/plasma/plasmoids/$id"
  elif [ -d "$M/usr/share/dorothyos-tablet/homegrid/$id" ]; then d="$M/usr/share/dorothyos-tablet/homegrid/$id"
  else d=$(find "$M/usr/share/dorothyos-tablet" "$M/usr/share/plasma/plasmoids" -type d -name "$id" 2>/dev/null | head -1); fi
  if [ -z "$d" ]; then bad "plasmoid $id not found"; continue; fi
  python3 -I - "$d/metadata.json" "$id" <<'PY' && ok "plasmoid $id: metadata.json valid, main.qml present" || bad "plasmoid $id: broken metadata or missing main.qml"
import json, os, sys
p, ident = sys.argv[1:3]
m = json.load(open(p))
assert m["KPlugin"]["Id"] == ident, "Id mismatch"
assert os.path.isfile(os.path.join(os.path.dirname(p), "contents", "ui", "main.qml")), "no main.qml"
PY
done
python3 -I - "$M/etc/xdg/kwinoutputconfig.json" <<'PY' && ok "kwinoutputconfig.json: valid JSON, DSI-1 at scale 2.5, landscape (Rotated270)" || bad "kwinoutputconfig.json is wrong"
import json, sys
d = json.load(open(sys.argv[1]))
blob = json.dumps(d)
assert "DSI-1" in blob and '"scale": 2.5' in blob.replace('"scale":2.5', '"scale": 2.5') and "Rotated270" in blob
PY
# the first-boot wizard runs as the throw-away user "plasma-setup" (home in /run): without a system-wide default it has no on-screen keyboard
# and the account cannot be created on a tablet without a physical keyboard (found on the first real boot, 2026-11-20)
grep -q '^InputMethod=/usr/share/applications/org.kde.plasma.keyboard.desktop$' "$M/etc/xdg/kwinrc" 2>/dev/null \
  && grep -q '^VirtualKeyboardEnabled=true$' "$M/etc/xdg/kwinrc" 2>/dev/null \
  && [ -f "$M/usr/share/applications/org.kde.plasma.keyboard.desktop" ] \
  && ok "/etc/xdg/kwinrc enables the on-screen keyboard for every session (first-boot wizard included)" \
  || bad "no system-wide on-screen keyboard default (/etc/xdg/kwinrc): the first-boot wizard could not be filled in without a keyboard"
# first-login (found on the first real boot, 2026-11-20): the launchers the dock tools point at must be shipped where phase10 / phase2b look
# for them, and every plasmashell restart must reset systemd's start-rate counter (6 restarts in a minute hit StartLimitBurst=3)
share=$M/usr/share/dorothyos-tablet
miss=$(for f in pipa-overview.desktop pipa-close.desktop pipa-keyboard.desktop pipa-rotate.desktop; do [ -f "$share/$f" ] || echo "$f"; done)
[ -z "$miss" ] && grep -q 'tabletux' "$share/phase10-tablet-ux-user.sh" && grep -q '\[ -d "\$SRC/tabletux" \]' "$share/phase10-tablet-ux-user.sh" \
  && ok "dock tool launchers (overview, close, keyboard, rotate) shipped where phase10 / phase2b read them" \
  || bad "dock tool launchers missing or phase10 looks in the wrong folder: ${miss:-phase10}"
rl=$(for f in "$share"/phase*.sh; do grep -n 'start plasma-plasmashell\|restart plasma-plasmashell' "$f" | grep -v 'reset-failed' | sed "s#^#$(basename "$f"):#"; done)
[ -z "$rl" ] && ok "every plasmashell (re)start in the first-login phases resets the systemd start-rate limit" \
  || bad "plasmashell started without reset-failed (start-limit-hit leaves the desktop half configured): $rl"
LSQ=$M/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/LockScreenUi.qml
if [ -f "$LSQ" ]; then grep -q 'pipa:' "$LSQ" && ok "touch lock screen patch applied" || note "lock screen is stock (patch not applied; harmless, see docs/LIMITATIONS.md)"; else note "LockScreenUi.qml not found at the expected path"; fi
grep -q 'tablet-maximize' "$M/usr/share/dorothyos-tablet/phase10-tablet-ux-user.sh" && grep -q 'ApplicationLauncher' "$M/usr/share/dorothyos-tablet/phase10-tablet-ux-user.sh" && ok "phase10 sets the touch edges and the maximize-windows rule (as on the reference tablet)" || bad "phase10 lacks the touch edges / maximize rule"
grep -q 'undo_colors' "$M/usr/share/dorothyos-tablet/phase18-branding-user.sh" && grep -q 'plasma-apply-colorscheme "$scheme"' "$M/usr/share/dorothyos-tablet/phase18-branding-user.sh" && ok "accent script pins the colour scheme before applying the accent (no dark -> light switch)" || bad "phase18 is the old accent script (it can turn a dark session light)"
grep -q '^P:flatpak$' "$M/lib/apk/db/installed" && grep -q '^P:kdialog$' "$M/lib/apk/db/installed" && ok "flatpak + kdialog installed (Camera launcher)" || bad "flatpak or kdialog missing"
for f in "$M"/usr/share/dorothyos-tablet/phase*.sh "$M"/usr/bin/pipa-first-login "$M"/usr/bin/dorothyos-settings "$M"/usr/bin/dorothyos-settings-helper "$M"/usr/share/dorothyos-tablet/camera/pipa-camera "$M"/usr/share/dorothyos-tablet/camera/pipa-camera-setup; do
  case "$(head -1 "$f")" in
    *python*) python3 -I -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' "$f" 2>/dev/null || bad "python syntax error: ${f#$M}" ;;
    *bash*) if command -v bash >/dev/null 2>&1; then bash -n "$f" 2>/dev/null || bad "bash syntax error: ${f#$M}"; fi ;;
    '#!/bin/sh'*|'#!/usr/bin/env sh'*) sh -n "$f" 2>/dev/null || bad "sh syntax error: ${f#$M}" ;;
    *) bad "no known shebang: ${f#$M}" ;;
  esac
done
ok "shell syntax of the installed scripts checked"

sect "package database"
npk=$(grep -c '^P:' "$M/lib/apk/db/installed")
info "$npk packages installed"
for p in plasma-desktop plasma-setup plymouth linux-xiaomi-pipa device-xiaomi-pipa dorothyos-tablet dorothyos-branding firefox; do
  grep -q "^P:$p\$" "$M/lib/apk/db/installed" && ok "package $p" || bad "package $p missing"
done
prop=$(awk 'BEGIN{RS="";FS="\n"} {p="";l=""; for(i=1;i<=NF;i++){if($i~/^P:/)p=substr($i,3); if($i~/^L:/)l=substr($i,3)} if(l ~ /proprietary/) print p}' "$M/lib/apk/db/installed" | tr '\n' ' ')
info "packages with licence 'proprietary' (firmware blobs): $prop"
info "image size on disk: $(du -sm "$M" 2>/dev/null | cut -f1) MiB used in the root filesystem"
n=$(find "$M" -xdev -type f -perm -4000 2>/dev/null | wc -l)
info "$n setuid files (informational)"
ww=$(find "$M/etc" "$M/usr/bin" "$M/usr/share/dorothyos-tablet" -xdev -type f -perm -0002 2>/dev/null | head -5)
[ -z "$ww" ] && ok "no world-writable files in /etc, /usr/bin, the tablet package" || bad "world-writable files: $ww"

echo
echo "RESULT $(basename "$IMG"): $pass ok, $warn warnings, $fail failed"
[ $fail = 0 ] && echo "VALIDATION PASSED (offline; NOT hardware-verified)" || echo "VALIDATION FAILED"
exit $((fail > 0))
