# Building the images

```sh
./build/build.sh both            # or: tianma | csot
# -> dist/dorothyos-<version>-{tianma,csot}.sparse.img  + .packages.txt + .boot-entries.txt + .SHA256SUMS
```

## Requirements

* Docker that can run **privileged linux/arm64** containers (Docker Desktop on macOS or Windows, or Docker on Linux). The tested
  host is an Apple-silicon Mac. On an x86-64 host the build would run under emulation: very slow and **untested** (set
  `PIPA_ALLOW_EMULATION=1`).
* About 25 GB free disk space and a good connection: ~2 GB of postmarketOS/Alpine packages are downloaded the first time
  (cached in the Docker volume `pipa-pmb-work`, the next build takes minutes).
* No `sudo` on the host is needed; the privileged part runs inside the container.

## What the pipeline does

| Step | Script | Result |
|---|---|---|
| 0 | `build/build.sh` | starts a privileged `alpine:edge` container, mounts this repository **read-only** and a Docker volume for the work area |
| 1 | `build/container-setup.sh` | installs `pmbootstrap` and tools; installs a **pinned `apk-tools-static` 3.0.9** (SHA-256 checked) |
| 2 | `build/build-image.sh` | configures `pmbootstrap` (device `xiaomi-pipa`, kernel `tianma`/`csot`, UI `plasma-desktop`, systemd, package list `build/packages.txt`); builds the apks `dorothyos-tablet` (from `overlay/dorothyos-tablet`) and `dorothyos-branding` (from `overlay/dorothyos-branding`) (deterministic source tarball + APKBUILD, built by `pmbootstrap build`); runs `pmbootstrap install --no-sshd --no-split` |
| 3 | `build/postprocess.sh` | mounts the image, **deletes the throw-away build account**, locks root, masks `systemd-firstboot`, removes ssh keys/histories/machine-id, checks that Plasma Setup is enabled, writes `/etc/dorothyos-release`, the package list with licences and the boot-entry listing, converts to an Android sparse image (`img2simg`), writes SHA-256 sums |

`build/loop-partnodes.sh` is a workaround for Docker Desktop: its VM has no udev, so `/dev/loopNpM` partition nodes are not
created; the script creates them from `/sys` while `pmbootstrap` installs.

## Why the apk-tools pin

`pmbootstrap` 3.12 downloads the newest `apk-tools-static` from Alpine edge. With version 3.0.10 the installation of `systemd` into a
fresh rootfs failed (`failed to commit usr/bin/udevadm` — duplicate paths in the merged-`/usr` layout). 3.0.9 from Alpine v3.24 works,
so `build/pmb-pinned.py` makes pmbootstrap use that binary. Remove the pin when upstream fixes it.

## What "reproducible" means here

The **procedure** is reproducible: the same repository revision, the same pinned tools and the same package list give the same
configuration on any machine. The **bytes** are not identical between builds: postmarketOS `systemd-edge` and Alpine `edge` are
rolling repositories (package versions move), the ext4 and FAT file systems get new UUIDs/timestamps, and the image contains
build dates. Therefore every release publishes the exact package list (`*.packages.txt`) and SHA-256 of the artifacts it
was built with, and the tests in `tests/` check properties (no account, locked root, correct device tree, …), not hashes.

## Customising

* Package list: `build/packages.txt`. The UI is the postmarketOS `postmarketos-ui-plasma-desktop` meta-package with extras.
* The tablet-first UI: `overlay/dorothyos-tablet/src/` (QML widgets, shell/python scripts). The apk is rebuilt on every build.
* Disk encryption: not enabled by default (see `SECURITY-MODEL.md`); pass `--fde` to the `pmbootstrap install` line in `build/build-image.sh`
  for your own private build (untested here: you must type the passphrase on a tablet screen at every boot).

## Tests

```sh
sh tests/audit.sh        # the repository tree: secrets, personal data, licence files, placeholders, large files (does NOT look at dist/)
./tests/validate.sh      # both images in dist/, offline, in a throw-away privileged container -> tests/logs/validate-<panel>.log
./tests/validate.sh dist/dorothyos-<ver>-<panel>.sparse.img <panel>      # one image
```

`validate-image.sh` unpacks the sparse image (`tests/unsparse.py`, plain Python), mounts both partitions **read-only** and checks:
accounts / locked root / no keys, histories, Wi-Fi or Bluetooth data, no identifiers of the maintainer; services (first-boot wizard enabled,
sshd off); the panel (device tree in the boot entry exists on the ESP, only the right kernel-variant package installed); the branding
(`os-release`, About page, Plymouth theme in the initramfs, wallpapers, icons); the touch UI (commands, plasmoid metadata, display config,
lock-screen patch, shell syntax); the package database; and both file systems (`e2fsck`, `fsck.vfat`). The results of the last run are in
`VALIDATION.md`. **None of this proves that the image boots** — only a tablet does.

## Testing a widget without a tablet

The QML of the home grid, control center, start menu and Settings can be rendered offscreen, which is how the UI was developed while the
tablet screen was locked. On a Linux machine with Plasma 6 (or on the tablet) copy the plasmoid to a throw-away id, wrap its root item in a
fixed-size `Item`, add a `Timer` that sets the state you want to see and calls `grabToImage(r => r.saveToFile("/tmp/x.png"))`, then:

```sh
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software plasmawindowed <throwaway-id>
```

Offscreen the screen reports 800 px and the light-scheme text colours, and QQC2 buttons draw no icons — so judge layout and logic, not colours.
Delete the throw-away package and `~/.config/plasmawindowed-appletsrc` afterwards. Touch gestures cannot be injected this way: say in your
pull request what you could not test.
