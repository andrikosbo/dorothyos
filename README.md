# DorothyOS

**A tablet-first Linux for the Xiaomi Pad 6 (`pipa`) — open, reproducible and flashable.**

DorothyOS turns the Xiaomi Pad 6 into a tablet that behaves like a tablet: an iPad-style home screen with pages and folders, a
floating dock, a touch control center (swipe down from the top), a touch start menu and a touch Settings app, a touch-friendly lock
screen, auto-rotate, an on-screen keyboard, hourly wallpaper rotation and a camera app — on a normal, upgradeable Linux
(KDE Plasma 6 on Wayland, hardware-accelerated graphics). Everything here is a script, a QML widget or a package recipe;
the images are built from them with one command.

*Created and maintained by [Andreas Boglou](https://boglou.com).*

> ### Status: release candidate 1 — verified on **one Tianma tablet**, CSOT not verified
> The images (one per display panel) were **built and checked offline** (`docs/VALIDATION.md`). The **Tianma** image was then flashed to one
> tablet (2026-11-20): it boots into the Plasma Setup wizard with a working on-screen keyboard, an account was created, the first-login setup
> finished and the dock and home screen worked (details and limits in `docs/VALIDATION.md`, §6). That is a single tablet and a single run:
> the **CSOT** image has no hardware test at all. A tablet that still carries an old bootloader (GRUB) from an earlier install needs
> `flash.sh --pin-boot-entry` (`docs/BOOTLOADER.md`; on the one tablet that stopped at `grub>` it fixed that). Treat the first flash as a test, **back up first**, and read `docs/LIMITATIONS.md`.
> Flashing erases the tablet. You do it at your own risk.

## What you get

| | |
|---|---|
| **Home screen** | pages, folders, edit mode (long-press), widgets-free iPad layout, tile icons, the wallpaper is never darkened |
| **Dock + status bar** | small centred floating dock with the DorothyOS start button, transparent 32 px status bar |
| **Start menu** | *DorothyOS Start*: pinned and recent apps, all apps by category or A–Z, search, session buttons — everything Kickoff does, sized for fingers |
| **Control center** | Wi-Fi, Bluetooth, brightness, volume, Do-Not-Disturb, rotation lock — swipe down from the top edge |
| **Settings** | *DorothyOS Settings*: a sidebar app (Wi-Fi, Bluetooth, display, sound, battery, appearance, dock, keyboard, apps, about …) that links to the full KDE modules for anything deeper |
| **Look** | DorothyOS wordmark and ring logo, orange accent `#e85d00`, ring boot splash, eight original CC0 wallpapers |
| **Display** | 250 % scale, landscape and auto-rotate by default, also at the login screen and in the first-boot wizard |
| **Camera** | rear camera through libcamera; the *Camera* tile offers the best available app (Cosmic Camera from Flathub) on first use |
| **First boot** | KDE *Plasma Setup* wizard creates **your** account — no default user, no default password, sshd off, root locked |
| **Updates** | a normal package-managed system: `apk upgrade` or Discover |

Hardware status and what is *not* working (front camera, autofocus, fast-charge chip, …) is in `docs/LIMITATIONS.md`.

## Get an image

Two images are built from the same sources — the only difference is the device tree that drives the display panel:

| Your tablet | Image |
|---|---|
| **Tianma** panel | `dorothyos-<version>-tianma.sparse.img` |
| **CSOT** panel | `dorothyos-<version>-csot.sparse.img` |

Do **not** guess the panel: `flash/detect-panel.sh` finds out while the tablet still runs Android (`docs/PANELS.md`).
Downloads are on the GitHub *Releases* page (compressed with zstd and split into parts below GitHub's 2 GiB
limit; `REASSEMBLE.txt` in the release explains it). Or build them yourself, see below.

## Install

Short version — everything is in **`docs/INSTALL.md`**:

1. unlock the bootloader (Xiaomi's official process; wipes the tablet), back up (`docs/ANDROID-ROLLBACK.md`);
2. get a U-Boot image from the community project — **not included here**, `docs/BOOTLOADER.md` says where;
3. `./flash/flash.sh --panel <tianma|csot> --image dorothyos-<version>-<panel>.sparse.img --uboot u-boot-xiaomi-pipa.img`
   (it checks the device, the checksum and the panel, shows the plan and asks you to type `ERASE`);
4. at the first boot, KDE Plasma Setup creates your account; after the first login the tablet-first setup runs once.

Back to Android: `docs/ANDROID-ROLLBACK.md`.

## Build it yourself

Needs Docker able to run privileged **arm64** containers (Apple Silicon Mac or an ARM64 Linux; x86 only through slow emulation,
untested), ~25 GB of free disk and a fast connection for the first build. Details in `docs/BUILD.md`.

```bash
./build/build.sh both            # → dist/dorothyos-<version>-{tianma,csot}.sparse.img + packages / boot-entry manifests + SHA256SUMS
./tests/validate.sh              # offline checks of those images (accounts, branding, services, panel, filesystems)
sh tests/audit.sh                # the repository tree itself: secrets, personal data, licences
```

How it works: `build/build.sh` starts a privileged Alpine container, builds the two apks in `overlay/` (`dorothyos-tablet` = the touch UI,
`dorothyos-branding` = name, logo, splash, wallpapers) with `pmbootstrap`, installs `device-xiaomi-pipa` + the Plasma desktop + those two apks into an
image, and `build/postprocess.sh` makes the image safe to publish (removes the build account, locks root, asserts the branding, writes the
manifests, converts to a fastboot sparse image). The repository is mounted read-only; nothing else on your computer is changed.

## Repository map

| Path | What it is |
|---|---|
| `overlay/dorothyos-tablet/` | the touch UI as an apk: home grid, control center, dock, start menu, Settings, camera launcher, lock screen patch, first-login scripts (`src/phase*.sh`) |
| `overlay/dorothyos-branding/` | name, `os-release`, "About this System", Plymouth splash, icons, wallpapers, licences — **change this package to re-brand** |
| `branding/` | sources of the artwork (logo master, splash and wallpaper generators) |
| `build/` | container build + post-processing |
| `flash/` | `flash.sh` (guarded fastboot flashing), `detect-panel.sh`, U-Boot environment patch tool |
| `tests/` | `audit.sh` (tree audit), `validate.sh` / `validate-image.sh` (image validation), `unsparse.py` |
| `release/` | `make-release.sh` (compress + split the images into release assets), release-notes template |
| `docs/` | install, build, panels, bootloader, Android rollback, security model, branding, architecture, limitations, validation |

## Security in one paragraph

The image contains **no account, no password, no ssh key, no Wi-Fi profile and no device identifier**; root is locked; sshd is disabled; the machine-id
is created at the first boot. The root filesystem is **not encrypted** (a shared passphrase would be a shared secret) — encrypt your own build if you
need to. `docs/SECURITY-MODEL.md` has the full table; how to report a vulnerability is in `SECURITY.md`.

## Next steps

* **Better camera quality** — a proper libcamera tuning profile for the rear OV13B10 sensor (colour, white balance, noise), then autofocus and the front camera once the kernel can describe them.
* **Making better use of the device's sensors** — the ambient-light sensor and the accelerometer are already available; next come automatic brightness and smarter orientation handling on top of the working auto-rotate.
* **A more native experience** — fewer scripted workarounds, more of the interface as first-class Plasma components, and touch behaviour (gestures, start menu, Settings, lock screen) that feels like a part of the system rather than an add-on.

The current gaps are listed in `docs/LIMITATIONS.md`.

## Credits and licences

DorothyOS is created and maintained by [Andreas Boglou](https://boglou.com). It stands on the work of many open-source communities — postmarketOS and Alpine Linux, the pipa mainline-Linux community, KDE, Qt, Mesa and hundreds
of others. Thank you: **`CREDITS.md`**. Licences: code **MIT** (`LICENSE`), wallpapers **CC0 1.0**, logo / wordmark / icon / boot splash **CC BY 4.0**
(see `THIRD_PARTY.md`), and the software inside the images under its own licences, with the exact package list published next to every image
(`THIRD_PARTY.md`; the images also contain proprietary firmware the hardware needs, see `docs/FIRMWARE.md`). DorothyOS is an independent project, not affiliated with or endorsed by
the projects or companies it names.

## Contributing

Bug reports from real hardware are the most valuable thing right now — especially **the first boot of a release image** and **CSOT** tablets.
`CONTRIBUTING.md` says how to report, how to test a change without touching a tablet, and what must never be posted (serial numbers, IMEI,
MAC addresses, Wi-Fi names, passwords, backups of `persist`).
