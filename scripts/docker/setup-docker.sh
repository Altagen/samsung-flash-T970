#!/bin/bash
# One-shot setup Docker sur SM-T970 depuis le PC via ADB
# Usage: ./scripts/docker/setup-docker.sh [path/to/docker-27.3.1.tgz]
# Assume: tablette connectée, ADB autorisé, Magisk root actif, kernel CIP flashé

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TGZ="${1:-$REPO_ROOT/downloads/docker-27.3.1.tgz}"
COMPOSE="${REPO_ROOT}/downloads/docker-compose-arm64"

# shellcheck source=../lib/fetch.sh
. "$REPO_ROOT/scripts/lib/fetch.sh"
if [ -z "${1:-}" ]; then
    fetch_artifact docker-27.3.1.tgz || exit 1
    fetch_artifact docker-compose-arm64 || echo "  (docker-compose unavailable, continuing without it)"
fi
[ -f "$TGZ" ] || { echo "Missing Docker tarball: $TGZ"; exit 1; }

echo "[1/7] Pushing Docker binaries to /data/local/tmp/docker/"
adb shell 'rm -rf /data/local/tmp/docker ; mkdir -p /data/local/tmp/docker'
TMP=$(mktemp -d)
tar xzf "$TGZ" -C "$TMP"
adb push "$TMP/docker/." /data/local/tmp/docker/
rm -rf "$TMP"
adb shell 'chmod +x /data/local/tmp/docker/*'

if [ -f "$COMPOSE" ]; then
    echo "[2/7] Pushing docker-compose"
    chmod +x "$COMPOSE"
    adb push "$COMPOSE" /data/local/tmp/docker/docker-compose
    adb shell 'chmod +x /data/local/tmp/docker/docker-compose'
else
    echo "[2/7] Skipping docker-compose (not found at $COMPOSE; scripts/fetch-downloads.sh docker-compose-arm64)"
fi

echo "[3/7] Pushing helper scripts"
adb push "$REPO_ROOT/scripts/mount-cgroups.sh" /data/local/tmp/mount-cgroups.sh
adb push "$SCRIPT_DIR/start-docker.sh" /data/local/tmp/start-docker.sh
adb push "$REPO_ROOT/scripts/prepare-rootfs-overrides.sh" /data/local/tmp/prepare-rootfs-overrides.sh
adb shell 'chmod +x /data/local/tmp/mount-cgroups.sh /data/local/tmp/start-docker.sh /data/local/tmp/prepare-rootfs-overrides.sh'

echo "[4/7] Pushing configs"
adb push "$SCRIPT_DIR/daemon.json" /data/local/tmp/daemon.json
adb push "$SCRIPT_DIR/containerd-config.toml" /data/local/tmp/containerd-config.toml

echo "[5/7] Pushing CA bundle"
if [ -f /etc/ssl/certs/ca-certificates.crt ]; then
    adb push /etc/ssl/certs/ca-certificates.crt /sdcard/ca-certificates.crt
    adb shell 'su -c "cp /sdcard/ca-certificates.crt /data/local/tmp/ca-certificates.crt"'
else
    echo "WARNING: /etc/ssl/certs/ca-certificates.crt not found on your PC."
    echo "         Docker won't be able to pull images over HTTPS."
fi

echo "[6/7] Setting up /data/docker"
adb shell 'su -c "
    mkdir -p /data/docker
    cp /data/local/tmp/daemon.json /data/docker/daemon.json
    cp /data/local/tmp/containerd-config.toml /data/docker/containerd-config.toml
    chmod 711 /data/docker
"'

echo "[7/7] Installing Magisk boot service"
adb push "$REPO_ROOT/scripts/magisk-service.d/docker-boot.sh" /sdcard/docker-boot.sh
adb shell 'su -c "
    mkdir -p /data/adb/service.d
    cp /sdcard/docker-boot.sh /data/adb/service.d/docker-boot.sh
    chmod +x /data/adb/service.d/docker-boot.sh
"'

echo ""
echo "Docker setup complete. Test:"
echo "  adb shell -t 'su -c /data/local/tmp/prepare-rootfs-overrides.sh'"
echo "  adb shell -t 'su -c /data/local/tmp/start-docker.sh'"
echo "  sleep 5"
echo "  adb shell 'su -c \"/data/local/tmp/docker/docker -H unix:///data/docker/docker.sock run --rm --net=host hello-world\"'"
