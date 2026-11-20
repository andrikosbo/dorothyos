#!/bin/sh
# phase2b-look-and-feel.sh — runs ON THE TABLET as the normal user (no root). Plasma user config only: reversible.
# Tablet look & feel: taller touch panel, large-icon home screen on the desktop, larger window-title buttons.
#   usage: phase2b-look-and-feel.sh apply | undo
# Backups of every touched file live in ~/pipa-phase2-backup/step2 (created by apply on first run).
set -u
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-1 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
CFG=$HOME/.config
APPLETS=$CFG/plasma-org.kde.plasma.desktop-appletsrc
BK=$HOME/pipa-phase2-backup/step2
SRC=$(cd "$(dirname "$0")" && pwd)   # needs pipa-rotate, pipa-keyboard (+ .desktop) next to this script
HOME_APPS="firefox.desktop org.kde.dolphin.desktop org.kde.discover.desktop systemsettings.desktop org.kde.konsole.desktop
 org.kde.gwenview.desktop org.kde.okular.desktop org.kde.kate.desktop org.kde.kcalc.desktop org.gnome.Weather.desktop
 org.kde.spectacle.desktop org.kde.plasma-systemmonitor.desktop pipa-rotate.desktop pipa-keyboard.desktop
"
APPDIRS="$HOME/.local/share/applications /usr/share/applications /var/lib/flatpak/exports/share/applications $HOME/.local/share/flatpak/exports/share/applications"
say() { echo "[$(date +%T)] $*"; }
restart_shell() { systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null; systemctl --user restart plasma-plasmashell.service; sleep 6; }

case "${1:-}" in
apply)
  mkdir -p "$BK"
  for f in plasma-org.kde.plasma.desktop-appletsrc plasmashellrc kwinrc breezerc; do
    [ -e "$BK/$f" ] || [ -e "$BK/$f.ABSENT" ] || { [ -f "$CFG/$f" ] && cp -a "$CFG/$f" "$BK/$f" || : > "$BK/$f.ABSENT"; }
  done
  say "install touch helpers: Rotate Screen + on-screen Keyboard toggle"
  install -d "$HOME/.local/bin" "$HOME/.local/share/applications"
  for f in pipa-rotate pipa-keyboard; do
    install -m755 "$SRC/$f" "$HOME/.local/bin/$f"
    # the launchers were written on a tablet whose account is "user": point them at THIS account's home (any account name is possible)
    sed "s#/home/user/#$HOME/#g" "$SRC/$f.desktop" > "$HOME/.local/share/applications/$f.desktop" && chmod 644 "$HOME/.local/share/applications/$f.desktop"
  done
  say "stop plasmashell, edit desktop containment"
  systemctl --user stop plasma-plasmashell.service; sleep 2
  # panel launcher stays Kickoff (grid mode in tablet mode); the full-screen Application Dashboard was tried and rejected
  # (search field grabs focus -> keyboard covers it, category column clipped at screen edge, small icons)
  sed -i '/^\[Containments\]\[2\]\[Applets\]\[3\]$/,/^\[Containments\]\[2\]\[Applets\]\[4\]$/ s/^plugin=org.kde.plasma.kickerdash$/plugin=org.kde.plasma.kickoff/' "$APPLETS"
  # task-manager launchers: add the Keyboard toggle after Rotate Screen
  grep -q 'pipa-keyboard.desktop' "$APPLETS" || sed -i '/^launchers=.*pipa-rotate.desktop/ s/$/,applications:pipa-keyboard.desktop/' "$APPLETS"
  # home screen = desktop folder view: very large icons, sorted by name, 2-line labels
  kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc --group Containments --group 1 --group General --key iconSize 4
  kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc --group Containments --group 1 --group General --key textLines 2
  kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc --group Containments --group 1 --group General --key sortMode 0
  kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc --group Containments --group 1 --group General --key arrangement 0
  say "home-screen launchers in ~/Desktop"
  mkdir -p "$HOME/Desktop"
  : > "$BK/desktop-files-created.txt"
  for a in $HOME_APPS; do
    for d in $APPDIRS; do
      if [ -f "$d/$a" ]; then
        [ -e "$HOME/Desktop/$a" ] || { cp "$d/$a" "$HOME/Desktop/$a" && chmod 755 "$HOME/Desktop/$a" && echo "$a" >> "$BK/desktop-files-created.txt"; }
        break
      fi
    done
  done
  say "window title-bar buttons: large"
  kwriteconfig6 --file breezerc --group Windeco --key ButtonSize ButtonLarge
  say "start plasmashell, panel thickness 56"
  systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null; systemctl --user start plasma-plasmashell.service; sleep 6
  busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s 'panelById(2).height = 56' >/dev/null
  qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure
  say "done"
  ;;
undo)
  [ -d "$BK" ] || { echo "no backup at $BK"; exit 1; }
  systemctl --user stop plasma-plasmashell.service; sleep 2
  for f in plasma-org.kde.plasma.desktop-appletsrc plasmashellrc kwinrc; do [ -f "$BK/$f" ] && cp -a "$BK/$f" "$CFG/$f"; done
  if [ -f "$BK/breezerc" ]; then cp -a "$BK/breezerc" "$CFG/breezerc"; else rm -f "$CFG/breezerc"; fi
  rm -f "$HOME/.local/bin/pipa-keyboard" "$HOME/.local/share/applications/pipa-keyboard.desktop"
  [ -f "$BK/desktop-files-created.txt" ] && while read -r a; do rm -f "$HOME/Desktop/$a"; done < "$BK/desktop-files-created.txt"
  systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null; systemctl --user start plasma-plasmashell.service; sleep 6
  qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure
  say "undone (note: this also restores kwinrc/plasma config to the state at the time of the step2 backup)"
  ;;
*) echo "usage: $0 apply|undo"; exit 1 ;;
esac
