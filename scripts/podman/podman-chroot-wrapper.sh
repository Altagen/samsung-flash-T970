#!/bin/bash
# Podman wrapper for use inside Ubuntu chroot on SM-T970
# Symlinked to /usr/local/bin/podman by enter-ubuntu.sh
export HOME=/data/podman
export USER=root
export CONTAINERS_CONF=/data/podman/containers.conf
export CONTAINERS_STORAGE_CONF=/data/podman/storage.conf
export CONTAINERS_REGISTRIES_CONF=/data/podman/registries.conf
export CONTAINERS_POLICY=/data/podman/policy.json
export XDG_RUNTIME_DIR=/data/podman/run
export TMPDIR=/data/podman/tmp
exec /data/local/tmp/podman/bin/podman \
    --root=/data/podman/storage \
    --runroot=/data/podman/run \
    --tmpdir=/data/podman/tmp \
    --cgroup-manager=cgroupfs \
    --runtime=/data/local/tmp/podman/bin/crun \
    --conmon=/data/local/tmp/podman/lib/conmon \
    --network-config-dir=/data/podman/networks \
    "$@"
