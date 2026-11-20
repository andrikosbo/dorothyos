#!/bin/sh
# phase10-tablet-ux-user.sh — runs ON THE TABLET as the normal user (no root). Plasma user config only: reversible.
# Second tablet pass on top of phase2b (the session is already in KWin tablet mode: auto-rotate, OSK, Overview, "tablet-maximize" rule):
#   1) optional extra apps (user Flatpaks listed in ART below; none by default): launchers on the home screen (~/Desktop)
#      and pinned in the dock
#   2) dock: a "tools" group next to the tray (Quick Launch): Keyboard, Overview, Close app
#   3) window buttons: the title bar (minimize / maximize / close) is KEPT and made touch-sized (breezerc ButtonSize=ButtonVeryLarge).
#      The dock "Close app" button stays as a second way to close the app that is on screen.
#   usage: phase10-tablet-ux-user.sh apply | undo      (expects ./tabletux/ next to this script, and pipa-rotate / pipa-keyboard
#          already installed by phase2b-look-and-feel.sh)
# Backups: ~/pipa-phase10-backup (appletsrc + plasmashellrc whole files; kwinrc is changed/undone key by key).
set -u
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-1 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
CFG=$HOME/.config
APPLETS=$CFG/plasma-org.kde.plasma.desktop-appletsrc
BK=$HOME/pipa-phase10-backup
SRC=$(cd "$(dirname "$0")" && pwd)
# the package installs the launchers flat next to the scripts; the development tree kept them in ./tabletux/
[ -d "$SRC/tabletux" ] && SRC=$SRC/tabletux
APPS=$HOME/.local/share/applications
FPEXP=$HOME/.local/share/flatpak/exports/share/applications
ART=""   # DorothyOS ships no third-party apps; list the desktop ids of extra Flatpaks here to pin them
say() { echo "[$(date +%T)] $*"; }
reconf() { qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure; }
kw() { kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc "$@"; }

case "${1:-}" in
apply)
  for a in $ART; do [ -f "$FPEXP/$a.desktop" ] || { say "ABORT: $a is not installed (install it first, e.g. flatpak install --user flathub $a)"; exit 1; }; done
  [ -f "$HOME/.local/bin/pipa-rotate" ] && [ -f "$HOME/.local/bin/pipa-keyboard" ] || { say "ABORT: run phase2b-look-and-feel.sh apply first"; exit 1; }
  mkdir -p "$BK"
  for f in plasma-org.kde.plasma.desktop-appletsrc plasmashellrc; do
    [ -e "$BK/$f" ] || [ -e "$BK/$f.ABSENT" ] || { [ -f "$CFG/$f" ] && cp -a "$CFG/$f" "$BK/$f" || : > "$BK/$f.ABSENT"; }
  done
  [ -e "$BK/kwin-borderless.old" ] || kreadconfig6 --file kwinrc --group Windows --key BorderlessMaximizedWindows --default unset > "$BK/kwin-borderless.old"
  [ -e "$BK/breeze-buttonsize.old" ] || kreadconfig6 --file breezerc --group Windeco --key ButtonSize --default ButtonLarge > "$BK/breeze-buttonsize.old"

  say "1) launchers: Overview, Close app"
  install -d "$APPS"
  for f in pipa-overview pipa-close; do install -m644 "$SRC/$f.desktop" "$APPS/$f.desktop" || { say "ABORT: $SRC/$f.desktop is missing"; exit 1; }; done

  say "2) home screen: extra apps"
  mkdir -p "$HOME/Desktop"
  : >> "$BK/desktop-files-created.txt"
  for a in $ART; do
    [ -e "$HOME/Desktop/$a.desktop" ] || { cp "$FPEXP/$a.desktop" "$HOME/Desktop/$a.desktop" && chmod 755 "$HOME/Desktop/$a.desktop" && echo "$a.desktop" >> "$BK/desktop-files-created.txt"; }
  done

  say "3) dock (plasmashell stopped while the config is edited)"
  systemctl --user stop plasma-plasmashell.service; sleep 2
  QL=$(awk '/^\[Containments\]\[2\]\[Applets\]\[[0-9]+\]$/{id=$0} /^plugin=org.kde.plasma.quicklaunch$/{print id}' "$APPLETS" | grep -oE '[0-9]+\]$' | tr -d ']' | head -1)
  if [ -z "$QL" ]; then
    # applet ids are global, nested system-tray applets included (they reach 28): take the max over every numeric group in the file
    QL=$(( $(grep '^\[' "$APPLETS" | grep -oE '\[[0-9]+\]' | tr -d '[]' | sort -n | tail -1) + 1 ))
    say "   new Quick Launch applet id $QL"
    kw --group Containments --group 2 --group Applets --group "$QL" --key plugin org.kde.plasma.quicklaunch
    kw --group Containments --group 2 --group Applets --group "$QL" --key immutability 1
    kw --group Containments --group 2 --group Applets --group "$QL" --group Configuration --group General --key showLauncherNames false
    kw --group Containments --group 2 --group Applets --group "$QL" --group Configuration --group General --key enablePopup false
    # tools group sits between the task list (+ separator) and the system tray
    sed -i "s/^AppletOrder=3;4;5;6;7;23;24\$/AppletOrder=3;4;5;6;$QL;7;23;24/" "$APPLETS"
  else say "   Quick Launch already present (id $QL)"; fi
  # tools group content (re-written on every run). Rotate Screen was removed 2026-11-19 (auto-rotate works): launcher kept in ~/.local/bin only.
  kw --group Containments --group 2 --group Applets --group "$QL" --group Configuration --group General --key launcherUrls \
    "file://$APPS/pipa-keyboard.desktop,file://$APPS/pipa-overview.desktop,file://$APPS/pipa-close.desktop"
  # task list: pin the extra apps; Rotate/Keyboard moved to the tools group
  kw --group Containments --group 2 --group Applets --group 5 --group Configuration --group General --key launchers \
    "applications:dorothyos-settings.desktop,applications:org.kde.discover.desktop,preferred://filemanager,applications:firefox.desktop"

  say "4) window buttons: title bar kept, buttons very large"
  kwriteconfig6 --file kwinrc --group Windows --key BorderlessMaximizedWindows false
  kwriteconfig6 --file breezerc --group Windeco --key ButtonSize ButtonVeryLarge

  say "5) touch edges (left = start menu, right = Overview) and the rule that opens normal windows maximized, as on the reference tablet"
  [ -e "$BK/kwin-edge-left.old" ] || kreadconfig6 --file kwinrc --group TouchEdges --key Left --default unset > "$BK/kwin-edge-left.old"
  [ -e "$BK/kwin-overview-edge.old" ] || kreadconfig6 --file kwinrc --group Effect-overview --key TouchBorderActivate --default unset > "$BK/kwin-overview-edge.old"
  kwriteconfig6 --file kwinrc --group TouchEdges --key Left ApplicationLauncher
  kwriteconfig6 --file kwinrc --group Effect-overview --key TouchBorderActivate 2
  if ! grep -q '^\[tablet-maximize\]' "$CFG/kwinrulesrc" 2>/dev/null; then
    [ -e "$BK/kwinrulesrc" ] || [ -e "$BK/kwinrulesrc.ABSENT" ] || { [ -f "$CFG/kwinrulesrc" ] && cp -a "$CFG/kwinrulesrc" "$BK/kwinrulesrc" || : > "$BK/kwinrulesrc.ABSENT"; }
    order=$(kreadconfig6 --file kwinrulesrc --group General --key Order)
    [ -n "$order" ] || { grep -q '^\[steam\]' /etc/xdg/kwinrulesrc 2>/dev/null && order=steam; }   # keep the base system's own rule active
    kwriteconfig6 --file kwinrulesrc --group General --key Order "${order:+$order,}tablet-maximize"
    for kv in "Description|Tablet: open normal windows maximized" "maximizehoriz|true" "maximizehorizrule|3" "maximizevert|true" "maximizevertrule|3" "types|1" "wmclassmatch|0"; do
      kwriteconfig6 --file kwinrulesrc --group tablet-maximize --key "${kv%%|*}" "${kv#*|}"
    done
  fi

  systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null; systemctl --user start plasma-plasmashell.service; sleep 6
  reconf
  say "done"
  ;;
