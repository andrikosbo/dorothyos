#!/bin/bash
# build.sh [tianma|csot|both] — builds the flashable image(s) in a privileged Alpine edge container (Docker).
#
#   ./build/build.sh both          # -> dist/dorothyos-<version>-{tianma,csot}.sparse.img + manifests + SHA256SUMS
#
# Needs: Docker (Docker Desktop on macOS/Windows, or Docker on Linux) that can run PRIVILEGED linux/arm64 containers, ~25 GB
# free disk, a fast internet connection (the build downloads ~2 GB of postmarketOS/Alpine packages, cached afterwards).
# An aarch64 host (Apple Silicon, ARM64 Linux) is the tested case. On x86_64 Docker would emulate arm64 (very slow, UNTESTED):
# set PIPA_ALLOW_EMULATION=1 to try anyway.
#
# The repository is mounted READ-ONLY into the container; all build state lives in the Docker volume ($PIPA_VOLUME) and
# only the finished artifacts are copied to ./dist. Nothing is written to your system outside Docker.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO=$(pwd)
WHAT=${1:-both}
NAME=${PIPA_CONTAINER:-pipa-build}
VOL=${PIPA_VOLUME:-pipa-pmb-work}
case "$WHAT" in tianma|csot) PANELS="$WHAT" ;; both) PANELS="tianma csot" ;; *) echo "usage: $0 tianma|csot|both"; exit 2 ;; esac
command -v docker >/dev/null || { echo "docker not found"; exit 2; }
arch=$(docker info --format '{{.Architecture}}' 2>/dev/null || true)
case "$arch" in aarch64|arm64) ;; *) [ "${PIPA_ALLOW_EMULATION:-0}" = 1 ] || { echo "Docker host architecture is '$arch', not arm64. Set PIPA_ALLOW_EMULATION=1 to try emulation (very slow, untested)."; exit 2; } ;; esac

docker volume create "$VOL" >/dev/null
if ! docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  docker run -d --name "$NAME" --privileged --platform linux/arm64 -v "$REPO":/repo:ro -v "$VOL":/work alpine:edge sleep infinity >/dev/null
fi
echo "alpine:edge image: $(docker inspect "$NAME" --format '{{.Image}}')"
mkdir -p dist
for p in $PANELS; do
  echo "=== building $p ==="
  docker exec "$NAME" sh /repo/build/build-image.sh "$p"
done
docker cp "$NAME":/work/out/. dist/
echo "artifacts in $REPO/dist:"; ls -la dist
