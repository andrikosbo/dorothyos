# Going back to Android

DorothyOS **replaces Android** on the tablet: it uses `userdata` for Linux, `boot_<slot>` for U-Boot and erases
`dtbo_<slot>`. It does **not** write `super` (the Android system), `vendor_boot*`, `vbmeta*`, `persist`, the modem partitions or
firmware, and it never changes the active slot. That is what makes a way back possible — **if you prepare it before you flash**.

> **Do this before flashing.** Nothing here has been tried on your tablet. The author's own rollback path was verified on one
> tablet with one ROM; it is described as an example, not as a guarantee.

## 1. Before flashing: what to back up

1. **Your data** (photos, documents): copy it off the tablet. Flashing erases `userdata`; there is no "undo".
2. **The boot images of the slot you will overwrite** (`boot_<slot>`, `dtbo_<slot>`), plus, if you can, `vendor_boot_<slot>`,
   `vbmeta_<slot>` — from a custom recovery (for example the OrangeFox build for pipa) with `dd`, or with a root shell:
   ```sh
   # example, current slot b, from a recovery shell with adb:
   adb shell dd if=/dev/block/by-name/boot_b   of=/sdcard/boot_b.img
   adb shell dd if=/dev/block/by-name/dtbo_b   of=/sdcard/dtbo_b.img
   adb pull /sdcard/boot_b.img . ; adb pull /sdcard/dtbo_b.img .
   ```
3. **`persist`, `modemst1`, `modemst2`, `fsg`, `devinfo`** (device-unique calibration, sensor registry, Wi-Fi/BT MAC data):
   copy them the same way and keep them **private**. They contain identifiers of your tablet; never publish them.
4. Write down `fastboot getvar all` output (private: it contains your serial number), notably `current-slot` and `anti`.

## 2. Path A — restore your saved boot images (fastest, keeps the Android you had)

Power off, hold **Power + Volume Down** for the bootloader fastboot screen.

```sh
fastboot getvar current-slot                 # stay on this slot, do NOT run "fastboot set_active"
fastboot flash boot_b  boot_b.img            # your backup of the slot flash.sh overwrote (b in this example)
fastboot flash dtbo_b  dtbo_b.img
fastboot reboot fastboot                     # userspace fastboot (fastbootd), needed to create a fresh data partition
fastboot erase userdata
fastboot erase metadata
fastboot reboot
```

Android starts again as a fresh install (your data is gone: restore it from your own backup). This works **only** if `super`
and the other partitions are still what they were — which is the case if you only used this project's `flash.sh`.

## 3. Path B — official Xiaomi fastboot ROM (if Path A fails or you have no backup)

Download the *fastboot* ROM for **pipa** matching your region from Xiaomi's official download page and flash it with Xiaomi's
`flash_all` script / Mi Flash Tool. It rewrites the Android partitions and wipes the data.

* **Anti-rollback:** do not flash a ROM older than the one the tablet had; compare `fastboot getvar anti` with the ROM's
  `anti_version.txt` first. A lower ROM can brick the tablet.
* Choose the script variant that does **not** re-lock the bootloader unless you want a locked bootloader.

## 4. Path C — GPT damage

If the tablet loops into fastboot ("qbootctl") because the partition table was damaged, the postmarketOS wiki page for the
Xiaomi Pad 6 describes restoring the GPT with `fastboot flash partition:N gpt_both{N}.bin` from the stock fastboot package.

## Observations from the reference tablet (not general rules)

* Android lived **only in slot b** there, slot a held only the installer environment of the custom ROM. After flashing,
  both slots stayed `successful=yes`. Because postmarketOS/U-Boot never sets the "boot successful" flag, running
  `fastboot set_active` would reset it and the bootloader could fall back to the other slot after a few boots. So: **never
  `set_active`**.
* The bootloader's Android-side checks (`vbmeta`) were not involved: the bootloader was already unlocked.
* Data rollback (`erase userdata`/`erase metadata`) was not exercised on the reference tablet because it would have destroyed
  the data being protected; the commands are the standard ones.
