# Credits

DorothyOS stands on the work of many open-source communities. Thank you.

DorothyOS is created and maintained by [Andreas Boglou](https://boglou.com).

| | |
|---|---|
| **postmarketOS** and **Alpine Linux** | the base system, the Xiaomi Pad 6 device packages, the firmware packaging and the `pmbootstrap` build tool |
| **The pipa mainline-Linux community** | Linux and U-Boot for the Xiaomi Pad 6 (the kernel port, the panel and sensor work) and the collected device firmware files |
| **linux-firmware** and its contributors | the Wi-Fi, Bluetooth and GPU firmware collection (<https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git>), packaged by Alpine Linux; the vendors' notices are in `docs/firmware-licenses/` (`FIRMWARE.md`) |
| **KDE** | Plasma, KDE Frameworks, Plasma Setup, Dolphin, Okular, Kate, Gwenview, Konsole, Discover and the other apps |
| **Qt** | the toolkit everything above is written in |
| **Mesa** (freedreno, turnip), **libcamera**, **PipeWire**, **systemd**, **NetworkManager**, **BlueZ**, **Flatpak** / **Flathub** | graphics, camera, audio, services, networking, Bluetooth and app delivery |
| **Mozilla Firefox**, **VLC**, **GNOME Snapshot**, **COSMIC Camera** | the apps the image ships or offers |
| and hundreds of other projects | every package, with its version and licence, is listed in `dorothyos-<version>-<panel>.packages.txt` next to each image |

The licences of the included software are in `/usr/share/licenses` on the device (the firmware licence texts are in `docs/firmware-licenses/`, see `docs/FIRMWARE.md`); the project's own licences are in `LICENSE`, `THIRD_PARTY.md`
and `overlay/dorothyos-branding/src/ARTWORK-LICENSE.txt`. On a running system this file is `/usr/share/doc/dorothyos-branding/CREDITS.md`
and *Settings → About DorothyOS → Acknowledgements* shows a short version.

DorothyOS is an independent project. Names such as postmarketOS, Alpine Linux, KDE, Plasma, Qt, Xiaomi, Firefox and Flathub belong to their
owners; DorothyOS is not affiliated with or endorsed by them.
