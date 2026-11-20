# Architecture — what DorothyOS adds to a stock postmarketOS image

The measurements below come from the reference device (Xiaomi Pad 6, Tianma panel). The first part describes the hardware and
base system, the second what DorothyOS changes (`overlay/dorothyos-tablet/` and `overlay/dorothyos-branding/`), the third the
services and system configuration that matter for the touch experience. What is deliberately **not** in the image is listed
at the end.

Legend — **R** reusable UI/UX (ships in the `dorothyos-tablet` package), **D** device-specific (needed for this hardware),
**U** upstream postmarketOS/KDE default (comes from the base image).

## 1. The device and the base system

| Item | Value |
|---|---|
| Model / panel | Xiaomi Pad 6 (`xiaomi,pipa`, SoC `qcom,sm8250` = Snapdragon 870); the panel is a **Tianma** one (`/proc/device-tree/model`: "Xiaomi Pad 6 (Tianma)") |
| OS | postmarketOS `systemd-edge` (os-release prints "Nura edge", the new name of the postmarketOS mirror/branding), Alpine edge, musl, **systemd** |
| Kernel | `linux-xiaomi-pipa` 7.2.4-r0 (mainline-based, `git.mainlining.org/pipa-mainline/linux`), `7.2.4-pipa` |
| Desktop | KDE Plasma 6.8.3 on Wayland (KWin), login manager `plasmalogin`, Qt 6.11/6.12 |
| Boot chain | Xiaomi ABL → U-Boot in `boot_b` → EFI → systemd-boot on the ESP (FAT32) → kernel + initramfs → ext4 root; root and ESP live **inside an image written to `userdata`** (U-Boot maps it with `blkmap`) |
| Storage layout | 2 partitions in the image: ESP (512 MB, FAT32, `pmos_boot`) and root (ext4, `pmos_root`); 4096-byte sectors |
| Graphics | OpenGL ES 3.2 / Vulkan 1.3 through Mesa `freedreno` / `turnip` (Adreno 650) — hardware accelerated |
| Sensors | accelerometer + ambient light through the Qualcomm SLPI DSP: `hexagonrpcd-sdsp` → `libssc` → `iio-sensor-proxy` |
| Audio / Wi-Fi / BT / camera | ALSA UCM from `device-xiaomi-pipa`, WCN6855 Wi-Fi/BT (`linux-firmware-qca`), camera through PipeWire + libcamera (rear sensor only; the "Camera" launcher uses Cosmic Camera from Flathub, GNOME Snapshot is the fallback) |

## 2. What differs from a stock postmarketOS image

### 2.1 Reusable UI / UX (R) — shipped as the `dorothyos-tablet` apk

All of it is **user-level configuration plus QML widgets and small scripts**; no compiled code, nothing patched in
Plasma except the lock screen QML (below).

| Feature | Where (in this repo: `overlay/dorothyos-tablet/src/`) | Applied at |
|---|---|---|
| Home screen, iPad style: widget `org.pipa.homegrid` (pages, folders, edit mode, tile icons, dock/bar settings tab) | `homegrid/`, `hometiles/`, `phase12-home-screen-user.sh` | first login |
| Touch control center `org.pipa.controlcenter` (Wi-Fi, Bluetooth, brightness, volume, DND, rotation) + swipe-down-from-top KWin script `pipa-top-edge` | `controlcenter/`, `phase13-control-center-user.sh` | first login |
| Status bar (32 px, transparent) + small centred floating dock, nine-patch look generated as a Plasma desktop theme | `phase14-statusbar-user.sh`, `dock/pipa-dock`, `dock/pipa_dock_theme.py`, `phase15-dock-settings-user.sh` | first login |
| Status-bar guard: re-applies 32 px to the top panel after every plasmashell start (Plasma 6.8 resets it to 54 px) | `statusbar-guard/pipa-statusbar-guard`, `pipa-statusbar-guard.service` (wired in by a `.wants` link), `phase14-statusbar-user.sh` | every session |
| Touch helpers: Rotate screen, on-screen keyboard toggle, Overview, Close app (launchers + dock tool group) | `pipa-rotate*`, `pipa-keyboard*`, `pipa-overview.desktop`, `pipa-close.desktop`, `phase2b-…`, `phase10-…` | first login |
| Window rules/look: touch-sized window buttons, maximised normal windows, squash/scale open-close animation | `phase10-…`, `phase14-…` | first login |
| Wallpaper rotation every hour (desktop + lock screen) | `wallpaper/`, `phase11-wallpaper-user.sh` | first login (only if wallpapers are installed) |
| Touch-friendly lock screen (5 asserted edits of `LockScreenUi.qml` / `MainBlock.qml`) | `system/lockscreen-patch.py`, `system/pipa-lockscreen` | apk post-install **and** an apk trigger after every `plasma-desktop` upgrade (system level) |
| **DorothyOS Start**: touch start menu replacing Kickoff in the dock (pinned, recent, all apps by category / A-Z, search, session buttons) | `launcher/org.dorothyos.launcher/`, `phase19-start-menu-user.sh` | first login (plasmoid installed system-wide by the apk) |
| **DorothyOS Settings**: sidebar settings app (Wi-Fi, Bluetooth, display, sound, battery, appearance, dock, keyboard, apps, about …) with links to the KDE modules | `settings/org.dorothyos.settings/`, `settings/dorothyos-settings-helper`, `settings/dorothyos-settings` | system-wide (apk), launcher in the dock / home screen / control center |
| Accent colour #e85d00 | `phase18-branding-user.sh` | first login |
| Camera launcher (offers the Flathub camera app on first use) | `camera/` | system-wide (apk) |
| Display defaults 250 % / landscape for the login screen, first-boot wizard and new accounts | `system/kwinoutputconfig.json` → `/etc/xdg/kwinoutputconfig.json` | apk |
| Power button: one tap = lock + screen off after 5 s; tablet screen timings; no splash; three useless autostarts hidden | `phase16-first-boot-user.sh` | first login |
| On-screen keyboard as input method, display scale 250 % | `phase17-device-defaults-user.sh` | first login |

