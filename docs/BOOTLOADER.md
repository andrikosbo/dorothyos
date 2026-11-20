# Boot chain and U-Boot

```
Xiaomi ABL (stock bootloader, unlocked)
  └─ boot_<slot>  : U-Boot (Android boot image format)         <- flashed by flash.sh
       └─ blkmap over the `userdata` partition (U-Boot maps the image that lives there as a block device)
            └─ ESP (FAT32, partition 1 of that image)   /EFI/BOOT/BOOTAA64.EFI = systemd-boot
                 └─ loader/entries/pmos.conf: vmlinuz + initramfs + devicetree sm8250-xiaomi-pipa-<panel>.dtb
                      └─ initramfs mounts ext4 root (partition 2 of the image), systemd, KDE Plasma
```

`flash.sh` writes exactly three things: `erase dtbo_<slot>`, `flash boot_<slot>` (U-Boot), `flash userdata` (this image).
It never touches `persist`, the modem partitions, `vbmeta*`, `vendor_boot*`, `super`, firmware or the other slot, and it never
runs `fastboot set_active`.

## Where to get the U-Boot image — this repository does NOT ship it

The U-Boot for the Xiaomi Pad 6 is built by the community project <https://github.com/pipa-project/u-boot>
(`xiaomi-pipa.cfg`, GPL-2.0-or-later; CI in <https://github.com/pipa-project/postmarketos-builds>). Their CI artifacts, and the archive
of the postmarketOS image published for this device, contain `u-boot-xiaomi-pipa.img`.

* This project does not redistribute that binary: its exact source commit is not recorded in the file, and the GPL requires
  the corresponding source to be offered with it. Obtain it from upstream (or build it from the source above) and pass it to
  `flash.sh --uboot`.
* The reference tablet runs a build whose SHA-256 is
  `0d1491eb3f4b64243ed6a5d7ec875072bcdacd95d785c1487db01e55925419ce` (U-Boot 2027.01, 201326592 bytes). The flash script
  checks that the file fits `boot_<slot>` and has the Android boot image magic; it does not insist on this hash so that newer
  upstream builds can be used, but **if you use another build you are on your own** — test it before you rely on it.

## Optional: pinning the EFI boot entry (`flash.sh --pin-boot-entry`, `flash/tools/make-uboot-env-patch.py`)

U-Boot's `bootefi bootmgr` tries `\EFI\BOOT\BOOTAA64.EFI` on every block device it knows, physical ones first, the image in
`userdata` last. On the reference tablet an old GRUB left over from earlier experiments came first and the tablet stopped at
`grub>` (seen again on 2026-11-20 with the unpatched build; with the patched build the same tablet went straight into the setup wizard). The tool makes a **data-only edit of the default environment** inside the U-Boot image (no code is changed): it adds
an `efidebug boot add -b 70 pmOS blkmap 0:1 /EFI/BOOT/BOOTAA64.EFI` entry, makes it the only boot order entry and calls it from
`bootcmd`.

You only need this if your tablet does not boot into the image, or stops in another bootloader. A tablet that has only ever run
stock Xiaomi software should not need it (an expectation, not a tested fact). The simplest way is the flash script, which patches a
temporary copy of the file you give it and flashes that copy together with the image:

```sh
./flash/flash.sh --panel <tianma|csot> --image dorothyos-<version>-<panel>.sparse.img --uboot u-boot-xiaomi-pipa.img --pin-boot-entry
```

The original file is never modified, and if the tool does not recognise the U-Boot build nothing is written to the tablet. On the
reference build above (SHA-256 `0d1491eb…19ce`) the patched copy has the SHA-256
`bcc625ed2ba29898846a66d55363e38eb89a47de703acf0b15532bdd502fd3c7`; that file booted the reference tablet straight into the setup wizard
(2026-11-20), and so did `flash.sh --pin-boot-entry` run on that tablet with the unmodified public U-Boot the same day (reported by the maintainer; one tablet, one run). To keep an installed system and replace only the bootloader, patch by hand and write `boot_<slot>` alone:

```sh
python3 flash/tools/make-uboot-env-patch.py u-boot-xiaomi-pipa.img u-boot-xiaomi-pipa-bootpm.img
fastboot flash boot_<slot> u-boot-xiaomi-pipa-bootpm.img
```

The tool asserts the layout of the file it patches (Android boot image v0, gzip'd U-Boot + DTB, the env blob at the expected
place, the new env fits the old byte budget) and stops if anything differs. It was written for the build above and is **not**
tested against other U-Boot builds.
