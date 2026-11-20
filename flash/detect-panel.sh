#!/bin/sh
# detect-panel.sh — tells which panel your Xiaomi Pad 6 has (tianma or csot). READ-ONLY. Needs the tablet booted into its
# ORIGINAL Android, USB debugging on, adb authorised on this computer. Nothing is written to the tablet.
#
# Evidence used (postmarketOS wiki, Xiaomi Pad 6): the Android kernel command line carries the display it found:
#     msm_drm.dsi_display0=qcom,mdss_dsi_m82_36_02_0a_dual_dphy_video   -> Tianma
#     msm_drm.dsi_display0=qcom,mdss_dsi_m82_42_02_0b_dual_dphy_video   -> CSOT
# If the output is anything else, the script says "unknown" and you must NOT guess: ask in the project's issues.
set -eu
command -v adb >/dev/null 2>&1 || { echo "adb not found (install android-platform-tools)"; exit 2; }
n=$(adb devices | awk 'NR>1 && $2=="device"' | wc -l | tr -d ' ')
[ "$n" = 1 ] || { echo "expected exactly one adb device in state 'device', found $n"; exit 2; }
model=$(adb shell getprop ro.product.device | tr -d '\r')
[ "$model" = pipa ] || { echo "this is not a Xiaomi Pad 6 (ro.product.device=$model)"; exit 2; }
cmd=$(adb shell cat /proc/cmdline | tr -d '\r')
case "$cmd" in
  *mdss_dsi_m82_36_02_0a*) echo tianma ;;
  *mdss_dsi_m82_42_02_0b*) echo csot ;;
  *) echo "unknown"; echo "no known display string in the kernel command line; do not guess the panel" >&2; exit 1 ;;
esac
