#!/usr/bin/env python3
"""pmbootstrap launcher that skips pmbootstrap's own download of apk-tools-static.

Why: pmbootstrap v3.12 downloads the newest apk-tools-static from Alpine edge (3.0.10 at the time of writing). That
version fails to install systemd-udevd on a fresh rootfs ("failed to commit usr/bin/udevadm", duplicate paths in the
merged-/usr layout). build/container-setup.sh therefore puts a known-good apk-tools-static (3.0.9, Alpine v3.24) at
$WORK/apk.static, and this launcher makes pmbootstrap use it as it is.  Everything else is stock pmbootstrap.
"""
import sys
import pmb.helpers.apk_static as apk_static

apk_static.init = lambda: None          # keep the pinned binary, do not fetch a newer one

from pmb import main  # noqa: E402

sys.argv[0] = "pmbootstrap"
sys.exit(main())
