#!/bin/sh
# pipa-camera-live.sh — run ON THE TABLET as the normal user (no root). Puts the recommended camera app on the home screen of a tablet
# that already has the old layout (GNOME Snapshot tile), i.e. what the reference tablet got by hand.
#   apply [TILE_DIR]  replaces the Snapshot tile of the home grid by Cosmic "Camera" (io.github.cosmic_utils.camera must be installed:
#                     run pipa-camera-setup first). TILE_DIR (optional) holds <style>/{512,256}/pipa-tile-io.github.cosmic_utils.camera.png
#                     made by system/make-tile-icons.py; without it the app's own icon is used.
#   undo              puts the Snapshot tile back and removes the launcher override and the tile files.
# plasmashell is stopped while its config is edited (and restarted afterwards, ~9 s).
set -e
ID=io.github.cosmic_utils.camera; OLD=org.gnome.Snapshot
A=$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc
T=$HOME/.local/share/plasma/plasmoids/org.pipa.homegrid/contents/tiles
ICO=$HOME/.local/share/icons/hicolor
APPS=$HOME/.local/share/applications
BK=$HOME/.local/share/pipa-camera-backup
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
restart() { systemctl --user stop plasma-plasmashell.service; sleep 2; "$@"; kbuildsycoca6 >/dev/null 2>&1; systemctl --user start plasma-plasmashell.service; sleep 9; }
case "${1:-}" in
apply)
  flatpak info "$ID" >/dev/null 2>&1 || { echo "install the app first: pipa-camera-setup" >&2; exit 1; }
  mkdir -p "$BK"; [ -e "$BK/appletsrc.orig" ] || cp -p "$A" "$BK/appletsrc.orig"
  PRE=""; ICON=$ID
  if [ -n "${2:-}" ]; then
    STYLE=$(pipa-icons get 2>/dev/null || echo light); case "$STYLE" in light) PRE="";; *) PRE="$STYLE-";; esac
    for st in light dark glass; do case "$st" in light) p="";; *) p="$st-";; esac
      for r in 512 256; do f=$2/$st/$r/pipa-tile-$ID.png; [ -e "$f" ] || continue
        mkdir -p "$T/$st/$r" "$ICO/${r}x${r}/apps"; cp "$f" "$T/$st/$r/"; cp "$f" "$ICO/${r}x${r}/apps/pipa-tile-${p}$ID.png"; done; done
    gtk-update-icon-cache -q -f "$ICO" 2>/dev/null || true; ICON=pipa-tile-${PRE}$ID
  fi
  [ -e "$APPS/$ID.desktop" ] && cp -p "$APPS/$ID.desktop" "$BK/$ID.desktop.orig"
  sed "s#^Icon=.*#Icon=$ICON#" "$HOME/.local/share/flatpak/exports/share/applications/$ID.desktop" > "$APPS/$ID.desktop"
  restart sed -i "s#;$OLD\$#;$ID#" "$A" ;;
undo)
  [ -e "$BK/$ID.desktop.orig" ] && cp -p "$BK/$ID.desktop.orig" "$APPS/$ID.desktop" || rm -f "$APPS/$ID.desktop"
  for st in light dark glass; do rm -f "$T/$st/512/pipa-tile-$ID.png" "$T/$st/256/pipa-tile-$ID.png"; done
  rm -f "$ICO"/*/apps/pipa-tile-*"$ID".png; gtk-update-icon-cache -q -f "$ICO" 2>/dev/null || true
  restart sed -i "s#;$ID\$#;$OLD#" "$A" ;;
*) echo "usage: $0 apply [TILE_DIR] | undo" >&2; exit 2 ;;
esac
echo done
