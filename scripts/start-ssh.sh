#!/system/bin/sh
# Start sshd in Ubuntu chroot for remote shell access from Android SSH clients
# (ConnectBot, JuiceSSH, etc.) — avoids using Termux as a daily terminal
# Idempotent: kills stale sshd, starts fresh
# Usage: su -c /data/local/tmp/start-ssh.sh

UBUNTU=/data/ubuntu
MOUNT=/data/data/com.termux/files/usr/bin/mount
UNSHARE=/data/data/com.termux/files/usr/bin/unshare

# --- Cleanup stale sshd (inside chroot only) ---
for pid in $(pidof sshd 2>/dev/null); do
    root=$(readlink /proc/$pid/root 2>/dev/null)
    case "$root" in
        "$UBUNTU"*) kill "$pid" 2>/dev/null ;;
    esac
done
sleep 1

# --- Enter chroot and launch sshd ---
exec $UNSHARE -m /system/bin/sh -c "
  $MOUNT --make-rprivate /
  $MOUNT --bind $UBUNTU $UBUNTU
  $MOUNT --make-rprivate $UBUNTU
  mkdir -p $UBUNTU/data
  $MOUNT --bind /data $UBUNTU/data
  $MOUNT --bind /dev $UBUNTU/dev
  chroot $UBUNTU /bin/bash /data/local/tmp/start-ssh-inner.sh
"
