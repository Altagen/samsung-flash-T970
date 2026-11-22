#!/usr/bin/env bash
# Assemble a boot.img for the SM-T970: stock ramdisk + stock DTB + stock
# cmdline/offsets, with only the kernel replaced by our Image.gz.
#
# Usage: kernel/make-boot-img.sh STOCK KERNEL OUTPUT
#   STOCK   stock boot image: boot.img, boot.img.lz4 or the AP_*.tar.md5 firmware file
#   KERNEL  Image.gz produced by kernel/build-kernel.sh
#   OUTPUT  boot image to write (e.g. output/boot-custom.img)
#
# All mkbootimg parameters (header v2, offsets, os_version, board, cmdline)
# are read from the stock image with AOSP unpack_bootimg, never hardcoded.
# In particular the cmdline is kept byte-identical: adding
# androidboot.force_normal_boot=1 to it breaks boot (see docs/how-it-works.md).
#
# The result is NOT flashable yet: patch it with the Magisk app first
# (docs/guide/04-flash-kernel.md).

set -euo pipefail

fail() { echo -e "\033[0;31mERROR\033[0m $*" >&2; exit 1; }

[ $# -eq 3 ] || { sed -n '5,9p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
STOCK="$(realpath "$1")"; KERNEL="$(realpath "$2")"; OUTPUT="$(realpath -m "$3")"

[ -f "$STOCK" ]  || fail "Stock image not found: $STOCK"
[ -f "$KERNEL" ] || fail "Kernel not found: $KERNEL"
[ "$OUTPUT" != "$STOCK" ] || fail "Refusing to overwrite the stock image."

# --- Host tools, or fall back to the builder container ---
# Needs AOSP unpack_bootimg with --format (Arch android-tools, Ubuntu 24.04
# mkbootimg). Debian 12 / Ubuntu 22.04 ship older versions: then re-run this
# script inside the sm8250-builder image, which carries pinned AOSP tools.
host_tools_ok() {
    command -v mkbootimg >/dev/null && command -v lz4 >/dev/null \
        && unpack_bootimg --help 2>&1 | grep -q -- '--format'
}
if [ -z "${IN_BUILDER:-}" ] && { [ -n "${FORCE_CONTAINER:-}" ] || ! host_tools_ok; }; then
    ENGINE="${CONTAINER_ENGINE:-podman}"
    IMAGE="sm8250-builder:v2"
    REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
    command -v "$ENGINE" >/dev/null || fail "Host lacks a recent mkbootimg/unpack_bootimg/lz4 and $ENGINE is not installed."
    if ! "$ENGINE" image inspect "$IMAGE" >/dev/null 2>&1; then
        echo "Building $IMAGE (boot image tools)..."
        "$ENGINE" build -t "$IMAGE" -f "$REPO_ROOT/Containerfile.d/Containerfile" "$REPO_ROOT/Containerfile.d"
    fi
    echo "Host boot image tools missing or too old: running inside $IMAGE."
    mkdir -p "$(dirname "$OUTPUT")"
    exec "$ENGINE" run --rm -e IN_BUILDER=1 \
        -v "$REPO_ROOT":/repo:ro \
        -v "$(dirname "$STOCK")":/in/stock:ro \
        -v "$(dirname "$KERNEL")":/in/kernel:ro \
        -v "$(dirname "$OUTPUT")":/out \
        "$IMAGE" /repo/kernel/make-boot-img.sh \
        "/in/stock/$(basename "$STOCK")" "/in/kernel/$(basename "$KERNEL")" "/out/$(basename "$OUTPUT")"
fi
gzip -t "$KERNEL" 2>/dev/null || fail "$KERNEL is not a gzip file (use Image.gz, not Image or Image.gz-dtb)."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- Get a plain stock boot.img ---
case "$STOCK" in
    *.tar.md5|*.tar)
        command -v lz4 >/dev/null || fail "lz4 not found."
        tar -xOf "$STOCK" boot.img.lz4 | lz4 -dq - "$TMP/stock.img" \
            || fail "boot.img.lz4 not found in $STOCK (use the AP_ file)." ;;
    *.lz4)
        command -v lz4 >/dev/null || fail "lz4 not found."
        lz4 -dq "$STOCK" "$TMP/stock.img" ;;
    *)
        cp "$STOCK" "$TMP/stock.img" ;;
esac

# --- Read stock parameters ---
mkdir "$TMP/stock"
mapfile -d '' ARGS < <(unpack_bootimg --boot_img "$TMP/stock.img" --out "$TMP/stock" --format=mkbootimg -0)
[ "${#ARGS[@]}" -gt 0 ] || fail "unpack_bootimg returned no arguments."

HEADER=""
for i in "${!ARGS[@]}"; do
    case "${ARGS[$i]}" in
        --kernel)         ARGS[$((i + 1))]="$KERNEL" ;;
        --header_version) HEADER="${ARGS[$((i + 1))]}" ;;
    esac
done
[ "$HEADER" = "2" ] || fail "Expected a header v2 boot image, got v${HEADER:-?}. Wrong device or firmware?"

# --- Build ---
mkdir -p "$(dirname "$OUTPUT")"
mkbootimg "${ARGS[@]}" --output "$OUTPUT"

# --- Verify ---
mkdir "$TMP/new"
unpack_bootimg --boot_img "$OUTPUT" --out "$TMP/new" >/dev/null
same() { [ "$(sha256sum < "$1")" = "$(sha256sum < "$2")" ]; }
same "$TMP/new/kernel"  "$KERNEL"             || fail "Kernel in output differs from $KERNEL."
same "$TMP/new/ramdisk" "$TMP/stock/ramdisk"  || fail "Ramdisk differs from stock."
same "$TMP/new/dtb"     "$TMP/stock/dtb"      || fail "DTB differs from stock."

OUT_SIZE=$(stat -c %s "$OUTPUT"); PART_SIZE=$(stat -c %s "$TMP/stock.img")
[ "$OUT_SIZE" -le "$PART_SIZE" ] || fail "Output ($OUT_SIZE B) is larger than the BOOT partition ($PART_SIZE B)."

echo "Boot image: $OUTPUT ($((OUT_SIZE / 1024 / 1024)) MiB, partition $((PART_SIZE / 1024 / 1024)) MiB)"
echo "  kernel   replaced  ($(basename "$KERNEL"))"
echo "  ramdisk  stock     (verified)"
echo "  dtb      stock     (verified)"
echo "  cmdline  stock"
echo "Next: push it to the tablet and patch it with Magisk (docs/guide/04-flash-kernel.md)."
