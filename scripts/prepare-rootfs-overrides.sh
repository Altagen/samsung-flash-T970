#!/system/bin/sh
# Recrée les fichiers /etc/* nécessaires aux runtimes conteneur après chaque boot
# (rootfs Android est ro, ces fichiers sont perdus au reboot)
# Sources : copiés depuis /data/local/tmp/ au setup initial

set -u

mount -o rw,remount /

# DNS resolver
mkdir -p /etc
cat > /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF

# CA bundle (nécessaire pour pull d'images HTTPS)
mkdir -p /etc/ssl/certs
[ -f /data/local/tmp/ca-certificates.crt ] && \
    cp /data/local/tmp/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

# Configs containers/ (policy.json + registries.conf — chemins hardcodés dans libs Go)
mkdir -p /etc/containers
[ -f /data/podman/policy.json ]     && cp /data/podman/policy.json     /etc/containers/policy.json
[ -f /data/podman/registries.conf ] && cp /data/podman/registries.conf /etc/containers/registries.conf

# Points de montage nécessaires aux bind-mounts ultérieurs
mkdir -p /run/lock /run/containers /run/netns /run/crun /run/containerd /run/docker /var/cache

mount -o ro,remount /

echo "rootfs overrides prepared at $(date)"
