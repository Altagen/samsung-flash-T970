#!/system/bin/sh
# Magisk service.d — autostart Docker daemon on boot
# Installed at /data/adb/service.d/docker-boot.sh (exécuté en late-boot, root, après décrypt /data)

# Attente : late_start_service → /data déjà monté, mais laisser au kernel le temps de finir le boot
sleep 30

LOG=/data/docker/boot.log
{
    echo "=== $(date) docker-boot.sh start ==="
    /data/local/tmp/prepare-rootfs-overrides.sh
    /data/local/tmp/start-docker.sh
    echo "=== $(date) docker-boot.sh done ==="
} >> "$LOG" 2>&1
