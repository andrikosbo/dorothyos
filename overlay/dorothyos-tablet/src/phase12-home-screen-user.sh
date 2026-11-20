#!/bin/sh
# phase12-home-screen-user.sh — runs ON THE TABLET as the normal user (no root). iPad-style home screen (Plasma user config only, reversible):
#   * uniform squircle icons (hometiles/, made by make-tile-icons.py) for a curated set of 22 apps
#   * plasmoid "org.pipa.homegrid" (homegrid/): clock + date top left, search pill, pages of those icons with page dots, drag to reorder,
#     icon size slider and Light / Dark / Glass icon style (the tile sets live inside the widget: contents/tiles/<style>/{512,256}),
#     installed per user (~/.local/share/plasma/plasmoids) and placed as a full-desktop widget on the desktop containment
#   * the apps on the home screen are the widget's config key "ids" (default = the 22 below); the user edits them on the tablet (long press ->
#     edit mode, "+" picker); the catalog of installed apps is ~/.local/bin/pipa-home-apps; launching = `kioclient exec <desktop file>`.
#     Re-running apply keeps the user's settings (list, style, size, labels, search); ~/.local/bin/pipa-icons copies the active tile set into
#     the hicolor theme so the dock follows the style
#   * the same tile icon is also set on the apps' launchers in ~/.local/share/applications (user-level override of the system .desktop file,
#     only the Icon= of the main [Desktop Entry]) so the dock, the app menu and Discover show the same squircles; the dock tools
#     (pipa-keyboard / pipa-overview / pipa-close) get their own tile icons
#   * the old icon dump on the desktop folder (~/Desktop/*.desktop) is moved to ~/pipa-phase12-backup/Desktop-orig (undo moves it back)
#   usage: phase12-home-screen-user.sh apply | undo | list      (expects ./hometiles/{light,dark,glass}/{512,256}/ and ./homegrid/ next to this script)
set -u
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-1 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
SRC=$(cd "$(dirname "$0")" && pwd)
CFG=$HOME/.config; APPLETS=$CFG/plasma-org.kde.plasma.desktop-appletsrc
BK=$HOME/pipa-phase12-backup; HOMEDIR=$HOME/.local/share/pipa-home
ICO=$HOME/.local/share/icons/hicolor
PLM=$HOME/.local/share/plasma/plasmoids/org.pipa.homegrid
APPSU=$HOME/.local/share/applications
APPDIRS="$HOME/.local/share/applications /usr/share/applications /var/lib/flatpak/exports/share/applications $HOME/.local/share/flatpak/exports/share/applications"
# order on the home screen (rows of 6): <desktop id>:<tile icon name>
ITEMS="org.kde.okular:okular org.kde.kate:kate org.kde.kcalc:accessories-calculator firefox:firefox org.kde.dolphin:org.kde.dolphin
 org.kde.gwenview:gwenview pipa-camera:org.gnome.Snapshot org.kde.discover:plasmadiscover dorothyos-settings:preferences-system
 org.kde.konsole:utilities-terminal org.kde.plasma-systemmonitor:utilities-system-monitor org.kde.spectacle:spectacle"
