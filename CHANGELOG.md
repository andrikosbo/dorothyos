# Changelog

## 0.1.0-rc1 — not released yet (local release candidate)

First complete set of sources and images; **built and validated offline**, and the Tianma image **booted and used on one tablet** (see `docs/VALIDATION.md` §6). CSOT is not verified on hardware.

* Firmware notices: `docs/FIRMWARE.md` (what the proprietary firmware is, its terms, the open point about the device-specific files, how to object) and the upstream licence texts (`docs/firmware-licenses/`) are installed in the image and attached to the release as `FIRMWARE-NOTICES.txt`; `THIRD_PARTY.md` corrected (kernel source) and `CREDITS.md` extended.
* `flash.sh --pin-boot-entry`: patches a copy of the supplied U-Boot (data-only environment edit) so that a tablet with an old GRUB on an internal partition boots DorothyOS instead of stopping at `grub>`. Tried on the one tablet that had stopped at `grub>`: it went to the setup wizard (reported by the maintainer).
* Fixed after the first boot on hardware: no on-screen keyboard in the setup wizard (`/etc/xdg/kwinrc`); dock tool launchers (Overview, Close) not installed; plasmashell start-limit hit during the first-login setup
  (half-configured dock); Keyboard/Rotate launchers hard-coded to `/home/user`; missing Firefox tile image; accent-colour phase aborting on a re-run. `docs/VALIDATION.md` §4.

* Two flashable images (`tianma`, `csot`) built reproducibly with `pmbootstrap` in a container (`build/`), post-processed so that no account,
  password, ssh key or host identifier ships (`build/postprocess.sh`), plus package/boot manifests and checksums.
* `dorothyos-tablet` apk: iPad-style home screen, control center, dock + status bar, touch lock screen, auto-rotate helpers, camera launcher,
  250 % / landscape display defaults for every account, first-login setup (`phase10`–`phase19`).
* Status-bar guard (`pipa-statusbar-guard` + user unit, enabled for every account): Plasma 6.8 resets the top panel to 54 px on every plasmashell start; the guard puts 32 px back a few seconds later.
* Project website `https://dorothy.gr/dorothyos` (apk metadata, `os-release`, About pages); the landing page is in `website/` (not deployed by this repository).
* New in this release: **DorothyOS Start** (touch start menu replacing Kickoff) and **DorothyOS Settings** (sidebar settings app).
* `dorothyos-branding` apk: name, `os-release`, *About this System*, ring boot splash (Plymouth), icons, accent colour, eight CC0 wallpapers.
* Tooling: `flash/` (guarded fastboot flashing, panel detection), `tests/audit.sh`, `tests/validate.sh`, `release/` (assets + guarded publish script).
* Documentation: install, build, panels, bootloader, security, limitations, branding, decisions, publishing, third-party notices.

### Upcoming changes
* **UI changes and improvements** — keep refining the interface: fewer scripted workarounds and more first-class Plasma components, touch behaviour (gestures, start menu, Settings, lock screen) that feels like part of the system, and smarter use of the sensors that already work (automatic brightness, orientation handling on top of auto-rotate).
* **Sound quality issues and calibration** — look into the known sound-quality problems and calibrate the audio output (levels, tuning) for this tablet.
* **Camera quality** — a proper libcamera tuning profile for the rear OV13B10 sensor (colour, white balance, noise), then autofocus and the front camera once the kernel can describe them.
