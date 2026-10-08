#!/usr/bin/env bash
# build_hailo10h_image.sh — Build Frigate with HailoRT 5.2.0 (Hailo-10H support)
# on an Apple Silicon Mac (native arm64) and transfer the image to a Raspberry Pi 5.
#
# Usage:
#   ./build_hailo10h_image.sh build   # build the image (default)
#   ./build_hailo10h_image.sh verify  # check HailoRT versions inside the image
#   ./build_hailo10h_image.sh save    # export compressed tarball to ./dist
#   ./build_hailo10h_image.sh push    # scp tarball to the Pi (edit PI_* below)
#
# Requirements: Docker Desktop running, built from the frigate repo root.

set -euo pipefail

IMAGE_NAME="frigate-10h"
IMAGE_TAG="5.2.0"
TARBALL="${IMAGE_NAME}:${IMAGE_TAG}.tar.gz"

# --- Raspberry Pi destination (edit these) ---
PI_USER="rdvt"
PI_HOST="hailopi.local"   # replace with your Pi's IP
PI_DIR="~"

cd "$(dirname "$0")"

case "${1:-build}" in
  build)
    echo ">>> Building ${IMAGE_NAME}:${IMAGE_TAG} (native arm64)..."
    docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" -f docker/main/Dockerfile .
    echo ">>> Done. Run '$0 verify' to check the HailoRT versions inside."
    ;;
  verify)
    echo ">>> HailoRT python wheel:"
    docker run --rm --entrypoint pip3 "${IMAGE_NAME}:${IMAGE_TAG}" show hailort | head -2
    echo ">>> hailortcli version (userspace):"
    docker run --rm --entrypoint hailortcli "${IMAGE_NAME}:${IMAGE_TAG}" version | head -2
    echo ">>> libhailort as resolved by the loader (ldconfig -p):"
    echo ">>> and the actual files on disk:"
    docker run --rm --entrypoint sh "${IMAGE_NAME}:${IMAGE_TAG}" \
      -c 'ldconfig -p | grep -i hailort; ls -l /usr/lib/libhailort.so* /usr/lib/aarch64-linux-gnu/libhailort.so* /usr/local/lib/libhailort.so* 2>/dev/null; true'
    echo ">>> Expected: hailort 5.2.0 everywhere and NO libhailort.so.4.21.0 under /usr/local/lib"
    ;;
  save)
    mkdir -p dist
    echo ">>> Exporting ${TARBALL} (docker save | gzip)..."
    docker save "${IMAGE_NAME}:${IMAGE_TAG}" | gzip > "dist/${TARBALL}"
    ls -lh "dist/${TARBALL}"
    ;;
  push)
    [ -f "dist/${TARBALL}" ] || { echo "Run '$0 save' first"; exit 1; }
    echo ">>> Copying to ${PI_USER}@${PI_HOST}:${PI_DIR} ..."
    scp "dist/${TARBALL}" "${PI_USER}@${PI_HOST}:${PI_DIR}/"
    echo ">>> Now on the Pi run:"
    echo "    docker load < ${PI_DIR}/${TARBALL}"
    ;;
  *)
    echo "Usage: $0 {build|verify|save|push}"
    exit 1
    ;;
esac
