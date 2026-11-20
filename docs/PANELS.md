# Tianma and CSOT panels — why there are two images

The Xiaomi Pad 6 was built with **two different display panels**, from Tianma and from CSOT. They need different
display initialisation, which in the mainline kernel is selected by the **device tree** (DTB):

| Variant | Device tree | postmarketOS package |
|---|---|---|
| Tianma | `qcom/sm8250-xiaomi-pipa-tianma.dtb` | `device-xiaomi-pipa-kernel-tianma` |
| CSOT | `qcom/sm8250-xiaomi-pipa-csot.dtb` | `device-xiaomi-pipa-kernel-csot` |

The two kernel packages are identical except for `deviceinfo_dtb`; `pmbootstrap` copies the chosen DTB to the root of the
ESP and the boot entry (`/boot/loader/entries/pmos.conf`) says `devicetree sm8250-xiaomi-pipa-<panel>.dtb`.

## Why this project ships two separate images and does not auto-detect

* The panel is **not** reported to Linux in a way that systemd-boot could use to choose between two device trees. The
  string that identifies it (`msm_drm.dsi_display0=…m82_36_02_0a…` = Tianma, `…m82_42_02_0b…` = CSOT) is on the kernel command
  line of the *Android* kernel; it is not passed on through U-Boot and EFI to Linux.
* Putting both device trees in one image and "trying" one would at best give a black screen on the wrong panel, and it is
  **not verified** that driving a panel with the other panel's initialisation sequence is harmless.
* So: **never assume that a Tianma image works on a CSOT tablet**. Each image is named `…-tianma.sparse.img` or
  `…-csot.sparse.img`, `flash/flash.sh` needs `--panel` and refuses a file whose name does not match, and the release notes
  repeat this.

## How to find out which panel you have

While the tablet still runs its **original Android** (USB debugging on, `adb` authorised):

```sh
./flash/detect-panel.sh        # prints tianma, csot, or "unknown" (read-only)
```

It reads `/proc/cmdline` through adb. If it prints `unknown`, do not guess: open an issue and attach the output of
`adb shell cat /proc/cmdline` (this line contains no personal data, but check it before posting).

On an already running Linux: `cat /proc/device-tree/model` prints `Xiaomi Pad 6 (Tianma)` or `… (CSOT)`.

## Status

The reference tablet of this project has a **Tianma** panel. The CSOT image is built by exactly the same pipeline and
differs only in that one DTB, but **no CSOT tablet was available**, so the CSOT image has never been booted by the author.
