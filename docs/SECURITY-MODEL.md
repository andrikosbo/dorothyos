# Security model of the image

| Topic | What the image does | Why |
|---|---|---|
| Accounts | **No user account and no password** in the image. At the first boot KDE's *Plasma Setup* wizard asks for language, time zone, Wi-Fi and creates **your** account (member of `wheel`, can use `sudo`). | A shared default password (as some community images have) is a remote-access hole for everybody who ever flashed the image |
| root | locked (`!` in `/etc/shadow`); no password login | use `sudo` from your account |
| SSH | **sshd is not enabled** (`pmbootstrap install --no-sshd`). To enable it after you created your account: `sudo systemctl enable --now sshd`, and use keys (`~/.ssh/authorized_keys`). | no listening service on a freshly flashed device |
| Firewall | postmarketOS default: the nftables firewall service is enabled (`--no-firewall` is not used). Which ports the desktop services (avahi, KDE Connect) open was not audited | |
| Disk encryption | **not encrypted.** The image is published; a passphrase baked into it would be shared by every user. You can build an encrypted image of your own (`--fde` in `build/build-image.sh`, untested) | honest limitation |
| Secure boot / verified boot | not available: the bootloader is unlocked and U-Boot does not verify the kernel | inherent to running Linux on this device |
| Secrets in the repository | none; `tests/audit.sh` scans the tree and the images for key material, tokens, the build password, IP/MAC/serial patterns and personal markers | |
| Build password | `pmbootstrap` insists on a password while it builds. A random 20-character one is generated per build, the account is deleted by `build/postprocess.sh` and the build **fails** if a regular account or an unlocked root remains | |
| machine-id | removed in the image; created on the first boot, so devices do not share one | |
| Third-party app stores | Flathub is *not* pre-configured (add it yourself: `flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo`) | |
| Lock screen | patched for touch (bigger field, hint, the prompt stays up while the keyboard is open). The patch only changes QML layout; it does not touch authentication. If it does not fit a Plasma version it is not applied (stock lock screen stays). `loginctl unlock-session` over SSH always works as an escape. | |

How to report a vulnerability: see `SECURITY.md` in the repository root. Vulnerabilities in postmarketOS, KDE or the kernel belong upstream.
