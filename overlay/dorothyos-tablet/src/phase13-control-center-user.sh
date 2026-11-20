#!/bin/sh
# phase13-control-center-user.sh — runs ON THE TABLET as the normal user (no root). Touch control center in the dock (Plasma user config only, reversible):
#   * Plasma widget "org.pipa.controlcenter" (controlcenter/, QML only) in ~/.local/share/plasma/plasmoids, placed in the panel just before the system tray
#   * helpers ~/.local/bin/pipa-cc (Wi-Fi, Bluetooth, night light, rotation lock, brightness, volume, screenshot ... as shell commands)
#     and ~/.local/bin/pipa-dnd (holds a "Do not disturb" inhibition on the notification server while the unit pipa-dnd.service runs)
#   * dock icon: tile pipa-tile-pipa-controls (hometiles/)
#   * the panel drops down at the top right: from the dock button, from the global shortcut Meta+Shift+C, and from a swipe down from the
#     top edge of the screen (KWin script pipa-top-edge: touch edge -> kglobalaccel "activate widget <id>")
#   * swipe up from the bottom edge = home (KWin touch edge Bottom -> ShowDesktop; the right edge already opens the window overview,
#     the left edge the application launcher)
#   usage: phase13-control-center-user.sh apply | undo      (expects ./controlcenter/ and ./hometiles/ next to this script)
set -u
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-1 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
SRC=$(cd "$(dirname "$0")" && pwd)
APPLETS=$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc
BK=$HOME/pipa-phase13-backup
PLM=$HOME/.local/share/plasma/plasmoids/org.pipa.controlcenter
ICO=$HOME/.local/share/icons/hicolor
say() { echo "[$(date +%T)] $*"; }
case "${1:-}" in
apply)
  mkdir -p "$BK" "$HOME/.local/bin" "$(dirname "$PLM")"
  [ -e "$BK/appletsrc" ] || cp -a "$APPLETS" "$BK/appletsrc"
  say "1) files"
  rm -rf "$PLM"; cp -r "$SRC/controlcenter/org.pipa.controlcenter" "$PLM"
  install -m755 "$SRC/controlcenter/pipa-cc" "$SRC/controlcenter/pipa-dnd" "$HOME/.local/bin/"
  for s in 512 256; do mkdir -p "$ICO/${s}x${s}/apps"; cp "$SRC/hometiles/light/$s/pipa-tile-pipa-controls.png" "$ICO/${s}x${s}/apps/"; done
  gtk-update-icon-cache -q -f "$ICO" 2>/dev/null
  say "2) dock (plasmashell stopped while the config is edited)"
  systemctl --user stop plasma-plasmashell.service; sleep 2
  ID=$(python3 - "$APPLETS" <<'PY'
import re, sys
p = sys.argv[1]; txt = open(p).read().split("\n")
def find(plugin, any_panel=False):
    cur = None
    for l in txt:
        m = re.match(r"^\[Containments\]\[%s\]\[Applets\]\[(\d+)\]$" % (r"\d+" if any_panel else "2"), l)
        if m: cur = m.group(1)
        elif l.startswith("["): cur = None
        elif cur and l == "plugin=" + plugin: return cur
have = find("org.pipa.controlcenter", True)   # also when phase14 moved it to the status bar
if have: print(have); sys.exit(0)
tray = find("org.kde.plasma.systemtray")
new = max(int(n) for l in txt if l.startswith("[") for n in re.findall(r"\[(\d+)\]", l)) + 1
sec = None
for i, l in enumerate(txt):
    if l.startswith("["): sec = l
    elif sec == "[Containments][2][General]" and l.startswith("AppletOrder="):
        parts = l.split("=", 1)[1].split(";")
        parts.insert(parts.index(tray), str(new)) if tray in parts else parts.append(str(new))
        txt[i] = "AppletOrder=" + ";".join(parts)
while txt and txt[-1] == "": txt.pop()
txt += ["", "[Containments][2][Applets][%d]" % new, "immutability=1", "plugin=org.pipa.controlcenter", ""]
open(p, "w").write("\n".join(txt)); print(new)
PY
)
  say "   control center applet id $ID"
  kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc --group Containments --group 2 --group Applets --group "$ID" --group Shortcuts --key global "Meta+Shift+C"
  kbuildsycoca6 >/dev/null 2>&1
  say "3) top-edge swipe (KWin script)"
  KS=$HOME/.local/share/kwin/scripts/pipa-top-edge
  rm -rf "$KS"; mkdir -p "$(dirname "$KS")"; cp -r "$SRC/controlcenter/kwin-script/pipa-top-edge" "$KS"
  sed -i "s/@CC_ID@/$ID/" "$KS/contents/ui/main.qml"
  kwriteconfig6 --notify --file kwinrc --group Plugins --key pipa-top-edgeEnabled true
  kwriteconfig6 --notify --file kwinrc --group TouchEdges --key Bottom ShowDesktop
  systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null; systemctl --user start plasma-plasmashell.service; sleep 7
  qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1
  say "done" ;;
undo)
  [ -d "$BK" ] || { echo "no backup at $BK"; exit 1; }
  systemctl --user stop pipa-dnd.service 2>/dev/null
  kwriteconfig6 --notify --file kwinrc --group Plugins --key pipa-top-edgeEnabled --delete
  kwriteconfig6 --notify --file kwinrc --group TouchEdges --key Bottom --delete; qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1
  rm -rf "$HOME/.local/share/kwin/scripts/pipa-top-edge"
  systemctl --user stop plasma-plasmashell.service; sleep 2
  python3 - "$APPLETS" <<'PY'
import re, sys
p = sys.argv[1]; txt = open(p).read().split("\n")
cur = None; ids = set()
for l in txt:
    m = re.match(r"^\[Containments\]\[2\]\[Applets\]\[(\d+)\]$", l)
    if m: cur = m.group(1)
    elif l.startswith("["): cur = None
    elif cur and l == "plugin=org.pipa.controlcenter": ids.add(cur)
out = []; skip = False; sec = None
for l in txt:
    if l.startswith("["):
        sec = l; skip = any(l.startswith("[Containments][2][Applets][%s]" % i) for i in ids)
    if skip: continue
    if sec == "[Containments][2][General]" and l.startswith("AppletOrder="):
        l = "AppletOrder=" + ";".join(x for x in l.split("=", 1)[1].split(";") if x not in ids)
    out.append(l)
open(p, "w").write("\n".join(out))
PY
  rm -rf "$PLM"; rm -f "$HOME/.local/bin/pipa-cc" "$HOME/.local/bin/pipa-dnd" "$ICO"/512x512/apps/pipa-tile-pipa-controls.png "$ICO"/256x256/apps/pipa-tile-pipa-controls.png
  gtk-update-icon-cache -q -f "$ICO" 2>/dev/null
  systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null; systemctl --user start plasma-plasmashell.service; sleep 6
  say "undone (night light / rotation lock / brightness are left as they are: use System Settings if one stays on)" ;;
*) echo "usage: $0 apply|undo"; exit 1 ;;
esac
