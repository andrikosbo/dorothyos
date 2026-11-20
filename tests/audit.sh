#!/bin/sh
# audit.sh — pre-publication audit of the repository tree (run it on the build host before every release):
#   * secrets (private keys, access tokens), personal data and device identifiers
#   * missing licence files, leftover placeholders, unexpectedly large files
# Exit status 1 when something must be fixed. Usage:  sh tests/audit.sh
set -u
cd "$(dirname "$0")/.."
ROOT=$(pwd)
fail=0
warn() { echo "WARN  $*"; }
bad()  { echo "FAIL  $*"; fail=1; }
EXCL='^\./(dist|tests/logs|release/out|\.git)/'
files() { find . -type f ! -name '.DS_Store' | grep -Ev "$EXCL"; }

echo "== files audited: $(files | wc -l | tr -d ' ')"

# 1. secrets -----------------------------------------------------------------------------------------------------------
pat_secret='-----BEGIN [A-Z ]*PRIVATE KEY-----|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}|sk-[A-Za-z0-9]{32,}'
files | while read -r f; do grep -IEn "$pat_secret" "$f" /dev/null; done > /tmp/audit-secret.$$ 2>/dev/null
if [ -s /tmp/audit-secret.$$ ]; then cat /tmp/audit-secret.$$; bad "possible secrets found (above)"; else echo "ok    no secrets / private keys / tokens"; fi
rm -f /tmp/audit-secret.$$

# 2. personal data and device identifiers ------------------------------------------------------------------------------------
# Generic patterns are built in. Anything specific to a person or a device (a name, a host name, a Wi-Fi name, a key
# directory ...) is NOT written in this repository: put such regular expressions, separated by |, in the environment
# variable PRIVATE_PATTERNS (e.g. export PRIVATE_PATTERNS='name1|name2|host3') before running this script.
pat_pii="/Users/|/Volumes/|[Ii][Mm][Ee][Ii]:? ?[0-9]{14,15}|serial(no| number)[:= ]+[A-Za-z0-9]{6,}${PRIVATE_PATTERNS:+|$PRIVATE_PATTERNS}"
files | grep -v -e '^./tests/audit.sh$' -e '^./tests/validate-image.sh$' | while read -r f; do grep -IEn "$pat_pii" "$f" /dev/null; done > /tmp/audit-pii.$$ 2>/dev/null
if [ -s /tmp/audit-pii.$$ ]; then cat /tmp/audit-pii.$$; bad "personal data / device identifiers (above)"; else echo "ok    no local paths, private patterns, IMEI / serial numbers"; fi
rm -f /tmp/audit-pii.$$
# MAC addresses (6 hex pairs) other than the documented all-zero / example ones
files | while read -r f; do grep -IEno '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' "$f" /dev/null; done | grep -Ev '00:00:00:00:00:00|aa:bb:cc:dd:ee:ff|AA:BB:CC:DD:EE:FF|12:34:56:78:9a:bc' > /tmp/audit-mac.$$ 2>/dev/null
if [ -s /tmp/audit-mac.$$ ]; then cat /tmp/audit-mac.$$; bad "MAC-address-like strings (above)"; else echo "ok    no MAC addresses"; fi
rm -f /tmp/audit-mac.$$

# 3. licences -----------------------------------------------------------------------------------------------------------------
[ -f LICENSE ] && echo "ok    LICENSE present" || bad "LICENSE missing"
[ -f overlay/dorothyos-branding/src/ARTWORK-LICENSE.txt ] && echo "ok    ARTWORK-LICENSE.txt present" || bad "ARTWORK-LICENSE.txt missing"
[ -f THIRD_PARTY.md ] && echo "ok    THIRD_PARTY.md present" || warn "THIRD_PARTY.md missing"

# 3b. the credits file shipped in the branding package must be the one in the repository root
cmp -s docs/FIRMWARE.md overlay/dorothyos-branding/src/FIRMWARE.md && diff -rq docs/firmware-licenses overlay/dorothyos-branding/src/firmware-licenses >/dev/null && echo "ok    firmware notices identical in docs/ and in the branding package" || bad "docs/FIRMWARE.md or docs/firmware-licenses differ from the copies in overlay/dorothyos-branding/src (copy them)"
cmp -s CREDITS.md overlay/dorothyos-branding/src/CREDITS.md && echo "ok    CREDITS.md identical in the repository root and in the branding package" || bad "CREDITS.md differs from overlay/dorothyos-branding/src/CREDITS.md (copy it)"

# 4. leftover placeholders ---------------------------------------------------------------------------------------------------------
ph=$(files | grep -v '^./tests/audit.sh$' | while read -r f; do grep -IEn 'OWNER/|TODO|dorothyos\.invalid' "$f" /dev/null; done)
if [ -n "$ph" ]; then echo "info  placeholders found:"; echo "$ph" | sed 's/^/        /' | cut -c1-170; fi

# 5. leftovers of the old project name -----------------------------------------------------------------------------------------
old=$(files | grep -v '^./tests/audit.sh$' | while read -r f; do grep -IEn 'pipa-plasma-tablet' "$f" /dev/null; done | grep -v 'CHANGELOG' | head -5)
[ -z "$old" ] && echo "ok    no stray references to the old project name" || { echo "$old"; warn "old project name still referenced (above)"; }

# 6. large files and binaries -------------------------------------------------------------------------------------------------
big=$(find . -type f -size +2000k ! -path './dist/*' ! -path './tests/logs/*' ! -path './release/out/*' ! -path './.git/*' | head)
[ -z "$big" ] && echo "ok    no file larger than 2 MB in the tree" || { echo "$big"; warn "large files in the tree (above): publish artifacts as release assets, not in git"; }
[ -d dist ] && echo "info  dist/ exists and is NOT part of the audited tree (release assets, never committed)"

# 7. executable scripts must have a shebang ------------------------------------------------------------------------------------
files | while read -r f; do [ -x "$f" ] && case "$f" in *.png|*.svg|*.jpg|*.apk|*.img) ;; *) head -c2 "$f" | grep -q '^#!' || echo "$f";; esac; done > /tmp/audit-x.$$
[ -s /tmp/audit-x.$$ ] && { cat /tmp/audit-x.$$; warn "executable files without shebang (above)"; } || echo "ok    executables have a shebang"
rm -f /tmp/audit-x.$$

echo
[ $fail = 0 ] && echo "AUDIT PASSED" || echo "AUDIT FAILED"
exit $fail
