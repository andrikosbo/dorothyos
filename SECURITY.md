# Security policy

## Supported versions

DorothyOS is in the release-candidate stage. Only the latest release (and the `main` branch) receives fixes.

## Reporting a vulnerability

Please **do not open a public issue** for a security problem. Use GitHub's private reporting instead:
**Security tab → "Report a vulnerability"** of this repository. Describe what is affected (file, script or image version), how to
reproduce it and what the impact is. Do not include personal data (serial numbers, IMEI, MAC addresses, Wi-Fi names, passwords, backups of
`persist`).

This is a small volunteer project: expect an acknowledgement within about a week and a fix or a clear answer as soon as it can be done.

## Scope

* In scope: the scripts, packages, build and flashing tools, and the configuration of the images produced from this repository
  (default accounts, services, file permissions, anything that could expose a user's device or data), and the code of the project website.
* Not in scope: vulnerabilities in postmarketOS, Alpine Linux, KDE, the Linux kernel, U-Boot, Mesa or other upstream software — please report
  them upstream (we are happy to be told so that we can link them).
* Inherent to running Linux on this device and documented, not vulnerabilities of this project: the bootloader is unlocked and there is no
  verified boot; the root file system of the published images is not encrypted. See `docs/SECURITY-MODEL.md`.
