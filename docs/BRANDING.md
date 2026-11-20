# Branding

DorothyOS has its own name, logo, boot splash, wallpapers and accent colour. The identity lives in one package,
**`dorothyos-branding`** (`overlay/dorothyos-branding/`), so that a fork can re-brand the whole system by changing that package only.

## The identity

| | |
|---|---|
| Name | **DorothyOS** (wordmark written `dorothyOS`) |
| Mark | a ring: black disc, orange ring, white centre (dark mark on a light tile for the app icon) |
| Colours | brand orange `#fd6d00`, light orange `#fca95e`, ink `#0d0d0f`; **UI accent `#e85d00`** (the deeper orange used for selections, switches, sliders) |
| Boot splash | dark screen, an orange ring with one turning arc — no text and no white disc on purpose: the Pad 6 panel boots in its native *portrait* orientation and Plymouth cannot know how the tablet is held, so the mark has to look right in any rotation |

Sources and outputs: `branding/logo/` (vector master + `build-logos.sh`), `branding/splash/build-splash.py`,
`branding/wallpapers/make-wallpapers.py`. Run them to regenerate every PNG; the committed outputs are what the package installs.

## Where the identity shows up on the system

| Place | How |
|---|---|
| `/etc/os-release`, `/usr/lib/os-release` | `NAME=DorothyOS`, `ID=dorothyos`, `ID_LIKE=alpine` (kept so that package tooling still recognises the base), `PRETTY_NAME="DorothyOS 0.1.0-rc1"`, `LOGO=dorothyos`, `ANSI_COLOR`, `VARIANT="Xiaomi Pad 6"`. On stock images `/etc/os-release` is a symlink to `/usr/lib/os-release`; `dorothyos-branding-apply` replaces it by a real file and an apk trigger re-applies it after every base-system upgrade |
| KDE **About this System** page | `/etc/xdg/kcm-about-distrorc` (`Name`, `Version`, `Variant`, `Logo`, `Website`) generated from `os-release` |
| Login console banner, SSH banner | `/etc/issue`, `/etc/motd` (only replaced while they still contain the stock Nura/postmarketOS text — a text edited by the user is never overwritten) |
| Boot menu | `title DorothyOS` in the systemd-boot entry (`build/postprocess.sh`) |
| Boot splash | Plymouth theme `dorothyos` (`/usr/share/plymouth/themes/dorothyos`), selected in `/etc/plymouth/plymouthd.conf` unless the user picked another theme |
| Wallpapers | KDE wallpaper packages `/usr/share/wallpapers/DorothyOS-*` (8 pictures, 2880×1800), rotated hourly by `phase11` |
| App icon | `dorothyos` in the hicolor icon theme (16–512 px + SVG) — the dock's start button, the About page, the Settings app |
| Accent colour | `phase18-branding-user.sh` at the first login (`plasma-apply-colorscheme --accent-color`), undo available |
| Hostname | `dorothyos` |
| `/etc/dorothyos-release` | machine-readable build info (version, panel, build date) |

## Credits policy: given, but quietly

DorothyOS is its own system, so the interface leads with **DorothyOS** everywhere a user looks (boot menu, splash, login console, *About this System*, Settings, wallpapers).
Upstream credits are not hidden — they are just not the headline:

| Where | What is shown |
|---|---|
| *About this System* (KDE) and *Settings → About DorothyOS* | DorothyOS name, version, device — **no** base-system name, logo or website. Settings → About has one muted line, **Acknowledgements**, that opens a short thank-you dialog |
| `/etc/os-release` | `NAME`, `PRETTY_NAME` = DorothyOS; `ID_LIKE` keeps the technical lineage (`nura alpine`) because package tooling reads it; it is not displayed |
| login banner (`/etc/issue`, `/etc/motd`) | DorothyOS only |
| `CREDITS.md`, `/usr/share/doc/dorothyos-branding/CREDITS.md`, `THIRD_PARTY.md`, `/usr/share/licenses`, the release notes | the full, honest list with licences — one click away, never in the way |
| README | one short "Credits and licences" section at the end |

The legal minimum (licence texts, the source offer in `THIRD_PARTY.md`, the "independent project, not affiliated" statement) stays in those documents. Changing the
policy is a one-file change (`overlay/dorothyos-branding/src/CREDITS.md`, the helper's `CREDITS_TEXT`) but it is a policy decision for the maintainers.

## What is *not* re-branded, and why

* Package names (`linux-xiaomi-pipa`, `postmarketos-*`, `alpine-*`) and the apk repository stay what they are: DorothyOS is built **from**
  the postmarketOS repository and says so (`BASE=` in `/etc/dorothyos-release`, `docs/BUILD.md`).
* The names Nura, postmarketOS, Alpine, KDE, Plasma, Qt, Xiaomi are trademarks of their owners; the "not affiliated" notice is in
  `THIRD_PARTY.md` and `README.md`.
* The login screen (plasma-login-manager) uses the Plasma defaults plus the wallpaper; it has no DorothyOS-specific theme yet.

## Boot splash — what to check on the device

The splash theme is a Plymouth *script* theme (`dorothyos.script`). It uses the same script-engine calls as the stock postmarketOS theme
(`Window.*`, `Image.Scale`, `Sprite`, `Plymouth.SetRefreshFunction` …), but it could **not** be rendered in the build container (no
framebuffer), so it is verified structurally only (files present, listed in the initramfs). If the stock postmarketOS splash shows instead:

1. `cat /etc/plymouth/plymouthd.conf` must say `Theme=dorothyos`;
2. `lsinitramfs`-style check: `zcat /boot/initramfs | cpio -t | grep plymouth/themes/dorothyos` must list the theme (the stock
   `mkinitfs` hook `30-postmarketos-bootsplash.files` copies the whole `/usr/share/plymouth`);
3. regenerate it with `doas mkinitfs`, reboot, and report the output of `journalctl -b | grep -i plymouth` in an issue.

## Re-branding for a fork

1. Edit `overlay/dorothyos-branding/src/dorothyos-branding.conf` (name, id, version, URLs, accent).
2. Replace the artwork: `branding/logo/dorothyos-master-template.svg` (placeholders `@BLACK@ @ORANGE@ @LIGHT@`) and rerun
   `sh branding/logo/build-logos.sh`, `python3 branding/splash/build-splash.py`, copy the outputs into `overlay/dorothyos-branding/src/`.
3. Replace the licence statement in `ARTWORK-LICENSE.txt`.
4. Bump `pkgver` in both APKBUILDs and `build/build-image.sh` expects the two to be equal.

## Artwork licences

| Asset | Licence |
|---|---|
| Wallpapers | CC0 1.0 (public-domain dedication) |
| Logo, wordmark, app icon, splash | CC BY 4.0 |
| Everything else | MIT |
