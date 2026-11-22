#!/bin/bash
# Inner script — runs inside Ubuntu chroot
# Called by start-ssh.sh, not directly

umask 0022
export PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root
export USER=root

mountpoint -q /proc          || mount -t proc proc /proc
mountpoint -q /sys           || mount -t sysfs sys /sys
mkdir -p /dev/pts /dev/shm /run /sys/fs/cgroup
mountpoint -q /dev/pts       || mount -t devpts -o newinstance,ptmxmode=0666,mode=0620,gid=5 devpts /dev/pts
[ -e /dev/ptmx ] || ln -sf /dev/pts/ptmx /dev/ptmx
mountpoint -q /dev/shm       || mount -t tmpfs tmpfs /dev/shm
mountpoint -q /run           || mount -t tmpfs tmpfs /run
mkdir -p /run/sshd
chown 0:0 /run/sshd
chmod 0755 /run/sshd
mountpoint -q /sys/fs/cgroup || mount -t cgroup2 cgroup2 /sys/fs/cgroup

# Docker/Podman CLI symlinks (so SSH sessions have them)
mkdir -p /usr/local/bin
[ -f /data/local/tmp/docker/docker ] && ln -sf /data/local/tmp/docker/docker /usr/local/bin/docker 2>/dev/null
[ -f /data/local/tmp/docker/docker-compose ] && ln -sf /data/local/tmp/docker/docker-compose /usr/local/bin/docker-compose 2>/dev/null
[ -f /data/local/tmp/podman/podman-chroot-wrapper.sh ] && ln -sf /data/local/tmp/podman/podman-chroot-wrapper.sh /usr/local/bin/podman 2>/dev/null
export DOCKER_HOST=unix:///data/docker/docker.sock

exec /usr/sbin/sshd -D -e
