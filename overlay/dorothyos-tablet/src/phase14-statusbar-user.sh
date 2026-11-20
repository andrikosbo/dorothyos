#!/bin/sh
# phase14-statusbar-user.sh — run ON THE TABLET as the normal user (no root).
# iPad look for the panels:
#   * NEW top panel = status bar (32 px, transparent): clock + date on the left, control-center button and the system tray on the right
#   * the bottom panel becomes a small centered floating dock (only: launcher, pager, task icons, quick-launch tools); clock, tray, control
#     center and the show-desktop button leave it (bottom-edge swipe already goes home)
#   * window animations: KWin "magic lamp" is NOT used (it needs the minimized icon geometry from a task bar); minimize/open use the
#     built-in squash + scale effects that are already active — this script only makes sure they are enabled
# The applets keep their ids (so the control-center shortcut, the KWin top-edge script and the tray config stay valid).
#   usage: phase14-statusbar-user.sh apply | undo
set -e
APPLETS=$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc
SHELLRC=$HOME/.config/plasmashellrc
BK=$HOME/pipa-phase14-backup
say() { echo "[$(date +%T)] $*"; }
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}

# step 2+3 are a function so that a re-run (the top panel already exists) still finishes the dock
ensure_shell() { systemctl --user is-active --quiet plasma-plasmashell.service || { systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null; systemctl --user start plasma-plasmashell.service; sleep 8; }; }
looks() {
  say "2) panel looks (live, plasmashell scripting)"
  qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
    var ps = panels();
    for (var i = 0; i < ps.length; i++) {
      var p = ps[i];
      if (p.location == 'top') { p.height = 32; p.opacity = 'translucent'; p.floating = false; p.lengthMode = 'fill'; }
      if (p.location == 'bottom') { p.lengthMode = 'fit'; p.alignment = 'center'; p.opacity = 'adaptive'; p.floating = true; }
    }" >/dev/null
  say "3) window animations: make sure squash + scale (open/minimize) are on"
  for e in squash scale; do kwriteconfig6 --notify --file kwinrc --group Plugins --key ${e}Enabled true; done
  qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1
}

case "${1:-}" in
apply)
  mkdir -p "$BK"
  [ -e "$BK/appletsrc" ] || cp -a "$APPLETS" "$BK/appletsrc"
  [ -e "$BK/plasmashellrc" ] || cp -a "$SHELLRC" "$BK/plasmashellrc"
  # already applied? (a top panel exists)
  if grep -q "^location=3$" "$APPLETS"; then say "a top panel already exists - only (re)applying the panel looks"; ensure_shell; looks; say "done"; exit 0; fi
  say "1) panels (plasmashell stopped while the config is edited)"
  systemctl --user stop plasma-plasmashell.service; sleep 2
  NEW=$(python3 - "$APPLETS" <<'PY'
import re, sys
p = sys.argv[1]; lines = open(p).read().split("\n")
# which applet ids of the dock are which plugin
cur = None; plug = {}
for l in lines:
    m = re.match(r"^\[Containments\]\[2\]\[Applets\]\[(\d+)\]$", l)
    if m: cur = m.group(1)
    elif l.startswith("["): cur = None
    elif cur and l.startswith("plugin="): plug[cur] = l.split("=", 1)[1]
def idof(name):
    for k, v in plug.items():
        if v == name: return k
clock, tray, cc, sd = (idof("org.kde.plasma.digitalclock"), idof("org.kde.plasma.systemtray"),
                       idof("org.pipa.controlcenter"), idof("org.kde.plasma.showdesktop"))
move = [x for x in (tray, clock, cc) if x]
top = max(int(n) for l in lines if l.startswith("[") for n in re.findall(r"\[(\d+)\]", l))
panel, spacer = str(top + 1), str(top + 2)
out = []
sec = None
for l in lines:
    if l.startswith("["):
        sec = l
        # drop the show-desktop button
        if sd and sec.startswith("[Containments][2][Applets][%s]" % sd):
            continue_skip = True
        else:
            continue_skip = False
        # move the status-bar applets (and everything nested below them) to the new panel
        for a in move:
            pre = "[Containments][2][Applets][%s]" % a
            if sec == pre or sec.startswith(pre[:-1] + "]["):
                l = "[Containments][%s][Applets][%s]" % (panel, a) + sec[len(pre):]
                sec = l
        if continue_skip: sec = "__skip__"
        out.append(l if sec != "__skip__" else "__skip__")
        continue
    if sec == "__skip__": continue
    if sec == "[Containments][2][General]" and l.startswith("AppletOrder="):
        keep = [x for x in l.split("=", 1)[1].split(";") if x not in move and x != sd]
        l = "AppletOrder=" + ";".join(keep)
    out.append(l)
# remove the skipped section headers
res = []
for l in out:
    if l == "__skip__": continue
    res.append(l)
while res and res[-1] == "": res.pop()
order = ";".join(x for x in (clock, spacer, cc, tray) if x)
res += ["",
        "[Containments][%s]" % panel, "activityId=", "formfactor=2", "immutability=1", "lastScreen=0", "location=3",
        "plugin=org.kde.panel", "wallpaperplugin=org.kde.image", "",
        "[Containments][%s][Applets][%s]" % (panel, spacer), "immutability=1", "plugin=org.kde.plasma.panelspacer", "",
        "[Containments][%s][General]" % panel, "AppletOrder=" + order, ""]
open(p, "w").write("\n".join(res))
print("%s %s %s" % (panel, clock, spacer))
PY
)
  PANEL=${NEW%% *}; REST=${NEW#* }; CLOCK=${REST%% *}
  say "   top panel containment $PANEL (clock applet $CLOCK)"
  # clock: "Tue 19 Nov  09:41" in one line, 24 h
  for kv in showDate=true dateDisplayFormat=BesideTime dateFormat=custom "customDateFormat=ddd d MMM" use24hFormat=2; do
    kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc --group Containments --group "$PANEL" --group Applets --group "$CLOCK" \
      --group Configuration --group Appearance --key "${kv%%=*}" "${kv#*=}"
  done
  # panel view: thin, not floating
  kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel $PANEL" --key floating 0
  kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel $PANEL" --group Defaults --key thickness 32
  kbuildsycoca6 >/dev/null 2>&1
  systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null; systemctl --user start plasma-plasmashell.service; sleep 8
  (command -v pipa-statusbar-guard >/dev/null 2>&1 && pipa-statusbar-guard) >/dev/null 2>&1 &   # Plasma resets the bar to 54 px on every start; the guard puts 32 px back
  looks
  say "done" ;;
undo)
  [ -d "$BK" ] || { echo "no backup at $BK"; exit 1; }
  systemctl --user stop plasma-plasmashell.service; sleep 2
  cp -a "$BK/appletsrc" "$APPLETS"; cp -a "$BK/plasmashellrc" "$SHELLRC"
  kbuildsycoca6 >/dev/null 2>&1
  systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null; systemctl --user start plasma-plasmashell.service; sleep 7
  (command -v pipa-statusbar-guard >/dev/null 2>&1 && pipa-statusbar-guard) >/dev/null 2>&1 &   # Plasma resets the bar to 54 px on every start; the guard puts 32 px back
  say "undone (panels as before; window effects left on)" ;;
*) echo "usage: $0 apply|undo"; exit 1 ;;
esac
