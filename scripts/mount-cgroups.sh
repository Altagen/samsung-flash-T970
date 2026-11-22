#!/system/bin/sh
# Monte cgroups v1 controllers pour Docker/Podman sur Android (SM-T970, kernel CIP 4.19)
# Réf: project_container_configs.md — inclut schedtune (contrôleur Samsung EAS)
# Usage depuis adb su ou Magisk service.d: /data/local/tmp/mount-cgroups.sh

set -eu

if ! mountpoint -q /sys/fs/cgroup; then
    mount -t tmpfs -o rw,nosuid,nodev,noexec,relatime tmpfs /sys/fs/cgroup
fi

for ctrl in blkio cpu cpuacct cpuset devices freezer memory pids schedtune; do
    mkdir -p /sys/fs/cgroup/$ctrl
    if ! mountpoint -q /sys/fs/cgroup/$ctrl; then
        mount -t cgroup -o $ctrl cgroup /sys/fs/cgroup/$ctrl 2>/dev/null || \
            echo "cgroup $ctrl: mount failed (may be unsupported on this kernel, continuing)"
    fi
done

echo "cgroups mounted:"
mount | grep '^cgroup'
