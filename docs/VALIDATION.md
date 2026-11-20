# Validation

**Status of release candidate `0.1.0-rc1`: built and validated OFFLINE; the Tianma image was flashed and booted on ONE tablet (§6); CSOT is not verified on hardware.**
The offline checks cannot say "it boots"; only a tablet can. §6 lists what was seen on hardware and by whom, §5 what is still not verified.

## 1. What was validated offline

`tests/validate.sh` unpacks each finished fastboot image (Android sparse → raw disk image), attaches it to a loop device in a throw-away privileged
container, mounts the ESP and the root file system **read-only** and runs `tests/validate-image.sh`. Result of the run on the release-candidate images
(logs: `tests/logs/validate-<panel>.log`, not committed because they contain build paths):

| Image | Result |
|---|---|
| `dorothyos-0.1.0-tianma.sparse.img` | **VALIDATION PASSED** — 71 checks ok, 0 warnings, 0 failed (offline) |
| `dorothyos-0.1.0-csot.sparse.img` | **VALIDATION PASSED** — 71 checks ok, 0 warnings, 0 failed (offline) |

What the checks cover (each is an `ok` / `FAIL` / `WARN` line in the log):

| Area | Checks |
|---|---|
| Container | SHA-256 of image and manifests; valid sparse format; 2 partitions; `pmOS_boot` (vfat) and `pmOS_root` (ext4); `e2fsck -fn` and `fsck.vfat -n` clean |
| No personal state | no regular account, root locked, no password hash, `/home` empty, no ssh host keys, no `machine-id`, no `authorized_keys` / private keys / shell histories, no saved Wi-Fi profile, no Bluetooth pairing, no AccountsService data; **no identifier of the maintainer or the reference tablet** in `/etc`, `/root`, `/var/lib`, the tablet package, the plasmoids, the boot loader |
| Services | Plasma Setup (first-boot wizard) enabled and not marked done; `systemd-firstboot` masked; sshd **not** enabled; sensor-registry service and auto-rotate kick enabled; login-manager unit present |
| Panel | boot entry names `sm8250-xiaomi-pipa-<panel>.dtb` and that file exists on the ESP; kernel, initramfs and `BOOTAA64.EFI` present; only the kernel-variant package of this panel installed; `/etc/dorothyos-release` says the same panel |
| Branding | `os-release` is DorothyOS (real file, `ID_LIKE=alpine` kept); *About this System* file; hostname; boot-menu title; Plymouth theme installed, selected **and present inside the initramfs**; 8 wallpaper packages; app icon in all sizes; licence files |
| Touch UI | all commands and phase scripts present, executable, shell/Python syntax OK; the four plasmoids have valid `metadata.json` and a `main.qml`; `kwinoutputconfig.json` valid (DSI-1, scale 2.5, landscape); touch lock-screen patch applied; the accent script is the fixed one (§4); `flatpak` + `kdialog` installed |
| Packages | `plasma-desktop`, `plasma-setup`, `plymouth`, kernel, device package, both DorothyOS packages, Firefox; list of `proprietary`-licensed firmware packages; no world-writable files in `/etc`, `/usr/bin`, the tablet package |

The build itself also asserts (in `build/postprocess.sh`, the build fails otherwise) that the build account is gone, root is locked, Plasma Setup is enabled,
the DorothyOS branding is in place and the initramfs carries the splash theme.

## 2. Repository audit

`sh tests/audit.sh` — secrets and private keys, maintainer paths / names / network identifiers, MAC addresses, licence files, leftover placeholders,
stray references to the old project name, files > 2 MB, scripts without shebang. It must say `AUDIT PASSED` before a release; `release/make-release.sh` refuses otherwise.
It audits the **tree** (what goes to git). The **images** are covered by §1.

## 3. Verified on the reference tablet (Tianma), not on an image

The tablet-first user interface runs on the author's own Xiaomi Pad 6 and has been used there: home screen, folders, dock, status bar, control center, hourly wallpapers,
power-button behaviour, touch lock screen, auto-rotate, camera (Cosmic Camera). The **start menu** and the **Settings app** were rendered offscreen
(`QT_QPA_PLATFORM=offscreen`, software renderer, test harness in `docs/BUILD.md`) and are installed on that tablet; **nobody has used them by touch yet**
(the screen was locked while they were installed). The accent-colour phase was applied on the tablet and verified by the stored
colour values; the lock screen prevented a visual check.

## 4. Bugs that validation and live testing found (all fixed in this release)

* **Accent colour turned the dark tablet light** (twice). `plasma-apply-colorscheme --accent-color X <Scheme>` ignores the scheme name and recolours the scheme it believes is current;
  with no `ColorScheme` key in `kdeglobals` (fresh profiles, the reference tablet) that is *BreezeLight*. `phase18-branding-user.sh` now pins the scheme first, applies the accent,
  verifies the stored scheme name and rolls back by itself if it is wrong. The validator checks that the image carries the fixed script.
