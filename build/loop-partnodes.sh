#!/bin/sh
# loop-partnodes.sh — create /dev/loopNpM nodes for loop devices with partitions.
# Docker Desktop's VM has no udev: after `losetup -P` the kernel scans the partitions (they show up in /sys) but no
# /dev/loopXpY node appears, and pmbootstrap fails with "File did not appear: /dev/loop0p2".  This tiny loop makes the
# nodes from sysfs.  Start it in the background before `pmbootstrap install`; stop it with kill (it is harmless on a
# normal Linux host that has udev: it only creates nodes that are missing).
while :; do
  for d in /sys/block/loop*/loop*p*; do
    [ -e "$d/dev" ] || continue
    n=${d##*/}
    IFS=: read -r maj min < "$d/dev"
    # replace a node that is missing or stale (points to another major:minor)
    cur=$(stat -c '%t:%T' "/dev/$n" 2>/dev/null || echo none)
    want=$(printf '%x:%x' "$maj" "$min")
    [ "$cur" = "$want" ] || { rm -f "/dev/$n"; mknod "/dev/$n" b "$maj" "$min" 2>/dev/null; }
  done
  sleep 0.3
done
