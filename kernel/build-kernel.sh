#!/usr/bin/env bash
# Build the container-enabled SM-T970 kernel (Image.gz) inside a pinned
# toolchain container (Ubuntu 22.04 + clang-12).
#
# Usage: kernel/build-kernel.sh [SOURCE_DIR] [OUTPUT_DIR]
#   SOURCE_DIR  Kernel sources (default: ./sources, fetched by kernel/get-sources.sh if missing)
#   OUTPUT_DIR  Out-of-tree build directory          (default: ./output/kernel)
#
# Environment:
#   CONTAINER_ENGINE  podman (default) or docker
#   JOBS              parallel make jobs (default: nproc)
#
# What it does:
#   1. Builds the toolchain image "sm8250-builder" if it does not exist
#   2. Applies kernel/patches/0001-sm-t970-container-support.patch (skipped if already applied)
#   3. Installs kernel/config/gts7xlwifi_containers.config as .config + olddefconfig
#   4. Compiles Image.gz  ->  OUTPUT_DIR/arch/arm64/boot/Image.gz

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$(realpath -m "${1:-$REPO_ROOT/sources}")"
OUT="$(realpath -m "${2:-$REPO_ROOT/output/kernel}")"
ENGINE="${CONTAINER_ENGINE:-podman}"
JOBS="${JOBS:-$(nproc)}"
IMAGE="sm8250-builder:v2"   # bump when Containerfile.d/Containerfile changes
PATCH="$REPO_ROOT/kernel/patches/0001-sm-t970-container-support.patch"
CONFIG="$REPO_ROOT/kernel/config/gts7xlwifi_containers.config"

step() { echo -e "\n\033[1;36m==> $*\033[0m"; }
fail() { echo -e "\033[0;31mERROR\033[0m $*" >&2; exit 1; }

# --- Pre-checks ---
command -v "$ENGINE" >/dev/null || fail "$ENGINE not found (set CONTAINER_ENGINE=docker to use Docker)."
command -v patch >/dev/null || fail "'patch' not found."
if [ ! -f "$SRC/Makefile" ]; then
    step "Kernel sources"
    "$REPO_ROOT/kernel/get-sources.sh" "$SRC"
fi
grep -q '^VERSION = 4$' "$SRC/Makefile" && grep -q '^PATCHLEVEL = 19$' "$SRC/Makefile" \
    || fail "$SRC does not look like a 4.19 kernel tree."
[ -d "$SRC/techpack/display" ] || fail "$SRC is missing techpack/ — not the SM8250 tree (see kernel/get-sources.sh)."

# --- 1. Toolchain image ---
step "Toolchain image ($IMAGE)"
if "$ENGINE" image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "already built"
else
    "$ENGINE" build -t "$IMAGE" -f "$REPO_ROOT/Containerfile.d/Containerfile" "$REPO_ROOT/Containerfile.d"
fi

# --- 2. Patch ---
step "Kernel patch"
if patch -d "$SRC" -p1 -R --dry-run -s -f < "$PATCH" >/dev/null 2>&1; then
    echo "already applied"
elif patch -d "$SRC" -p1 --dry-run -s -f < "$PATCH" >/dev/null 2>&1; then
    patch -d "$SRC" -p1 -s -f < "$PATCH"
    echo "applied $(basename "$PATCH")"
else
    fail "Patch neither applies nor is already applied. Sources are not the pinned commit (kernel/get-sources.sh)?"
fi

# --- 3. Config ---
step "Kernel config"
mkdir -p "$OUT"
cp "$CONFIG" "$OUT/.config"

run_make() {
    "$ENGINE" run --rm \
        -v "$SRC":/work/sources:ro \
        -v "$OUT":/work/output \
        "$IMAGE" \
        make -C /work/sources O=/work/output ARCH=arm64 LLVM=1 LLVM_IAS=1 "$@"
}

run_make olddefconfig
for opt in CONFIG_USER_NS CONFIG_OVERLAY_FS CONFIG_CGROUP_PIDS CONFIG_VETH CONFIG_IKCONFIG_PROC; do
    grep -q "^$opt=y" "$OUT/.config" || fail "$opt is not enabled after olddefconfig."
done
echo "container options present"

# --- 4. Build ---
step "Compiling Image.gz with $JOBS jobs (15-30 min)"
run_make -j"$JOBS" Image.gz

KERNEL="$OUT/arch/arm64/boot/Image.gz"
[ -f "$KERNEL" ] || fail "Build finished but $KERNEL is missing."

step "Done"
echo "Kernel: $KERNEL ($(du -h "$KERNEL" | cut -f1))"
echo "Next:   kernel/make-boot-img.sh <stock boot.img> $KERNEL output/boot-custom.img"
