#!/system/bin/sh
# Wrapper pour podman rootful sur SM-T970 Android
# Usage: su -c /data/local/tmp/podman/podman-wrapper.sh <commande podman>

set -eu

# Bind-mount /run/{lock,containers,netns} to writable storage (hardcoded paths in podman libs)
mount -o rw,remount / 2>/dev/null || true
mkdir -p /run/lock /run/containers /run/netns /run/crun /run/podman 2>/dev/null || true
mount -o ro,remount / 2>/dev/null || true
# tmpfs éphémère (comportement Linux standard pour /run/*) — vidé à chaque boot
mountpoint -q /run/lock       || mount -t tmpfs -o rw,nosuid,nodev tmpfs /run/lock
mountpoint -q /run/containers || mount -t tmpfs -o rw,nosuid,nodev tmpfs /run/containers
mountpoint -q /run/netns      || mount -t tmpfs -o rw,nosuid,nodev tmpfs /run/netns
mountpoint -q /run/crun       || mount -t tmpfs -o rw,nosuid,nodev tmpfs /run/crun
mountpoint -q /run/podman     || mount -t tmpfs -o rw,nosuid,nodev tmpfs /run/podman

# /var/cache hardcodé par containers/image (blob-info-cache)
mkdir -p /data/podman/var-cache
mount -o rw,remount / 2>/dev/null || true
mkdir -p /var/cache 2>/dev/null || true
mount -o ro,remount / 2>/dev/null || true
mountpoint -q /var/cache || mount --bind /data/podman/var-cache /var/cache

# /dev/shm absent sur Android — podman shm_lock_manager en a besoin
if [ ! -d /dev/shm ]; then
    mkdir -p /dev/shm
    mount -t tmpfs -o rw,nosuid,nodev tmpfs /dev/shm
    chmod 1777 /dev/shm
fi

export PATH=/data/local/tmp/podman/bin:/system/bin:/system/xbin:$PATH
export HOME=/data/podman
export USER=root
export CONTAINERS_CONF=/data/podman/containers.conf
export CONTAINERS_STORAGE_CONF=/data/podman/storage.conf
export CONTAINERS_REGISTRIES_CONF=/data/podman/registries.conf
export CONTAINERS_POLICY=/data/podman/policy.json
export XDG_RUNTIME_DIR=/data/podman/run
export TMPDIR=/data/podman/tmp

/data/local/tmp/podman/bin/podman \
    --root=/data/podman/storage \
    --runroot=/data/podman/run \
    --tmpdir=/data/podman/tmp \
    --cgroup-manager=cgroupfs \
    --runtime=/data/local/tmp/podman/bin/crun \
    --conmon=/data/local/tmp/podman/lib/conmon \
    --network-config-dir=/data/podman/networks \
    "$@"