### 2.2 Device-specific (D)

| Item | Why | In this repo |
|---|---|---|
| `device-xiaomi-pipa`, `device-xiaomi-pipa-kernel-{tianma,csot}`, `linux-xiaomi-pipa`, `firmware-xiaomi-pipa-*` | the official postmarketOS packages for the device; the kernel variant package only selects the **device tree for the panel** (Tianma vs CSOT) | installed from the postmarketOS binary repository by `pmbootstrap` — nothing is forked |
| U-Boot in `boot_b` with a patched environment | the stock U-Boot did not pin the EFI boot entry to the right partition | not in the repo (binary); see `docs/BOOTLOADER.md` |
| `pipa-sensors-registry.service` | the SLPI sensor DSP needs a *sensor registry* that lives on the tablet's own `persist` partition; the service copies it **read-only** from `/mnt/vendor/persist` into `/mnt/vendor/persist/sensors/registry` on the root filesystem. It reads only the device's own data and never writes to `persist` | `system/pipa-sensors-registry.service`, `bin/pipa-sensors-registry` |
| `iio-sensor-proxy.service.d/10-pipa.conf` (restart on failure, start after the DSP server) and `system-sleep/50-pipa-sensors` (restart both after resume) | the proxy crashed once after resume and the DSP link goes stale | `system/10-pipa.conf`, `system/50-pipa-sensors` |
| `pipa-autorotate-kick` user service | KWin claims the accelerometer before the proxy has probed its SSC sensors; the claim is then counted but never starts the stream → no auto-rotate. The service flips KWin's auto-rotate policy off and on once the proxy reports `HasAccelerometer` | `pipa-autorotate-kick(.service)` |
| apk pins `linux-xiaomi-pipa=7.2.4-r0`, `device-xiaomi-pipa=11-r0` on the reference tablet | protect the hand-patched Tianma boot entry from kernel updates | **not** reproduced: the image is built from consistent packages of one date; see "Known limitations" |

## 3. Services and system configuration found on the tablet

* System units enabled beyond the pmOS defaults: `pipa`-prefixed: none (the sensor drop-in and the sleep hook above only). Everything else
  (`NetworkManager`, `bluetooth`, `ModemManager`, `hexagonrpcd-{adsp-rootpd,adsp-sensorspd,sdsp}`, `qbootctl`, `tqftpserv`, `tuned`, `apk-polkit-server`, `cups`, `avahi`, `sshd`, `plasmalogin`)
  comes from the postmarketOS packages. `sshd` is enabled on postmarketOS images by default; the DorothyOS image builds with `--no-sshd` (see `docs/SECURITY-MODEL.md`).
* User units: `pipa-autorotate-kick`, `pipa-wallpaper.timer` (+ pipewire, wireplumber …).
* `/etc/udev/rules.d/`: nothing added (iio-sensor-proxy already enables the accelerometer).
* `/etc/mkinitfs`, `/etc/modprobe.d`: stock.
* Power management: governor `schedutil`, zram swap 8 GB, `tuned-ppd`; suspend is **s2idle** only (the SoC has no deep sleep in the mainline kernel), so "sleep" = lock + display off.
* KWin: `kwinoutputconfig.json` output `DSI-1` 1800×2880, scale **2.5**, `Rotated270` (landscape), `autoRotation = InTabletMode`;
  `kwinrc`: `Xwayland/Scale=2.5`, `Wayland/InputMethod=org.kde.plasma.keyboard`, `TouchEdges/Bottom=ShowDesktop`, `Effect-overview/TouchBorderActivate=2`.

## 4. Deliberately not in the image

| Item | Why |
|---|---|
| user account, password, ssh keys | the first-boot wizard creates the account; there is no default |
| Wi-Fi profiles and passwords | entered by the user on the device |
| disk encryption | a passphrase baked into a public image would be shared by everybody; build your own with `--fde` |
| device-unique data (serial numbers, IMEI, MAC addresses, the `persist` / modem / calibration partitions) | never copied; the sensor registry is read from the device's own `persist` partition at the first boot |
| third-party apps, web-app launchers and their brand tiles; personal wallpaper photos | personal choice and/or somebody else's trademarks; DorothyOS ships its own CC0 wallpapers (`branding/wallpapers/`) |
