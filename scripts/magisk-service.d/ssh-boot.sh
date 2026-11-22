#!/system/bin/sh
# Magisk service.d — autostart sshd (inside Ubuntu chroot) at boot
# Installed at /data/adb/service.d/ssh-boot.sh (late_start_service, root)
#
# start-ssh.sh uses Termux's mount/unshare, which live in /data/data/com.termux.
# That directory is credential-encrypted: it only becomes readable after the
# first unlock (PIN/pattern) following a reboot. So wait for the boot to
# complete AND for those binaries to be reachable, instead of a fixed delay.

LOG=/data/local/tmp/ssh-boot.log
UNSHARE=/data/data/com.termux/files/usr/bin/unshare

{
    echo "=== $(date) ssh-boot.sh start ==="

    until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done

    n=0
    until [ -x "$UNSHARE" ]; do
        [ $n -eq 0 ] && echo "waiting for the first unlock (Termux binaries are encrypted until then)"
        n=$((n + 1))
        [ $n -ge 720 ] && { echo "gave up after 1h: $UNSHARE not reachable"; exit 1; }
        sleep 5
    done

    sleep 5
    /data/local/tmp/start-ssh.sh &
    echo "sshd launched (PID chain backgrounded)"
    echo "=== $(date) ssh-boot.sh done ==="
} >> "$LOG" 2>&1
