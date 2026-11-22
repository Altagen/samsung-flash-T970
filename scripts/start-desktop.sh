#!/system/bin/sh
# Start desktop in Ubuntu chroot via Termux:X11
# Idempotent: kills stale sessions, starts X server if needed
# Usage (from Termux): su -c /data/local/tmp/start-desktop.sh
# Requires: Termux:X11 app installed on tablet

UBUNTU=/data/ubuntu
MOUNT=/data/data/com.termux/files/usr/bin/mount
UNSHARE=/data/data/com.termux/files/usr/bin/unshare
TERMUX_PREFIX=/data/data/com.termux/files/usr
TERMUX_X11=$TERMUX_PREFIX/bin/termux-x11

# --- Cleanup stale desktop session (if any) ---
for proc in xfce4-session xfwm4 xfdesktop xfce4-panel cinnamon cinnamon-session; do
    killall "$proc" 2>/dev/null
done
pkill -f "socat.*X11-unix" 2>/dev/null

# --- X11 server: start or reuse ---
if cat /proc/net/unix 2>/dev/null | grep -q "@.*termux.*X11-unix/X0"; then
    echo "X11 server already running, reusing."
else
    echo "Starting X11 server..."
    pkill -f "com.termux.x11.Loader" 2>/dev/null
    sleep 1
    $TERMUX_X11 :0 &
    X11_PID=$!
    n=0
    while [ $n -lt 50 ]; do
        if cat /proc/net/unix 2>/dev/null | grep -q "@.*termux.*X11-unix/X0"; then
            break
        fi
        sleep 0.1
        n=$((n + 1))
    done
    if ! cat /proc/net/unix 2>/dev/null | grep -q "@.*termux.*X11-unix/X0"; then
        echo "ERROR: X11 server failed to start. Open the Termux:X11 app and retry."
        exit 1
    fi
    echo "X11 server started (PID $X11_PID)."
fi

# --- Enter chroot and launch desktop ---
exec $UNSHARE -m /system/bin/sh -c "
  $MOUNT --make-rprivate /
  $MOUNT --bind $UBUNTU $UBUNTU
  $MOUNT --make-rprivate $UBUNTU
  mkdir -p $UBUNTU/data
  $MOUNT --bind /data $UBUNTU/data
  $MOUNT --bind /dev $UBUNTU/dev
  chroot $UBUNTU /bin/bash /data/local/tmp/start-desktop-inner.sh
"
