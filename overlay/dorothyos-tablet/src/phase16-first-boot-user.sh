#!/bin/sh
# phase16-first-boot-user.sh — runs ON THE TABLET as the normal user (no root). A calmer first start, tablet style (user config only, reversible):
#   * no Plasma splash screen between login and the home screen (ksplashrc Theme=None) - the wallpaper/home grid appears straight away
#   * three useless autostarts are switched off (a hidden copy in ~/.config/autostart): Evolution alarm notifier (pulls in evolution-source-registry
#     + addressbook factory), xwaylandvideobridge (screen sharing of X11 windows, ~60 MB), gmenudbusmenuproxy (global menu for GTK apps, no global
#     menu on the tablet). Together about 180 MB of RAM. KDE Connect, Discover notifier, Spectacle, pipewire/pulseaudio stay.
#   * screen timings like a tablet: on battery dim after 1 min and screen off after 2 min, on power dim after 2 min and off after 5 min
#     (the lock screen keeps its own timer; Plasma still holds the screen on while a video plays)
#   * power button, ONE tap = lock + soft sleep like an iPad: the lock screen appears at once and the screen switches off 5 s later (PowerDevil
#     PowerButtonAction=32 "lock screen" + "turn off display when locked after 5 s"); a tap or a touch wakes it to the lock screen again.
#     (The old setting was 1 = suspend-to-RAM; the tablet only has s2idle, and sshd's "Active PAM session" inhibitor blocks it while any ssh
#     session is open, so the button seemed to do nothing during development.)
#   Takes effect at the next login (or reboot).  usage: phase16-first-boot-user.sh apply | undo
set -u
CFG=$HOME/.config
AUTO=$CFG/autostart
BK=$HOME/pipa-phase16-backup
say() { echo "[$(date +%T)] $*"; }
HIDE="org.gnome.Evolution-alarm-notify org.kde.xwaylandvideobridge gmenudbusmenuproxy"
# group key value pairs: "<profile> <key> <seconds>"
TIMES="Battery DimDisplayIdleTimeoutSec 60
Battery TurnOffDisplayIdleTimeoutSec 120
AC DimDisplayIdleTimeoutSec 120
AC TurnOffDisplayIdleTimeoutSec 300"
case "${1:-}" in
apply)
  mkdir -p "$BK" "$AUTO"
  [ -e "$BK/ksplashrc" ] || { [ -e "$CFG/ksplashrc" ] && cp -a "$CFG/ksplashrc" "$BK/ksplashrc" || : > "$BK/ksplashrc.none"; }
  [ -e "$BK/powerdevilrc" ] || cp -a "$CFG/powerdevilrc" "$BK/powerdevilrc" 2>/dev/null || : > "$BK/powerdevilrc.none"
  say "1) no Plasma splash"
  kwriteconfig6 --file ksplashrc --group KSplash --key Engine none
  kwriteconfig6 --file ksplashrc --group KSplash --key Theme None
  say "2) autostarts off"
  for n in $HIDE; do
    [ -e "/etc/xdg/autostart/$n.desktop" ] || { say "   ($n is not installed)"; continue; }
    printf '[Desktop Entry]\nHidden=true\n' > "$AUTO/$n.desktop"; say "   $n"
  done
  say "3) screen timings"
  for prof in AC Battery LowBattery; do
    kwriteconfig6 --file powerdevilrc --group "$prof" --group SuspendAndShutdown --key PowerButtonAction 32
    kwriteconfig6 --file powerdevilrc --group "$prof" --group Display --key TurnOffDisplayWhenIdle true
    kwriteconfig6 --file powerdevilrc --group "$prof" --group Display --key TurnOffDisplayIdleTimeoutWhenLockedSec 5
  done
  echo "$TIMES" | while read -r prof key val; do
    kwriteconfig6 --file powerdevilrc --group "$prof" --group Display --key DimDisplayWhenIdle true
    kwriteconfig6 --file powerdevilrc --group "$prof" --group Display --key TurnOffDisplayWhenIdle true
    kwriteconfig6 --file powerdevilrc --group "$prof" --group Display --key "$key" "$val"
  done
  say "done - active from the next login" ;;
undo)
  if [ -e "$BK/ksplashrc" ]; then cp -a "$BK/ksplashrc" "$CFG/ksplashrc"; else rm -f "$CFG/ksplashrc"; fi
  for n in $HIDE; do [ "$(cat "$AUTO/$n.desktop" 2>/dev/null)" = "$(printf '[Desktop Entry]\nHidden=true')" ] && rm -f "$AUTO/$n.desktop"; done
  if [ -e "$BK/powerdevilrc" ]; then cp -a "$BK/powerdevilrc" "$CFG/powerdevilrc"; else rm -f "$CFG/powerdevilrc"; fi
  say "undone (active from the next login)" ;;
*) echo "usage: $0 apply|undo"; exit 1 ;;
esac
