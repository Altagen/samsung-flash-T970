#!/bin/bash
# One-shot setup Podman sur SM-T970 depuis le PC via ADB
# Usage: ./scripts/podman/setup-podman.sh [path/to/podman-linux-arm64.tar.gz]
# Assume: kernel CIP flashé, Magisk root, ADB autorisé

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TGZ="${1:-$REPO_ROOT/downloads/podman-linux-arm64.tar.gz}"

# shellcheck source=../lib/fetch.sh
. "$REPO_ROOT/scripts/lib/fetch.sh"
[ -n "${1:-}" ] || fetch_artifact podman-linux-arm64.tar.gz || exit 1
[ -f "$TGZ" ] || { echo "Missing Podman tarball: $TGZ"; exit 1; }

echo "[1/6] Extracting and pushing Podman binaries"
TMP=$(mktemp -d)
tar xzf "$TGZ" -C "$TMP"
SRC="$TMP/podman-linux-arm64/usr/local"

adb shell 'rm -rf /data/local/tmp/podman; mkdir -p /data/local/tmp/podman/bin /data/local/tmp/podman/lib'
adb push "$SRC/bin/." /data/local/tmp/podman/bin/
adb push "$SRC/lib/podman/." /data/local/tmp/podman/lib/
adb shell 'chmod +x /data/local/tmp/podman/bin/* /data/local/tmp/podman/lib/*'
rm -rf "$TMP"

echo "[2/6] Pushing wrapper + helper scripts"
adb push "$SCRIPT_DIR/podman-wrapper.sh" /data/local/tmp/podman/podman-wrapper.sh
adb push "$SCRIPT_DIR/podman-chroot-wrapper.sh" /data/local/tmp/podman/podman-chroot-wrapper.sh
adb push "$REPO_ROOT/scripts/mount-cgroups.sh" /data/local/tmp/mount-cgroups.sh
adb push "$REPO_ROOT/scripts/prepare-rootfs-overrides.sh" /data/local/tmp/prepare-rootfs-overrides.sh
adb shell 'chmod +x /data/local/tmp/podman/podman-wrapper.sh /data/local/tmp/podman/podman-chroot-wrapper.sh /data/local/tmp/mount-cgroups.sh /data/local/tmp/prepare-rootfs-overrides.sh'

echo "[3/6] Pushing configs"
for f in containers.conf storage.conf registries.conf policy.json; do
    adb push "$SCRIPT_DIR/$f" /data/local/tmp/$f
done

echo "[4/6] Pushing CA bundle"
if [ -f /etc/ssl/certs/ca-certificates.crt ]; then
    adb push /etc/ssl/certs/ca-certificates.crt /sdcard/ca-certificates.crt
    adb shell 'su -c "cp /sdcard/ca-certificates.crt /data/local/tmp/ca-certificates.crt"'
else
    echo "WARNING: /etc/ssl/certs/ca-certificates.crt not found on your PC."
fi

echo "[5/6] Setting up /data/podman + /etc/containers"
adb shell 'su -c "
    mkdir -p /data/podman/storage /data/podman/run /data/podman/tmp \
             /data/podman/libpod /data/podman/volumes /data/podman/networks
    chmod 711 /data/podman
    cp /data/local/tmp/containers.conf /data/podman/containers.conf
    cp /data/local/tmp/storage.conf    /data/podman/storage.conf
    cp /data/local/tmp/registries.conf /data/podman/registries.conf
    cp /data/local/tmp/policy.json     /data/podman/policy.json
    mount -o rw,remount /
    mkdir -p /etc/containers
    cp /data/podman/policy.json     /etc/containers/policy.json
    cp /data/podman/registries.conf /etc/containers/registries.conf
    mount -o ro,remount /
"'

echo "[6/6] Installing Magisk boot service + docker-compose symlink"
adb push "$REPO_ROOT/scripts/magisk-service.d/podman-boot.sh" /sdcard/podman-boot.sh
adb shell 'su -c "
    mkdir -p /data/adb/service.d
    cp /sdcard/podman-boot.sh /data/adb/service.d/podman-boot.sh
    chmod +x /data/adb/service.d/podman-boot.sh
    mkdir -p /data/podman/.docker/cli-plugins
    [ -f /data/local/tmp/docker/docker-compose ] && \
        ln -sf /data/local/tmp/docker/docker-compose /data/podman/.docker/cli-plugins/docker-compose
"'

echo ""
echo "Podman setup complete. Test:"
echo "  adb shell -t 'su -c /data/local/tmp/prepare-rootfs-overrides.sh'"
echo "  adb shell -t 'su -c /data/local/tmp/mount-cgroups.sh'"
echo "  adb shell 'su -c \"/data/local/tmp/podman/podman-wrapper.sh run --rm --net=host hello-world\"'"
