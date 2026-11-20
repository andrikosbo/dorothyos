# Contributing to DorothyOS

Thanks for helping. The project is small and hardware-limited (one tablet model, two panels), so the most valuable contributions are
**reports and tests from real tablets**, then fixes.

## Before you post anything — what must never appear in an issue, a log or a screenshot

* serial numbers, IMEI, MAC addresses, Wi-Fi names (SSIDs) and passwords, Bluetooth device names, your account name and e-mail
* any file from the `persist`, `modem*` or `fsg` partitions, Android backups, `DEVICE_STATE`-style dumps
* ssh keys, tokens, the output of `env`, full `dmesg`/`journalctl` without reading it first (they contain MAC addresses and serials)
* screenshots of the lock screen or settings pages that show your network or accounts

Post the *relevant lines*, with identifiers replaced by `xx`.

## Reporting a problem

Use the issue templates. Please say: the **panel** (tianma/csot), the **image version** (`cat /etc/dorothyos-release`), whether the image
was flashed fresh or upgraded, and what you tried. For the first boot of a release image (success **or** failure) there is a template of its own —
that report is what turns "release candidate" into "verified" in `docs/VALIDATION.md`.

Security problems in this repository's scripts: use the repository's *security advisory* page, not a public issue.
Bugs in postmarketOS, KDE Plasma, the kernel or Mesa belong upstream — but tell us, we will link them.

## Changing something

1. **Never test on someone's only tablet.** UI changes (QML) can be rendered offscreen without hardware — see `docs/BUILD.md` → "Testing a widget
   without a tablet" (`QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software plasmawindowed <id>` + `grabToImage`).
2. Shell scripts are POSIX `sh` unless they say bash; run `sh -n` and, if you can, `shellcheck`.
3. A phase script (`overlay/dorothyos-tablet/src/phase*.sh`) must be **idempotent**, have an `undo`, and never delete user data. Settings you
   change must be backed up first (see `phase18-branding-user.sh`). Never fall back to a different colour scheme / theme silently.
4. Everything that ends up on the device goes through the two packages in `overlay/`; do not add files by editing the image.
5. Before a pull request: `sh tests/audit.sh` must pass; if you changed the build or the packages run `./build/build.sh <panel>` and
   `./tests/validate.sh`.
6. Branding is isolated in `overlay/dorothyos-branding/`; other code must not hard-code the name more than needed.
7. Do not add third-party **brand** artwork (streaming or app-store tiles, …), photographs you do not own, or proprietary binaries. Licences are
   listed in `THIRD_PARTY.md`; new dependencies must be added there.

## Commit style

Short imperative subject, a body that says *why*. Reference the issue. One topic per commit.

## Licence of contributions

By contributing you agree that your code is licensed under the MIT licence (`LICENSE`) and your artwork under the licence stated in
`overlay/dorothyos-branding/src/ARTWORK-LICENSE.txt`.

## Conduct

Be kind, assume good faith, keep it about the work. Maintainers may remove comments that are abusive or that leak other people's data.
