#!/usr/bin/env bash
# Fetch the exact kernel source tree used for the validated build:
# LineageOS android_kernel_samsung_sm8250 (Samsung SM8250 kernel with the
# CIP 4.19 updates merged), pinned to one commit.
#
# Usage: kernel/get-sources.sh [DEST]      (default: ./sources)
#
# 1. git: shallow fetch of the pinned commit from GitHub (~250 MB)
# 2. fallback: the source archive from the project mirror, SHA-256 verified
#    (downloads/android_kernel_samsung_sm8250-<commit>.tar.xz, see docs/mirror.md)
# The patch is NOT applied here: kernel/build-kernel.sh does it.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$(realpath -m "${1:-$REPO_ROOT/sources}")"
KERNEL_REPO="${KERNEL_REPO:-https://github.com/LineageOS/android_kernel_samsung_sm8250.git}"
KERNEL_COMMIT="4910fe83f91f340e28ada2c956a5ca39676dc619"   # lineage-23.2, 2026-03-11
ARCHIVE="android_kernel_samsung_sm8250-${KERNEL_COMMIT:0:9}.tar.xz"

ok()   { echo -e "  \033[0;32mOK\033[0m $*"; }
fail() { echo -e "\033[0;31mERROR\033[0m $*" >&2; exit 1; }

check_tree() {
    grep -q '^SUBLEVEL = 325$' "$DEST/Makefile" 2>/dev/null && [ -d "$DEST/techpack/display" ]
}

if [ -f "$DEST/Makefile" ]; then
    check_tree || fail "$DEST exists but is not the expected 4.19.325 SM8250 tree. Move it away and re-run."
    if git -C "$DEST" rev-parse HEAD >/dev/null 2>&1; then
        [ "$(git -C "$DEST" rev-parse HEAD)" = "$KERNEL_COMMIT" ] \
            || echo "  WARNING: $DEST is at $(git -C "$DEST" rev-parse --short HEAD), expected ${KERNEL_COMMIT:0:9}."
    fi
    ok "Kernel sources already present in $DEST"
    exit 0
fi

mkdir -p "$(dirname "$DEST")"

# --- 1. git, pinned commit ---
if command -v git >/dev/null; then
    echo "Fetching $KERNEL_REPO @ ${KERNEL_COMMIT:0:9} (shallow)..."
    TMP_GIT="$DEST.part"
    rm -rf "$TMP_GIT"
    if git init -q "$TMP_GIT" \
        && git -C "$TMP_GIT" remote add origin "$KERNEL_REPO" \
        && git -C "$TMP_GIT" fetch -q --depth 1 origin "$KERNEL_COMMIT" \
        && git -C "$TMP_GIT" -c advice.detachedHead=false checkout -q FETCH_HEAD; then
        mv "$TMP_GIT" "$DEST"
        check_tree || fail "Fetched tree does not look right."
        ok "Kernel sources in $DEST (git, ${KERNEL_COMMIT:0:9})"
        exit 0
    fi
    rm -rf "$TMP_GIT"
    echo "  git fetch failed, falling back to the mirror archive."
fi

# --- 2. mirror archive ---
# shellcheck source=../scripts/lib/fetch.sh
. "$REPO_ROOT/scripts/lib/fetch.sh"
fetch_artifact "$ARCHIVE" || fail "Kernel sources unavailable from both GitHub and the mirror."
mkdir -p "$DEST"
tar -xJf "$REPO_ROOT/downloads/$ARCHIVE" -C "$DEST" --strip-components=1
check_tree || fail "Extracted tree does not look right."
ok "Kernel sources in $DEST (mirror archive, ${KERNEL_COMMIT:0:9})"
