#!/bin/sh
# phase11-wallpaper-user.sh — runs ON THE TABLET as the normal user (no root). Hourly desktop + lock-screen wallpaper rotation.
# Pictures: the DorothyOS wallpaper packages (/usr/share/wallpapers/DorothyOS-*/contents/images/2880x1800.jpg, package dorothyos-branding),
# or any <category>/*.jpg the user already keeps in ~/Pictures/Wallpapers.  Needs ./wallpaper/ next to this script.
#   usage: phase11-wallpaper-user.sh apply | undo
set -u
export XDG_RUNTIME_DIR=/run/user/$(id -u) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus WAYLAND_DISPLAY=wayland-1
SRC=$(cd "$(dirname "$0")" && pwd)/wallpaper
SYS=/usr/share/wallpapers
U=$HOME/.config/systemd/user; BK=$HOME/pipa-phase11-backup
case "${1:-}" in
apply)
  # the pictures are installed system-wide by dorothyos-branding as KDE wallpaper packages; link them into one category folder of the home folder
  if ! ls "$HOME/Pictures/Wallpapers"/*/*.jpg >/dev/null 2>&1; then
    if ls "$SYS"/DorothyOS-*/contents/images/2880x1800.jpg >/dev/null 2>&1; then
      mkdir -p "$HOME/Pictures/Wallpapers/DorothyOS"
      for f in "$SYS"/DorothyOS-*/contents/images/2880x1800.jpg; do n=${f#$SYS/}; n=${n%%/*}; ln -sf "$f" "$HOME/Pictures/Wallpapers/DorothyOS/$n.jpg"; done
      cp /usr/share/licenses/dorothyos-branding/ARTWORK-LICENSE.txt "$HOME/Pictures/Wallpapers/DorothyOS/LICENSE.txt" 2>/dev/null || :
    else echo "no wallpaper pictures installed - skipping the hourly wallpaper rotation"; exit 0; fi
  fi
  mkdir -p "$BK" "$U" "$HOME/.local/bin"
  [ -e "$BK/kscreenlockerrc" ] || [ -e "$BK/kscreenlockerrc.ABSENT" ] || { [ -f "$HOME/.config/kscreenlockerrc" ] && cp -a "$HOME/.config/kscreenlockerrc" "$BK/" || : > "$BK/kscreenlockerrc.ABSENT"; }
  install -m755 "$SRC/pipa-wallpaper" "$HOME/.local/bin/pipa-wallpaper"
  install -m644 "$SRC/pipa-wallpaper.service" "$SRC/pipa-wallpaper.timer" "$U/"
  systemctl --user daemon-reload; systemctl --user enable --now pipa-wallpaper.timer
  "$HOME/.local/bin/pipa-wallpaper" next
  systemctl --user list-timers pipa-wallpaper.timer --no-pager ;;
undo)
  systemctl --user disable --now pipa-wallpaper.timer 2>/dev/null
  rm -f "$U/pipa-wallpaper.service" "$U/pipa-wallpaper.timer" "$HOME/.local/bin/pipa-wallpaper"; systemctl --user daemon-reload
  if [ -f "$BK/kscreenlockerrc" ]; then cp -a "$BK/kscreenlockerrc" "$HOME/.config/kscreenlockerrc"; else rm -f "$HOME/.config/kscreenlockerrc"; fi
  d=$(ls "$SYS"/DorothyOS-*/contents/images/2880x1800.jpg 2>/dev/null | head -n1); [ -n "$d" ] && plasma-apply-wallpaperimage "$d"
  rm -rf "$HOME/.local/state/pipa-wallpaper"
  echo "undone (pictures in ~/Pictures/Wallpapers are kept)" ;;
*) echo "usage: $0 apply|undo"; exit 1 ;;
esac
