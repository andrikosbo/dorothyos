#!/bin/sh
# phase17-device-defaults-user.sh — user level (no root). Display and input defaults of the Xiaomi Pad 6 that the reference tablet
# has and that the other phases do not set:
#   * on-screen keyboard: KWin Wayland input method = Plasma Keyboard (appears when a text field is tapped)
#   * display scale 250 % (the 11" 2880x1800 panel is far too small at 100 %; 250 % is what the dock / home-screen sizes are tuned
#     for) for KWin's output AND for Xwayland applications
# The screen rotation itself is left to KWin (auto-rotate "in tablet mode", accelerometer through iio-sensor-proxy).
# Idempotent. usage: phase17-device-defaults-user.sh apply | undo
set -u
CFG=$HOME/.config
BK=$HOME/pipa-phase17-backup
SCALE=${PIPA_SCALE:-2.5}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
say() { echo "[$(date +%T)] $*"; }
case "${1:-}" in
apply)
  mkdir -p "$BK"
  [ -e "$BK/kwinrc" ] || { [ -f "$CFG/kwinrc" ] && cp -a "$CFG/kwinrc" "$BK/kwinrc" || : > "$BK/kwinrc.ABSENT"; }
  say "1) on-screen keyboard"
  kwriteconfig6 --file kwinrc --group Wayland --key InputMethod /usr/share/applications/org.kde.plasma.keyboard.desktop
  kwriteconfig6 --file kwinrc --group Wayland --key VirtualKeyboardEnabled true
  kwriteconfig6 --file kwinrc --group Xwayland --key Scale "$SCALE"
  say "2) display scale $SCALE"
  out=$(kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk '/^Output:/ {print $3; exit}')
  if [ -n "$out" ]; then
    kscreen-doctor "output.$out.scale.$SCALE" >/dev/null 2>&1 && say "   $out -> scale $SCALE" || say "   kscreen-doctor could not set the scale (set it in System Settings > Display)"
  else
    say "   no output found (no running Wayland session?) - set the scale in System Settings > Display"
  fi
  qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || :
  say "done" ;;
undo)
  if [ -e "$BK/kwinrc" ]; then cp -a "$BK/kwinrc" "$CFG/kwinrc"; else
    kwriteconfig6 --file kwinrc --group Wayland --key InputMethod --delete
    kwriteconfig6 --file kwinrc --group Wayland --key VirtualKeyboardEnabled --delete
    kwriteconfig6 --file kwinrc --group Xwayland --key Scale --delete
  fi
  out=$(kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk '/^Output:/ {print $3; exit}')
  [ -n "$out" ] && kscreen-doctor "output.$out.scale.1" >/dev/null 2>&1 || :
  qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || :
  say "undone" ;;
*) echo "usage: $0 apply|undo"; exit 1 ;;
esac
