#!/system/bin/sh
# Démarre containerd + dockerd sur Android (SM-T970, kernel CIP 4.19)
# Usage (depuis adb shell): su -c /data/local/tmp/start-docker.sh

set -eu

export PATH=/data/local/tmp/docker:/system/bin:/system/xbin:$PATH

/data/local/tmp/mount-cgroups.sh

mkdir -p /data/docker/containerd-state /data/docker/containerd-root \
         /data/docker/run-containerd /data/docker/run-docker

# containerd/dockerd have hardcoded /run/{containerd,docker} paths; bind-mount to writable
mount -o rw,remount / 2>/dev/null || true
mkdir -p /run/containerd /run/docker 2>/dev/null || true
mount -o ro,remount / 2>/dev/null || true
mountpoint -q /run/containerd || mount --bind /data/docker/run-containerd /run/containerd
mountpoint -q /run/docker     || mount --bind /data/docker/run-docker     /run/docker

if pidof dockerd >/dev/null 2>&1; then
    echo "dockerd already running (pid $(pidof dockerd))"
    exit 0
fi

# 1) containerd avec state/root hors /run (read-only sur Android)
nohup /data/local/tmp/docker/containerd \
    --config /data/docker/containerd-config.toml \
    > /data/docker/containerd.log 2>&1 &
CONTAINERD_PID=$!
echo $CONTAINERD_PID > /data/docker/containerd.pid
echo "containerd started, pid=$CONTAINERD_PID"

sleep 2

# 2) dockerd utilise le containerd qu'on vient de lancer
nohup /data/local/tmp/docker/dockerd \
    --config-file=/data/docker/daemon.json \
    -H unix:///data/docker/docker.sock \
    --containerd=/data/docker/containerd.sock \
    --exec-root=/data/docker/run \
    --pidfile=/data/docker/docker.pid \
    > /data/docker/dockerd.log 2>&1 &

echo $! > /data/docker/dockerd.pid
echo "dockerd started, pid=$(cat /data/docker/dockerd.pid)"
echo "Logs: /data/docker/{containerd,dockerd}.log"
echo "Socket: /data/docker/docker.sock"
echo ""
echo "Test: export DOCKER_HOST=unix:///data/docker/docker.sock"
echo "      /data/local/tmp/docker/docker version"
