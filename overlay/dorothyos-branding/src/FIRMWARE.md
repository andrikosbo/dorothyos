# Firmware, proprietary components and source availability

The Xiaomi Pad 6 does not work without closed-source firmware: touch controller, GPU, audio and sensor DSPs, video codec, Wi-Fi and
Bluetooth all load binary blobs at boot. The DorothyOS **images contain them; this repository does not** (no firmware file is in the git
tree). This page says what they are, where they come from, under which terms they are redistributed, and what DorothyOS does about it.
It is a description, not legal advice. (Overview of everything else: `THIRD_PARTY.md`.)

## 1. What is in the images

Every package of an image is listed with its version and licence in `dorothyos-<version>-<panel>.packages.txt`. The ones that carry
firmware are:

### A. `linux-firmware-{qcom,qca,ath10k,ath11k}` — version 20261019

The upstream **linux-firmware** collection (<https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git>), packaged by
Alpine Linux. The four packages are whole families (several hundred files); the tablet uses only a few of them (for example the WCN6855
Wi-Fi/Bluetooth files and Adreno GPU microcode), the rest is there because the packages are installed as a unit. The upstream file
`WHENCE` records the origin and licence of every file; each of the 715 files in these four packages has a *redistributable* licence entry there (checked on 2026-11-20 against the tag `20261019`), under these texts,
which are reproduced unmodified in [`docs/firmware-licenses/`](firmware-licenses/) and in the release file `FIRMWARE-NOTICES.txt`:

| Licence file | Applies to (in these packages) | Main conditions |
|---|---|---|
| `LICENSE.qcom` (+ `NOTICE.qcom`, `LICENSE.qcom-2`) | Qualcomm firmware: remote processors, GPU, video, Wi-Fi/Bluetooth | binary form only; only on platforms with Qualcomm chipsets; **the licence text must accompany the binaries**; the supplier's names, logos and trademarks may not be used; no reverse engineering; no sublicensing under other (for example open-source) terms |
| `LICENSE.QualcommAtheros_ath10k` | Qualcomm Atheros Wi-Fi and Bluetooth (`ath10k`, `ath11k`, `qca`) | binary form only, without modification, only with the vendor's chipsets; notice and disclaimer must be reproduced; no endorsement |
| `LICENSE.dell` | a few files supplied by Dell | similar redistribution licence, text included |
| `LICENCE.linaro` | Linaro-supplied files | BSD-3-Clause style |
| `LICENSE.qcom_yamato` | two old GPU microcode files | BSD-3-Clause |

### B. `firmware-xiaomi-pipa-*` (nine small packages, version 3)

Device-specific files for this tablet, packaged in postmarketOS (`pmaports`, `device/testing/firmware-xiaomi-pipa`), whose source is the
community repository <https://github.com/pipa-mainline/xiaomi-pipa-firmware> (commit `842d35be…`).

| Package | What it is |
|---|---|
| `-adreno` | GPU zap shader (`a650_zap.mbn`) |
| `-adsp`, `-cdsp`, `-slpi` | audio, compute and sensor DSP firmware and their configuration |
| `-venus` | video encoder/decoder firmware |
| `-hexagonfs` | files the DSP userspace daemon reads |
| `-awinic` | audio amplifier (Awinic AW88230) |
| `-novatek` | touch controller firmware for both panels (NT36532, Tianma and CSOT variants) |
| `-nuvolta` | Nuvolta RX1665 chip firmware |

**Licence status: unknown / not granted in writing.** The package metadata says only `proprietary`. The source repository has no README
and no licence file (checked on 2026-11-20: it contains just the directories `lib/` and `usr/`), and the files are not part of
linux-firmware. The rights belong to the chip and device makers (for example Qualcomm, Xiaomi, Awinic, Novatek, Nuvolta); we have not
verified where the files were taken from, and we have **no statement from the rights holders** that allows their redistribution. The
postmarketOS binary repository distributes the packages, and the DorothyOS build downloads them from there; the images then carry the
same binaries. That is how the packages reach everybody who installs postmarketOS on this tablet, but it is not a permission from the rights
holders. Treat it as a risk the maintainer has accepted knowingly.

## 2. What DorothyOS does about it

* **The firmware stays out of the git tree.** Only the release images contain it, and `*.packages.txt` marks every such package
  (`proprietary` or `custom`).
* **The licence texts accompany the images:** they are installed on the device in `/usr/share/licenses/dorothyos-branding/firmware/` (with this
  page in `/usr/share/doc/dorothyos-branding/FIRMWARE.md`), they are in `docs/firmware-licenses/` in the repository, and one file
  `FIRMWARE-NOTICES.txt` is attached next to the images in every release (it contains this page and all the texts above). The notices are not removed or altered, and the blobs are
  redistributed unmodified.
* **The MIT licence of this repository does not cover any firmware** (`LICENSE`, *Scope*), and nothing here puts firmware under other terms.
* **No affiliation, no endorsement.** DorothyOS is an independent community project; the names above are used only to say whose firmware
  it is.
* **If you hold rights to one of these files and object** to its redistribution, open an issue (or, for something you would rather not
  discuss in public, a private security advisory) in this repository. The file will be removed from the images and the release assets
  as soon as possible and replaced by a build without it, if the hardware can still work.
* The images can be built without these packages only in theory: without them the tablet has no touch, GPU acceleration, audio, sensors,
  Wi-Fi or Bluetooth. We do not offer such a build.

## 3. Source code for the free software in the images

For every GPL/LGPL/MPL package the corresponding source is available from the places listed in `THIRD_PARTY.md`; the exact versions are
in `*.packages.txt`. Specifically for the kernel (`linux-xiaomi-pipa` 7.2.4, GPL-2.0-only): the unmodified kernel.org tarball
`linux-7.2.4.tar.xz` plus the patches and the configuration in the postmarketOS package
<https://gitlab.postmarketos.org/postmarketOS/pmaports/-/tree/master/device/testing/linux-xiaomi-pipa>. On request (open an issue) the
maintainers will point you to the exact source of any component of a published image for at least three years after its release.

## 4. Thanks

To the **linux-firmware** maintainers and every vendor who submits redistributable firmware to it; to the **Alpine Linux** maintainers of
the `linux-firmware` packages; to **postmarketOS** and the maintainer of the Xiaomi Pad 6 packages in `pmaports`; and to the
**pipa mainline community** that collected and published the device-specific files and made this tablet usable with mainline Linux.
