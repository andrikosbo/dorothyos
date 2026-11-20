# DorothyOS @VERSION@ — release candidate

> **Verified on one Tianma tablet; CSOT not verified.** These images were built and checked offline (see `docs/VALIDATION.md`). The Tianma image was
> flashed to one tablet (2026-11-20): wizard with on-screen keyboard, account, first-login setup, home screen and dock worked. Treat the first flash as a test,
> **back up first**, and report what happens (the *First boot report* issue template). A tablet that ever ran another Linux system (old GRUB) needs `flash.sh --pin-boot-entry` (`docs/BOOTLOADER.md`).
> Flashing erases the tablet.

A tablet-first Linux for the **Xiaomi Pad 6 (`pipa`)**: iPad-style home screen, dock, touch control center,
start menu and Settings app, touch lock screen, auto-rotate, camera, 250 % display scale, DorothyOS look (ring logo, orange accent, boot splash).

## Pick the right file — one image per display panel

| Your tablet | Files |
|---|---|
| **Tianma** panel | `dorothyos-@VERSION@-tianma.*` |
| **CSOT** panel | `dorothyos-@VERSION@-csot.*` (**never booted by anyone yet**) |

Find your panel with `flash/detect-panel.sh` while the tablet still runs Android (`docs/PANELS.md`). **Do not guess.**

## Get the image back from the release files
See `REASSEMBLE.txt` (cat the parts, `zstd -d --long=27`, check `dorothyos-@VERSION@-<panel>.SHA256SUMS`). `DOWNLOAD.SHA256SUMS` covers the downloaded files.

## Install
`docs/INSTALL.md`; in short: unlock the bootloader, get a U-Boot image (**not included**, `docs/BOOTLOADER.md`),
`./flash/flash.sh --panel <tianma|csot> --image dorothyos-@VERSION@-<panel>.sparse.img --uboot u-boot-xiaomi-pipa.img`. At the first boot KDE
Plasma Setup creates your account — there is no default user or password; sshd is off; root is locked; the disk is not encrypted.

## What the offline validation covered
@VALIDATION@

## Known limitations (full list: `docs/LIMITATIONS.md`)
* one tablet, one run (Tianma); CSOT never on hardware; the shutdown splash, upgrades, suspend and the Start/Settings apps by touch are unchecked;
* no front camera, no autofocus, muted camera colours; one app at a time may use the camera (first use offers to download *Cosmic Camera* from Flathub);
* kernel-side quirks of the mainline port (charge-pump probe error, occasional vblank timeouts);
* the images contain proprietary firmware blobs required by the hardware (`*.packages.txt` marks them `proprietary`); see the section *Firmware* below.

## Next steps
* **Better camera quality** — a proper libcamera tuning profile for the rear OV13B10 sensor (colour, white balance, noise), then autofocus and the front camera once the kernel can describe them.
* **Making better use of the device's sensors** — the ambient-light sensor and the accelerometer are already available; next come automatic brightness and smarter orientation handling on top of the working auto-rotate.
* **A more native experience** — fewer scripted workarounds, more of the interface as first-class Plasma components, and touch behaviour (gestures, start menu, Settings, lock screen) that feels like a part of the system rather than an add-on.

## Firmware
The tablet needs closed-source firmware (touch, GPU, audio and sensor DSPs, video, Wi-Fi, Bluetooth), so the images contain it; the git repository does not. The linux-firmware
files come with their redistribution licences, which are reproduced in `FIRMWARE-NOTICES.txt` (attached to this release) and in `docs/firmware-licenses/`; the files are unmodified
and are used only for this Qualcomm-based hardware. The device-specific files (`firmware-xiaomi-pipa-*`) carry **no licence statement** at their source: they are redistributed
the way postmarketOS distributes them, without a permission from the rights holders. If you hold rights and object, open an issue and they will be removed. Details: `docs/FIRMWARE.md`.
Thanks to the linux-firmware project, Alpine Linux, postmarketOS and the pipa mainline community.

## Credits and licences
Thank you to the open-source communities DorothyOS is built on: see `CREDITS.md`. `dorothyos-@VERSION@-<panel>.packages.txt` lists every package with its version and
licence; `THIRD_PARTY.md` explains the licences. Code: MIT; wallpapers: CC0-1.0; logo/wordmark/icon/splash: CC BY 4.0. DorothyOS is an independent project.