* A dangling `post-upgrade` symlink broke the first image build (the apk scriptlet was missing) — now a real file.
* **First real boot (2026-11-20, Tianma) found five more bugs, all fixed and checked again on the tablet:**
  1. *The setup wizard had no on-screen keyboard*, so an account could not be created on a tablet without a physical keyboard. The wizard runs as the throw-away user `plasma-setup`
     (home in `/run`), and the keyboard was only enabled per normal user at first login. The image now ships `/etc/xdg/kwinrc` (input method + virtual keyboard) and the validator checks it.
  2. *The dock buttons Overview and Close said "does not exist".* `phase10` copied their launchers from a `tabletux/` folder that the package does not install (they are installed flat);
     the copy failed silently. `phase10` now uses the installed folder and aborts loudly if a launcher is missing; the validator checks the files.
  3. *The dock was not the small centred one.* Every first-login phase stops and starts plasmashell; from the fourth start within 60 s systemd refused (`StartLimitBurst=3`), `phase14` (`set -e`) aborted
     before its "panel looks" step and, because of its "top panel already exists" guard, could never finish on a re-run. All phases now `reset-failed` before every start and `phase14` re-applies its looks on a re-run; the validator checks it.
  4. *The Keyboard and Rotate launchers pointed at `/home/user/…`*, which only exists for an account called `user`. `phase2b` now rewrites the path to the real home.
  5. *Firefox got a tile image that is not shipped* (brand tiles were removed from the repository). Apps without a tile now keep their own icon; and a second run of `phase18` aborted and threw the accent colour away
     because `plasma-apply-colorscheme` writes nothing when the scheme is already current — it now compares against the same fallback it uses to read the scheme.
* The validator itself had false positives (BusyBox `losetup` without `--sector-size`, `blkid` output, `*.pem` files, default-key-name strings inside OpenSSH files, a shell syntax check applied to a Python helper);
  they were fixed in the script, not by loosening the intent of the checks.

## 5. Not verified (do not assume)

* that the **CSOT** image boots, or anything else about the CSOT panel;
* the Tianma image on more than the one tablet, and more than one run; no photos or logs from the first runs are kept;
* the **shutdown/reboot splash**, and whether the boot splash looks right (size, orientation); the maintainer only reports that a splash appeared before the wizard;
* the look of Plasma Setup (scale, rotation) and the accent colour on a fresh profile (not examined in detail);
* touch behaviour of *DorothyOS Start* and *DorothyOS Settings* (long press, drag, scroll, on-screen keyboard in the search field);
* the camera launcher's first-use download dialog, Wi-Fi/Bluetooth/audio/brightness/suspend on the new image;
* package upgrades (`apk upgrade`) after installation, kernel/device-tree updates for either panel.

## 6. Hardware reports

When somebody flashes a release image, the result goes here (open the *First boot report* issue template, the maintainer adds a row).

| Date | Image | Panel | Result | Notes |
|---|---|---|---|---|
| 2026-11-20 | Tianma, first build (before the fixes in §4) | Tianma | boots; with the unpatched U-Boot it stopped at `grub>` (old GRUB on this tablet); with the patched U-Boot it showed the splash and the Plasma Setup wizard, but **no on-screen keyboard** | maintainer's own tablet, reported by the maintainer; the setup log was read over ssh (the dock bugs of §4 came from it) |
| 2026-11-20 | Tianma, second build (all fixes of §4), flashed with the patched U-Boot | Tianma | wizard **with on-screen keyboard**; account created by touch only; first-login setup finished; home screen, small centred dock, Close / Overview / Keyboard buttons work | same tablet, reported by the maintainer; no photos, no log of this run. The patched U-Boot was written beforehand with the tool (before `flash.sh --pin-boot-entry` existed) |
| 2026-11-20 | Tianma, same second build, flashed again, this time with `flash.sh --pin-boot-entry` and the **unmodified public U-Boot** | Tianma | goes to the Plasma Setup wizard, **no `grub>`** | same tablet, reported by the maintainer ("Wizard, no grub>"); no photo, no log. The script patched a temporary copy of the public U-Boot (SHA-256 `0d1491eb…19ce` → `bcc625ed…d7c3`, the same file as before) and flashed it together with the image; the setup after the wizard was not repeated on this run, the image is the same as in the row above. One tablet only: other leftover bootloaders and the CSOT panel are untested |
| — | CSOT | CSOT | no report yet | — |

The images that were flashed on 2026-11-20 (Tianma, SHA-256 `9ef177ab…3e38`) predate one packaging change: the images in the release additionally carry the
firmware licence texts and `FIRMWARE.md` (`/usr/share/licenses/dorothyos-branding/firmware/`, `docs/FIRMWARE.md`) and the extended `CREDITS.md`. Nothing else
was changed; the release images were rebuilt and passed the offline checks above (71), but that exact build has **not** been flashed.

## 7. Reproduce

```bash
./build/build.sh both       # ≈ 10 min with a warm cache (the first build downloads ≈ 2 GB)
./tests/validate.sh         # both images, ≈ 7 min
sh tests/audit.sh
```