say() { echo "[$(date +%T)] $*"; }
# only the Icon= of the main [Desktop Entry] (not the ones of [Desktop Action ...])
seticon() { sed -i "/^\[Desktop Entry\]/,/^\[/ s|^Icon=.*|Icon=$2|" "$1"; }
ov_apply() { # id source-file tile-icon-name
  ov="$APPSU/$1.desktop"
  if [ -e "$ov" ]; then
    grep -qx "$1" "$BK/override-created.txt" 2>/dev/null || [ -e "$BK/apps-orig/$1.desktop" ] || cp -a "$ov" "$BK/apps-orig/$1.desktop"
  else
    echo "$1" >> "$BK/override-created.txt"; cp "$2" "$ov"
  fi
  seticon "$ov" "pipa-tile-$3"; chmod 755 "$ov"
  # D-Bus activation of flatpak apps (DBusActivatable=true) is not reliable from kioclient / the home screen: Exec= does the same job (Weather did not start)
  sed -i '/^DBusActivatable=/d' "$ov"
}
find_desktop() { for d in $APPDIRS; do [ -f "$d/$1.desktop" ] && { echo "$d/$1.desktop"; return 0; }; done; return 1; }
kw() { kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc "$@"; }
case "${1:-}" in
list) for it in $ITEMS; do echo "${it%%:*}"; done ;;
apply)
  mkdir -p "$BK/Desktop-orig" "$BK/apps-orig"; touch "$BK/override-created.txt"
  [ -e "$BK/appletsrc" ] || cp -a "$APPLETS" "$BK/appletsrc"
  say "1) widget + helpers + icon sets"
  STYLE=$(sed -n 's/^iconStyle=//p' "$APPLETS" | tail -1); case "$STYLE" in light|dark|glass) ;; *) STYLE=light ;; esac
  rm -rf "$HOMEDIR" "$PLM"; mkdir -p "$(dirname "$PLM")" "$HOME/.local/bin" "$HOMEDIR"; cp -r "$SRC/homegrid/org.pipa.homegrid" "$PLM"
  mkdir -p "$PLM/contents/tiles"; cp -r "$SRC/hometiles/light" "$SRC/hometiles/dark" "$SRC/hometiles/glass" "$PLM/contents/tiles/"
  install -m755 "$SRC/homegrid/pipa-home-apps" "$HOME/.local/bin/pipa-home-apps"
  install -m755 "$SRC/homegrid/pipa-icons" "$HOME/.local/bin/pipa-icons"
  say "2) tile overrides"
  DEF=""; n=0
  for it in $ITEMS; do
    id=${it%%:*}; ic=${it##*:}; f=$(find_desktop "$id") || { say "   skip (not installed): $id"; continue; }
    n=$((n+1))
    # an app without a tile in the shipped sets (e.g. a third-party brand) keeps its own icon, which the grid draws on a plate
    if [ -f "$SRC/hometiles/light/512/pipa-tile-$ic.png" ]; then ov_apply "$id" "$f" "$ic"; else say "   no tile image for $id: it keeps its own icon"; fi
    DEF="$DEF${DEF:+;}$id"
  done
  sed -i "s|@DEFAULT_IDS@|$DEF|" "$PLM/contents/config/main.xml"; say "   $n apps in the default list"
  say "2b) dock tool icons"
  for t in keyboard overview close; do [ -f "$APPSU/pipa-$t.desktop" ] && seticon "$APPSU/pipa-$t.desktop" "pipa-tile-pipa-$t"; done
  "$HOME/.local/bin/pipa-icons" set "$STYLE" force; say "   icon style: $STYLE (all three sets installed in hicolor, launchers use '$STYLE')"
  say "3) move the old desktop icons away"
  for f in "$HOME"/Desktop/*.desktop; do [ -e "$f" ] && mv "$f" "$BK/Desktop-orig/"; done
  say "4) place the widget (plasmashell stopped while the config is edited)"
  systemctl --user stop plasma-plasmashell.service; sleep 2
  ID=$(python3 - "$APPLETS" <<'PY'
import re, sys
p = sys.argv[1]; txt = open(p).read().split("\n")
secs = []; cur = None
for l in txt:
    if l.startswith("["): cur = [l, []]; secs.append(cur)
    elif cur is None: secs.append([None, [l]])
    else: cur[1].append(l)
def plugin(h):
    for hh, body in secs:
        if hh == h:
            for l in body:
                if l.startswith("plugin="): return l[7:]
drop = set(); keep_cfg = []
for h, _ in secs:
    m = h and re.match(r"^\[Containments\]\[1\]\[Applets\]\[(\d+)\]$", h)
    if m and plugin(h) in ("org.pipa.homegrid", "org.kde.plasma.folder", "org.kde.plasma.digitalclock"): drop.add(m.group(1))
for h, body in secs:
    m = h and re.match(r"^\[Containments\]\[1\]\[Applets\]\[(\d+)\]\[Configuration\]\[General\]$", h)
    if m and m.group(1) in drop and plugin("[Containments][1][Applets][%s]" % m.group(1)) == "org.pipa.homegrid":
        keep_cfg = [l for l in body if l.strip()]
nums = [int(n) for h, _ in secs if h for n in re.findall(r"\[(\d+)\]", h)]
new = max(nums) + 1
out = []
for h, body in secs:
    if h and any(h.startswith("[Containments][1][Applets][%s]" % d) for d in drop): continue
    out.append(h) if h else None
    out.extend(body)
while out and out[-1] == "": out.pop()
out += ["", "[Containments][1][Applets][%d]" % new, "immutability=1", "plugin=org.pipa.homegrid", ""]
if keep_cfg: out += ["[Containments][1][Applets][%d][Configuration][General]" % new] + keep_cfg + [""]
open(p, "w").write("\n".join(out))
print(new)
PY
)
  say "   applet id $ID"
  for k in "ItemGeometries-1152x720:1152,720" "ItemGeometriesHorizontal:1152,720" "ItemGeometries-720x1152:720,1152" "ItemGeometriesVertical:720,1152"; do
    kw --group Containments --group 1 --key "${k%%:*}" "Applet-$ID:0,0,${k##*:},0;"
  done
  # lock the desktop (2 = user-immutable): a long press can no longer pick the full-screen widget up, move or resize it (it happened once)
  kw --group Containments --group 1 --key immutability 2
  kbuildsycoca6 >/dev/null 2>&1          # before plasmashell starts: otherwise the task manager drops pinned launchers it cannot resolve yet
  systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null; systemctl --user start plasma-plasmashell.service; sleep 7
  say "done" ;;
undo)
  [ -d "$BK" ] || { echo "no backup at $BK"; exit 1; }
  systemctl --user stop plasma-plasmashell.service; sleep 2
  cp -a "$BK/appletsrc" "$APPLETS"
  mkdir -p "$HOME/Desktop"; for f in "$BK/Desktop-orig/"*.desktop; do [ -e "$f" ] && mv "$f" "$HOME/Desktop/"; done
  while read -r id; do [ -n "$id" ] && rm -f "$APPSU/$id.desktop"; done < "$BK/override-created.txt"
  for f in "$BK/apps-orig/"*.desktop; do [ -e "$f" ] && cp -a "$f" "$APPSU/"; done
  for t in "keyboard:input-keyboard-virtual" "overview:window-duplicate" "close:window-close"; do [ -f "$APPSU/pipa-${t%%:*}.desktop" ] && seticon "$APPSU/pipa-${t%%:*}.desktop" "${t##*:}"; done
  rm -rf "$HOMEDIR" "$PLM"; rm -f "$HOME/.local/bin/pipa-home-apps" "$HOME/.local/bin/pipa-icons" "$HOMEDIR"/icon-style* "$ICO"/512x512/apps/pipa-tile-*.png "$ICO"/256x256/apps/pipa-tile-*.png
  gtk-update-icon-cache -q -f "$ICO" 2>/dev/null; kbuildsycoca6 >/dev/null 2>&1
  systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null; systemctl --user start plasma-plasmashell.service; sleep 6
  say "undone (previous desktop icons and widgets restored)" ;;
*) echo "usage: $0 apply|undo|list"; exit 1 ;;
esac