undo)
  [ -d "$BK" ] || { echo "no backup at $BK"; exit 1; }
  systemctl --user stop plasma-plasmashell.service; sleep 2
  for f in plasma-org.kde.plasma.desktop-appletsrc plasmashellrc; do [ -f "$BK/$f" ] && cp -a "$BK/$f" "$CFG/$f"; done
  rm -f "$APPS/pipa-overview.desktop" "$APPS/pipa-close.desktop"
  [ -f "$BK/desktop-files-created.txt" ] && while read -r a; do [ -n "$a" ] && rm -f "$HOME/Desktop/$a"; done < "$BK/desktop-files-created.txt"
  old=$(cat "$BK/kwin-borderless.old" 2>/dev/null)
  if [ "$old" = "unset" ] || [ -z "$old" ]; then kwriteconfig6 --file kwinrc --group Windows --key BorderlessMaximizedWindows --delete; else kwriteconfig6 --file kwinrc --group Windows --key BorderlessMaximizedWindows "$old"; fi
  kwriteconfig6 --file breezerc --group Windeco --key ButtonSize "$(cat "$BK/breeze-buttonsize.old" 2>/dev/null || echo ButtonLarge)"
  for kv in "TouchEdges|Left|kwin-edge-left.old" "Effect-overview|TouchBorderActivate|kwin-overview-edge.old"; do
    g=${kv%%|*}; r=${kv#*|}; k=${r%%|*}; f=$BK/${r#*|}; old=$(cat "$f" 2>/dev/null)
    if [ -z "$old" ] || [ "$old" = unset ]; then kwriteconfig6 --file kwinrc --group "$g" --key "$k" --delete; else kwriteconfig6 --file kwinrc --group "$g" --key "$k" "$old"; fi
  done
  if [ -f "$BK/kwinrulesrc" ]; then cp -a "$BK/kwinrulesrc" "$CFG/kwinrulesrc"; elif [ -e "$BK/kwinrulesrc.ABSENT" ]; then rm -f "$CFG/kwinrulesrc"; fi
  systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null; systemctl --user start plasma-plasmashell.service; sleep 6
  reconf
  say "undone (appletsrc/plasmashellrc restored to the state before phase10; the extra Flatpaks stay installed)"
  ;;
*) echo "usage: $0 apply|undo"; exit 1 ;;
esac
