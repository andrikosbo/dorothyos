#!/bin/sh
# phase15-dock-settings-user.sh — runs ON THE TABLET as the normal user (no root). Dock + status bar settings (user config only, reversible):
#   * ~/.local/bin/pipa-dock (+ pipa_dock_theme.py): sets the dock look (opacity, roundness, size, auto-hide inside apps), the status-bar opacity,
#     and manages the dock's apps (the Task Manager launchers). The look is a generated Plasma desktop theme "pipa-dock-<n>" (nine-patch panel
#     background: "south-" prefix = bottom dock, "north-" prefix = top status bar) applied with plasma-apply-desktoptheme; size and auto-hide go
#     through the plasmashell scripting API.
#   * the controls are in the home screen: sliders button (top right) -> sheet tab "Dock & bar" (installed by phase12, org.pipa.homegrid).
#     The sheet runs: pipa-dock apply dockAlpha= dockRadius= dockSize= barAlpha= dockHide=  /  launchers | add | remove | move | reset
#   Installing changes nothing visible; the look only changes when a slider is moved (or pipa-dock apply is run).
#   usage: phase15-dock-settings-user.sh apply | undo      (expects ./dock/ next to this script; run after phase12 + phase14)
set -u
SRC=$(cd "$(dirname "$0")" && pwd)
export XDG_RUNTIME_DIR=/run/user/$(id -u) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
BIN=$HOME/.local/bin
say() { echo "[$(date +%T)] $*"; }
case "${1:-}" in
apply)
  mkdir -p "$BIN"
  install -m755 "$SRC/dock/pipa-dock" "$BIN/pipa-dock"
  install -m644 "$SRC/dock/pipa_dock_theme.py" "$BIN/pipa_dock_theme.py"
  say "installed pipa-dock; current look: $("$BIN/pipa-dock" get)"
  say "done (open the sliders button on the home screen -> Dock & bar)" ;;
undo)
  [ -x "$BIN/pipa-dock" ] && "$BIN/pipa-dock" reset >/dev/null 2>&1
  rm -f "$BIN/pipa-dock" "$BIN/pipa_dock_theme.py"; rm -rf "$HOME/.local/share/pipa-home/dock.json"
  say "undone (default Plasma panel theme, dock 56 px, top bar 32 px; the dock's apps were not touched)" ;;
*) echo "usage: $0 apply|undo"; exit 1 ;;
esac
