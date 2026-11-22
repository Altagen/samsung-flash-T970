#!/usr/bin/env bash
# Generate vbmeta_disabled.img: an empty vbmeta (no descriptors, no signature)
# with flags = 3 (HASHTREE_DISABLED | VERIFICATION_DISABLED). Flashed to the
# VBMETA partition, it turns Android Verified Boot off so the bootloader
# accepts TWRP and the custom boot image.
#
# Usage: firmware/make-vbmeta-disabled.sh [OUTPUT]   (default: firmware/vbmeta_disabled.img)
#
# Uses the avbtool pinned in the sm8250-builder image (AOSP android-14.0.0_r75),
# which reproduces byte for byte the image flashed during the project (see
# SHA256SUMS). Falls back to the host's avbtool when no container engine exists.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$(realpath -m "${1:-$HERE/vbmeta_disabled.img}")"
ENGINE="${CONTAINER_ENGINE:-podman}"
IMAGE="sm8250-builder:v2"

if ! command -v "$ENGINE" >/dev/null; then
    command -v avbtool >/dev/null || { echo "Neither $ENGINE nor avbtool found." >&2; exit 1; }
    avb() { avbtool "$@"; }
    AVB_OUT="$OUT"
else
    if ! "$ENGINE" image inspect "$IMAGE" >/dev/null 2>&1; then
        "$ENGINE" build -t "$IMAGE" -f "$HERE/../Containerfile.d/Containerfile" "$HERE/../Containerfile.d"
    fi
    mkdir -p "$(dirname "$OUT")"
    avb() { "$ENGINE" run --rm -v "$(dirname "$OUT")":/out "$IMAGE" avbtool "$@"; }
    AVB_OUT="/out/$(basename "$OUT")"
fi

avb make_vbmeta_image --flags 3 --padding_size 4096 --output "$AVB_OUT"
avb info_image --image "$AVB_OUT" | grep -E '^(Algorithm|Flags):'
echo "Written: $OUT ($(stat -c %s "$OUT") bytes)"
