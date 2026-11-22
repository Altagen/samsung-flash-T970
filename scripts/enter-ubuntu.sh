#!/system/bin/sh
# Enter Ubuntu chroot with isolated mount namespace
# Usage:  su -c /data/local/tmp/enter-ubuntu.sh              (interactive shell)
#         su -c "/data/local/tmp/enter-ubuntu.sh CMD ARGS"    (run command)

UBUNTU=/data/ubuntu
MOUNT=/data/data/com.termux/files/usr/bin/mount
UNSHARE=/data/data/com.termux/files/usr/bin/unshare

# Save command to run (if any) to a temp file so it survives exec+unshare
if [ $# -gt 0 ]; then
    CMD_FILE=/data/local/tmp/ubuntu-cmd.tmp
    # Preserve arguments exactly as passed
    printf '%s\n' "$*" > "$CMD_FILE"
else
    CMD_FILE=""
fi

exec "$UNSHARE" -m /system/bin/sh -c "
  $MOUNT --make-rprivate /
  $MOUNT --bind $UBUNTU $UBUNTU
  $MOUNT --make-rprivate $UBUNTU
  mkdir -p $UBUNTU/data
  $MOUNT --bind /data $UBUNTU/data
  $MOUNT --bind /dev $UBUNTU/dev
  chroot $UBUNTU /usr/bin/env -i PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin TERM=xterm-256color HOME=/root USER=root /bin/bash -c '

    mountpoint -q /proc          || mount -t proc proc /proc
    mountpoint -q /sys           || mount -t sysfs sys /sys
    mkdir -p /dev/pts /dev/shm /run /sys/fs/cgroup
    mountpoint -q /dev/pts       || mount -t devpts -o newinstance,ptmxmode=0666,mode=0620,gid=5 devpts /dev/pts
    [ -e /dev/ptmx ] || ln -sf /dev/pts/ptmx /dev/ptmx
    mountpoint -q /dev/shm       || mount -t tmpfs tmpfs /dev/shm
    mountpoint -q /run           || mount -t tmpfs tmpfs /run
    mountpoint -q /sys/fs/cgroup || mount -t cgroup2 cgroup2 /sys/fs/cgroup

    # Docker/Podman CLI
    mkdir -p /usr/local/bin
    [ -f /data/local/tmp/docker/docker ] && ln -sf /data/local/tmp/docker/docker /usr/local/bin/docker 2>/dev/null
    [ -f /data/local/tmp/docker/docker-compose ] && ln -sf /data/local/tmp/docker/docker-compose /usr/local/bin/docker-compose 2>/dev/null
    [ -f /data/local/tmp/podman/podman-chroot-wrapper.sh ] && ln -sf /data/local/tmp/podman/podman-chroot-wrapper.sh /usr/local/bin/podman 2>/dev/null
    export DOCKER_HOST=unix:///data/docker/docker.sock

    if [ -f /data/local/tmp/ubuntu-cmd.tmp ]; then
      cp /data/local/tmp/ubuntu-cmd.tmp /tmp/ubuntu-cmd.sh
      rm -f /data/local/tmp/ubuntu-cmd.tmp
      chmod +x /tmp/ubuntu-cmd.sh
      exec /bin/bash /tmp/ubuntu-cmd.sh
    else
      exec /bin/bash
    fi
  '
"
