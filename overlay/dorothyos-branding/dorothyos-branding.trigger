#!/bin/sh
# an upgrade of alpine-release / postmarketos-release restores the upstream symlink: re-apply our identity
/usr/bin/dorothyos-branding-apply --quiet || :
exit 0
