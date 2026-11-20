#!/bin/sh
# phase18-branding-user.sh — user level (no root). DorothyOS accent colour (#e85d00, the deeper brand orange) for the whole Plasma
# session: selections, switches, sliders, focus rings, the highlighted rows of the home screen, control center and Settings.
# The system-wide identity (name in "About this System", boot splash, wallpapers, os-release) comes from the apk dorothyos-branding.
# Idempotent.  usage: phase18-branding-user.sh apply | undo
set -u
CFG=$HOME/.config
BK=$HOME/pipa-phase18-backup
ACCENT=${DOROTHYOS_ACCENT:-#e85d00}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}
export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-1}
say() { echo "[$(date +%T)] $*"; }
# The colour scheme in use. A fresh profile has no ColorScheme key in kdeglobals: the Global Theme (LookAndFeelPackage) then decides.
# NEVER fall back blindly to the light scheme: that would silently switch a dark tablet to light (it happened once on the reference tablet).
current_scheme() {
  s=$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)
  if [ -z "$s" ]; then
    case "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)" in
      *dark*|*Dark*) s=BreezeDark ;;
      *) s=BreezeLight ;;
    esac
  fi
  echo "$s"
}
# "About this System": a tablet that only got the user-level DorothyOS interface (no dorothyos-branding apk, so /etc/xdg/kcm-about-distrorc is
# missing or still the base system's) shows the DorothyOS name, version and mark through a per-user file; KDE reads ~/.config before /etc/xdg.
about_apply() {
  if grep -q '^Name=DorothyOS' /etc/xdg/kcm-about-distrorc 2>/dev/null; then say "   About page: the system file is already DorothyOS"; return 0; fi
  F=$CFG/kcm-about-distrorc
  if [ -e "$F" ] && ! grep -q 'written by DorothyOS' "$F"; then say "   About page: you have your own ~/.config/kcm-about-distrorc, left alone"; return 0; fi
  ver=0.1.0-rc1
  [ -r /usr/share/dorothyos/dorothyos-branding.conf ] && ver=$(sed -n 's/^DOROTHYOS_RELEASE="\([^"]*\)".*/\1/p' /usr/share/dorothyos/dorothyos-branding.conf)
  site=https://dorothy.gr/dorothyos
  [ -r /usr/share/dorothyos/dorothyos-branding.conf ] && site=$(sed -n 's/^DOROTHYOS_HOME_URL="\([^"]*\)".*/\1/p' /usr/share/dorothyos/dorothyos-branding.conf)
  logo=""
  for c in /usr/share/icons/hicolor/512x512/apps/dorothyos.png "$HOME/.local/share/icons/hicolor/256x256/apps/dorothyos.png" /usr/share/icons/hicolor/256x256/apps/dorothyos.png; do [ -f "$c" ] && { logo=$c; break; }; done
  {
    echo "# written by DorothyOS (phase18-branding-user.sh); delete this file to get the system default back"
    echo "[General]"; echo "Name=DorothyOS"; echo "Version=$ver"; echo "Variant=Xiaomi Pad 6"; echo "Logo=dorothyos"
    echo "Website=$site"   # always set (even when empty): without the key KDE would fall back to the website of the base system
    [ -z "$logo" ] || echo "LogoPath=$logo"
  } > "$F"
  say "   About page: DorothyOS $ver ($F)"
}
undo_colors() {
  [ -d "$BK" ] || { echo "no backup at $BK"; return 1; }
  if [ -f "$BK/kdeglobals" ]; then cp -a "$BK/kdeglobals" "$CFG/kdeglobals"; else rm -f "$CFG/kdeglobals"; fi
  # the restored file is exactly the old one; tell the running session to re-read the colours (KGlobalSettings PaletteChanged)
  busctl --user emit /KGlobalSettings org.kde.KGlobalSettings notifyChange ii 0 0 >/dev/null 2>&1 || :
}
case "${1:-}" in
apply)
  mkdir -p "$BK"
  [ -e "$BK/kdeglobals" ] || [ -e "$BK/kdeglobals.ABSENT" ] || { [ -f "$CFG/kdeglobals" ] && cp -a "$CFG/kdeglobals" "$BK/kdeglobals" || : > "$BK/kdeglobals.ABSENT"; }
  scheme=$(current_scheme)
  say "accent $ACCENT on colour scheme $scheme"
  # plasma-apply-colorscheme --accent-color IGNORES a scheme name given with it and recolours the scheme it believes is "current";
  # with no ColorScheme key in kdeglobals (fresh profiles, the reference tablet) that is BreezeLight, which turned a dark tablet light.
  # So: pin the scheme explicitly first (writes ColorScheme=<name>), then add the accent on top of it, then verify.
  if plasma-apply-colorscheme "$scheme" >/dev/null 2>&1 && plasma-apply-colorscheme --accent-color "$ACCENT" >/dev/null 2>&1; then
    # (plasma-apply-colorscheme writes nothing when the scheme is already the current one, e.g. on a second run: compare with the same
    #  fallback current_scheme() uses instead of the raw key, otherwise a re-run aborts and throws the accent colour away)
    now=$(current_scheme)
    if [ "$now" != "$scheme" ]; then
      say "   ABORT: the colour scheme is now '$now', expected '$scheme' - restoring the previous colours"
      undo_colors; exit 1
    fi
    say "   applied through plasma-apply-colorscheme (scheme pinned: $scheme)"
  else
    # no running session (or an older Plasma): write the values the tool would write; the next login picks them up
    rgb=$(python3 - "$ACCENT" <<'PY'
import sys
h = sys.argv[1].lstrip("#")
print(",".join(str(int(h[i:i + 2], 16)) for i in (0, 2, 4)))
PY
)
    kwriteconfig6 --file kdeglobals --group General --key AccentColor "$rgb"
    kwriteconfig6 --file kdeglobals --group General --key LastUsedCustomAccentColor "$rgb"
    say "   written to kdeglobals ($rgb), active at the next login"
  fi
  about_apply
  say "done" ;;
undo)
  undo_colors || exit 1
  grep -q 'written by DorothyOS' "$CFG/kcm-about-distrorc" 2>/dev/null && rm -f "$CFG/kcm-about-distrorc"
  say "undone (accent colour and About page as before)" ;;
*) echo "usage: $0 apply|undo"; exit 1 ;;
esac
