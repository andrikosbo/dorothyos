# Installing DorothyOS on a Xiaomi Pad 6

> **Status: release candidate.** The images were built and checked **offline** (see `VALIDATION.md`). The **Tianma** image has been flashed
> and booted on one tablet (2026-11-20, see `VALIDATION.md` §6); the **CSOT** image has not been on any hardware. Treat the first flash as a
> test: back up first, expect to need `ANDROID-ROLLBACK.md`. If the tablet stops at `grub>` see the table at the end of this page.

## You need

* A Xiaomi Pad 6 (`pipa`; **not** the Pad 6 Pro/Max or another model) with an **unlocked bootloader**. Unlocking is done through
  Xiaomi's official process (wait time, Mi account) and **wipes the tablet**. This project cannot and does not unlock it.
* A computer with `fastboot` (Android platform-tools), a USB-C cable, and a charged tablet (≥ 50 %).
* The **panel variant** of your tablet (`detect-panel.sh`, see `PANELS.md`): `tianma` or `csot`. The wrong one is not verified to
  be safe.
* The image for your panel, from the release page: `dorothyos-<version>-<panel>.sparse.img` (+ `.SHA256SUMS`;
  large releases are split/compressed, see the release notes).
* A U-Boot image for the tablet: **not included**, see `BOOTLOADER.md`.
* **A backup** (`ANDROID-ROLLBACK.md`). Flashing erases all data.

## Steps

1. Check the download: `sha256sum -c dorothyos-<version>-<panel>.SHA256SUMS` (on macOS: `shasum -a 256 -c …`).
2. While the tablet still runs Android: `./flash/detect-panel.sh` → `tianma` or `csot`.
3. Power the tablet off, hold **Power + Volume Down** until the fastboot screen appears, connect it.
4. ```sh
   ./flash/flash.sh --panel <tianma|csot> \
       --image dorothyos-<version>-<panel>.sparse.img \
       --uboot u-boot-xiaomi-pipa.img
   ```
   The script checks the device (product, unlocked, slot, battery, size), the image checksum and the panel name in the file name,
   shows what it will do and asks you to type `ERASE`. Then it runs `erase dtbo_<slot>`, `flash boot_<slot>`, `flash userdata`,
   `reboot`.

   **If the tablet has ever run another Linux system** (an earlier postmarketOS, Ubuntu Touch, a dual-boot experiment …) add
   `--pin-boot-entry`. An old bootloader left on an internal partition (GRUB) can be found before DorothyOS and stops the tablet at
   `grub>`; that is what happened on the reference tablet with the plain U-Boot. The option patches a *copy* of the U-Boot file you
   supply (a data-only edit of its default environment, `flash/tools/make-uboot-env-patch.py`) so that it boots the DorothyOS image
   directly, and flashes that copy. Your original file is not changed, and nothing is written to the tablet if the tool does not
   recognise your U-Boot build. A tablet that only ever ran the stock Xiaomi software should not need it (this is expected, not tested).
   ```sh
   ./flash/flash.sh --panel <tianma|csot> --image dorothyos-<version>-<panel>.sparse.img \
       --uboot u-boot-xiaomi-pipa.img --pin-boot-entry
   ```
5. First boot: after the logo, KDE's **Plasma Setup** wizard asks for language, keyboard, time zone, Wi-Fi and creates **your
   account**. There is no default account or password — not even one you may remember from the stock postmarketOS image: you choose both here. This takes a while the first time (the root partition grows to the whole
   `userdata` area on the first boot).
6. After you log in the tablet-first setup runs once (about a minute, the screen flickers a few times): home screen, dock, control
   center, gestures, the DorothyOS start menu (the logo at the left of the dock) and the Settings app. Swipe up from the bottom edge for
   the home screen, down from the top edge for the control center.

## If something goes wrong

| Symptom | What to try |
|---|---|
| Black screen after the U-Boot logo | wrong panel image? Re-flash the other variant is **not** a first step: confirm the panel with `detect-panel.sh` or from the Android command line first. Hold Power 15 s to power off, Power + Volume Down for fastboot |
| `grub>` or another bootloader prompt | an old bootloader on an internal partition came first (this happened on the reference tablet with the unpatched U-Boot, 2026-11-20): flash again with `--pin-boot-entry` (step 4, see `BOOTLOADER.md`); to keep the installed system instead, build the patched U-Boot with `python3 flash/tools/make-uboot-env-patch.py <your U-Boot> <out>` and write only `boot_<slot>` with `fastboot flash boot_<slot> <out>` |
| Setup wizard does not appear / no login screen | switch to a text console is not available without a keyboard; connect a USB keyboard, Ctrl+Alt+F2, log in is impossible without an account → re-flash. Please report (include the steps, not personal data) |
| Want Android back | `ANDROID-ROLLBACK.md` |

## Updating

The image is a normal postmarketOS system: `sudo apk update && sudo apk upgrade` (or Discover) updates it. **Kernel and device
package updates have not been tested on this image**; on the author's tablet they are held back on purpose (a package update can
regenerate the boot entry, and with the panel variant packages that matters). If you want the same safety:
`sudo apk add linux-xiaomi-pipa=<installed version> device-xiaomi-pipa=<installed version> device-xiaomi-pipa-kernel-<panel>=<installed version>`
(the versions are in `apk info -v`), and upgrade them deliberately.
After a `plasma-desktop` upgrade an apk trigger re-applies the touch lock screen patch automatically.
