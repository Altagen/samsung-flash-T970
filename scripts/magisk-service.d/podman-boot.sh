#!/system/bin/sh
# Magisk service.d — prépare Podman au boot + restart conteneurs auto-restart
# Podman est daemonless : pas de service à lancer, juste préparer l'environnement
# et relancer les conteneurs marqués --restart=always|unless-stopped

sleep 30

LOG=/data/podman/boot.log
{
    echo "=== $(date) podman-boot.sh start ==="

    # 1) Infrastructure partagée : rootfs overrides + cgroups (si docker-boot ne l'a pas fait)
    /data/local/tmp/prepare-rootfs-overrides.sh || true
    /data/local/tmp/mount-cgroups.sh || true

    # runroot et tmpdir sont censés être tmpfs (vidés au boot) ; sur Android ils sont
    # persistants dans /data → nettoyage manuel pour éviter "boot ID mismatch"
    rm -rf /data/podman/run/* /data/podman/tmp/* 2>/dev/null || true

    # 2) Préparation des mounts podman via le wrapper (idempotent, commande no-op)
    /data/local/tmp/podman/podman-wrapper.sh info --format '{{.Host.OS}}' || true

    # 3) Restart des conteneurs à politique auto-restart
    /data/local/tmp/podman/podman-wrapper.sh start --all --filter restart-policy=always
    /data/local/tmp/podman/podman-wrapper.sh start --all --filter restart-policy=unless-stopped

    echo "=== $(date) podman-boot.sh done ==="
} >> "$LOG" 2>&1
