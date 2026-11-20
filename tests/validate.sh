#!/bin/bash
# validate.sh [IMAGE.sparse.img PANEL ...] — host wrapper: runs tests/validate-image.sh for each image in a throw-away privileged arm64
# Alpine container (Docker needed, nothing else on your system is touched). Default: both images in dist/.
#     tests/validate.sh                                   # dist/dorothyos-*-{tianma,csot}.sparse.img
#     tests/validate.sh dist/dorothyos-0.1.0-csot.sparse.img csot
set -euo pipefail
cd "$(dirname "$0")/.."
REPO=$(pwd)
mkdir -p tests/logs
if [ $# -eq 0 ]; then
  set --
  for p in tianma csot; do
    f=$(ls dist/dorothyos-*-"$p".sparse.img 2>/dev/null | head -1 || true)
    [ -n "$f" ] && set -- "$@" "$f" "$p"
  done
  [ $# -gt 0 ] || { echo "no images in dist/ (run build/build.sh first)"; exit 2; }
fi
docker volume create pipa-validate-work >/dev/null
rc=0
while [ $# -ge 2 ]; do
  img=$1; panel=$2; shift 2
  log=tests/logs/validate-$panel.log
  echo "### validating $img ($panel) -> $log"
  docker run --rm --privileged --platform linux/arm64 ${PRIVATE_PATTERNS:+-e PRIVATE_PATTERNS} -v "$REPO":/repo:ro -v pipa-validate-work:/scratch alpine:edge \
    sh /repo/tests/validate-image.sh "/repo/$img" "$panel" 2>&1 | tee "$log" | grep -E '^(FAIL|WARN|RESULT|VALIDATION)' || true
  grep -q '^VALIDATION PASSED' "$log" || rc=1
done
exit $rc
