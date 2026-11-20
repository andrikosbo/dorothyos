#!/bin/sh
# phase19-start-menu-user.sh — user level (no root).
#   * replaces the Kickoff launcher in the dock by "DorothyOS Start" (plasmoid org.dorothyos.launcher): pinned apps, recent apps,
#     all apps by category and A-Z, search, lock / sleep / restart / shut down;
#   * makes sure "DorothyOS Settings" (plasmoid org.dorothyos.settings + dorothyos-settings-helper + the "Settings" launcher) is usable.
# Both plasmoids, the helper and the launcher are installed system-wide by the apk; on a tablet that only got the user-level patch
# they are copied into ~/.local instead.  Idempotent.   usage: phase19-start-menu-user.sh apply | undo
set -u
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}
export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-1}
SRC=$(cd "$(dirname "$0")" && pwd)
APPLETS=$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc
BK=$HOME/pipa-phase19-backup
ID=org.dorothyos.launcher
PLM=$HOME/.local/share/plasma/plasmoids/$ID
SID=org.dorothyos.settings
SPLM=$HOME/.local/share/plasma/plasmoids/$SID
LBIN=$HOME/.local/bin
APPSU=$HOME/.local/share/applications
ICO=$HOME/.local/share/icons/hicolor
say() { echo "[$(date +%T)] $*"; }
case "${1:-}" in
apply)
  mkdir -p "$BK"
  [ -e "$BK/appletsrc" ] || cp -a "$APPLETS" "$BK/appletsrc"
  say "1) plasmoid"
  if [ -d "/usr/share/plasma/plasmoids/$ID" ]; then say "   installed system-wide by the apk"; rm -rf "$PLM"
  else
    mkdir -p "$(dirname "$PLM")"; rm -rf "$PLM"; cp -r "$SRC/launcher/$ID" "$PLM"; say "   copied to $PLM"
  fi
  say "1b) DorothyOS Settings"
  if [ -d "/usr/share/plasma/plasmoids/$SID" ]; then say "   installed system-wide by the apk"; rm -rf "$SPLM"
  else
    mkdir -p "$(dirname "$SPLM")" "$LBIN" "$APPSU"; rm -rf "$SPLM"; cp -r "$SRC/settings/$SID" "$SPLM"
    install -m755 "$SRC/settings/dorothyos-settings-helper" "$LBIN/dorothyos-settings-helper"
    install -m755 "$SRC/settings/dorothyos-settings" "$LBIN/dorothyos-settings"
    [ -e /usr/share/applications/dorothyos-settings.desktop ] || install -m644 "$SRC/settings/dorothyos-settings.desktop" "$APPSU/dorothyos-settings.desktop"
    say "   user-level copy installed (plasmoid, helper, launcher)"
  fi
  say "2) icon (the mark in the dock)"
  if [ ! -e /usr/share/icons/hicolor/256x256/apps/dorothyos.png ] && [ -f "$SRC/launcher/icons/dorothyos-256.png" ]; then
    mkdir -p "$ICO/64x64/apps" "$ICO/256x256/apps"
    install -m644 "$SRC/launcher/icons/dorothyos-64.png" "$ICO/64x64/apps/dorothyos.png"
    install -m644 "$SRC/launcher/icons/dorothyos-256.png" "$ICO/256x256/apps/dorothyos.png"
    gtk-update-icon-cache -q -f "$ICO" 2>/dev/null || :
    say "   user-level copy installed"
  fi
  if grep -q "^plugin=$ID$" "$APPLETS"; then say "3) the dock already uses DorothyOS Start"; exit 0; fi
  say "3) swap the launcher in the dock (plasmashell stopped while the config is edited)"
  systemctl --user stop plasma-plasmashell.service; sleep 2
  sed -i -e "s/^plugin=org.kde.plasma.kickoff\$/plugin=$ID/" -e "s/^plugin=org.kde.plasma.kickerdash\$/plugin=$ID/" -e "s/^plugin=org.kde.plasma.kicker\$/plugin=$ID/" "$APPLETS"
  kbuildsycoca6 >/dev/null 2>&1
  systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null; systemctl --user start plasma-plasmashell.service; sleep 7
  if grep -q "^plugin=$ID$" "$APPLETS"; then say "done"; else say "no Kickoff launcher found in the dock - nothing replaced"; fi ;;
undo)
  [ -d "$BK" ] || { echo "no backup at $BK"; exit 1; }
  systemctl --user stop plasma-plasmashell.service; sleep 2
  cp -a "$BK/appletsrc" "$APPLETS"; rm -rf "$PLM" "$SPLM"
  rm -f "$LBIN/dorothyos-settings-helper" "$LBIN/dorothyos-settings" "$APPSU/dorothyos-settings.desktop"
  rm -f "$ICO/64x64/apps/dorothyos.png" "$ICO/256x256/apps/dorothyos.png"
  kbuildsycoca6 >/dev/null 2>&1
  systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null; systemctl --user start plasma-plasmashell.service; sleep 6
  say "undone (Kickoff is back in the dock)" ;;
*) echo "usage: $0 apply|undo"; exit 1 ;;
esac
