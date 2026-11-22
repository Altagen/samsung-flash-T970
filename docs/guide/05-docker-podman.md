# Step 5 — Install Docker and/or Podman

[← Step 4: Flash the kernel](04-flash-kernel.md) · [Guide overview](../../README.md#step-by-step-guide) · [Step 6: Ubuntu, desktop & SSH →](06-ubuntu-desktop-ssh.md)

> **Goal:** native Docker and/or Podman on Android, restarted at every boot.
> **Time:** 5 min. **Where:** PC only (over ADB). You never type a command on the tablet.

## Prerequisites

- [ ] [Step 4](04-flash-kernel.md) done — `adb shell uname -r` prints `4.19.325-cip128-st12+`
- [ ] Root over ADB — `adb shell su -c id` prints `uid=0(root)`
- [ ] Tablet on Wi-Fi (image pulls) — `adb shell ping -c1 -W3 1.1.1.1`
- [ ] Binaries in `downloads/` (step 0; the installers fetch them otherwise) — `sha256sum -c --ignore-missing SHA256SUMS | grep -E 'docker|podman'`
- [ ] A CA bundle on the PC, pushed to the tablet for TLS — `ls /etc/ssl/certs/ca-certificates.crt` (Fedora: `/etc/pki/tls/certs/ca-bundle.crt`, copy it to that path first)

## Actions

### 1. 🖥️ Run the installer

```bash
./setup.sh
```

```
Checking prerequisites...
  * ADB connected
  * Magisk root active
  * Custom kernel detected
…
  1) Docker only
  2) Podman only
  3) Docker + Podman (both)
  4) Ubuntu dev environment (Termux + Ubuntu chroot)
  5) X11 graphical desktop (requires Ubuntu)
  6) SSH server in chroot (for ConnectBot/JuiceSSH — requires Ubuntu)
  7) Everything (Docker + Podman + Ubuntu + X11 + SSH)
  u) Uninstall components
  Choice [1-7/u]:
```

Type **3** (or 1 / 2). For each runtime, the installer:

1. fetches the binaries if `downloads/` lacks them (official URL, mirror fallback, SHA-256 checked), then pushes them to `/data/local/tmp/{docker,podman}/`;
2. pushes the configs, the wrappers and the PC's CA bundle;
3. installs the boot hook in `/data/adb/service.d/`;
4. rebuilds `/etc/resolv.conf` and the CA bundle, starts dockerd, and runs `hello-world`.

It ends with:

```
  * Docker: hello-world OK
  * Podman: hello-world OK
```

Components already installed are skipped, so it is safe to run again. The
installers also work on their own: `scripts/docker/setup-docker.sh` and
`scripts/podman/setup-podman.sh`.

### 2. 🖥️ Run a real container

Networking is **host mode only**: there is no Docker bridge on Android
(`"bridge": "none"`), so `-p` port mappings do not work. A container listens
directly on the tablet's ports.

```bash
D='/data/local/tmp/docker/docker -H unix:///data/docker/docker.sock'
adb shell "su -c '$D run -d --name web --net=host --restart=always nginx:alpine'"

adb forward tcp:8080 tcp:80        # PC:8080 → tablet:80
curl -s localhost:8080 | grep -o '<title>.*</title>'      # <title>Welcome to nginx!</title>
```

Podman, through its wrapper (it sets the paths Android lacks):

```bash
P=/data/local/tmp/podman/podman-wrapper.sh
adb shell "su -c '$P run -d --name whoami --net=host --restart=always docker.io/traefik/whoami --port 8081'"
adb forward tcp:8081 tcp:8081 && curl -s localhost:8081 | head -2
```

Compose works with both runtimes (they share the `docker-compose` binary). Use
`network_mode: host`:

```bash
cat > /tmp/compose.yaml <<'EOF'
services:
  whoami:
    image: docker.io/traefik/whoami
    command: ["--port", "9091"]
    network_mode: host
    restart: unless-stopped
EOF
adb shell "su -c 'mkdir -p /data/local/tmp/demo'" && adb push /tmp/compose.yaml /data/local/tmp/demo/
adb shell "su -c 'cd /data/local/tmp/demo && DOCKER_HOST=unix:///data/docker/docker.sock /data/local/tmp/docker/docker-compose up -d'"
```

These commands are long because Android has no `/var/run/docker.sock` and no
`/etc/containers`. For daily use, the Ubuntu shell and SSH from
[step 6](06-ubuntu-desktop-ssh.md) give you plain `docker` and `docker-compose`.

### 3. 🖥️ Reboot test

```bash
adb reboot
# wait for the lock screen, then ~1 min (the boot hooks wait 30 s)
adb shell "su -c '/data/local/tmp/docker/docker -H unix:///data/docker/docker.sock ps'"
```

At each boot, the hooks rebuild the files Android loses (`/etc/resolv.conf`, CA
bundle, `/etc/containers/*`), mount the cgroup v1 hierarchies, start
`containerd` + `dockerd`, clean Podman's stale run state, and restart the
containers that have `--restart=always` / `unless-stopped`. None of this needs
the tablet to be unlocked.

## Verify

```bash
adb shell "su -c '/data/local/tmp/docker/docker -H unix:///data/docker/docker.sock run --rm --net=host hello-world'" | grep 'Hello from Docker'
adb shell "su -c '/data/local/tmp/podman/podman-wrapper.sh run --rm --net=host hello-world'" | grep 'Hello from Docker'
adb shell "su -c 'ls /data/adb/service.d/'"        # docker-boot.sh  podman-boot.sh
```

After a reboot, `docker ps` lists `web` as `Up`.

Data lives in `/data/docker` and `/data/podman`, outside Termux and outside the
per-app encrypted area ([why](../how-it-works.md#where-things-live)).

## If it fails

| Problem | Fix |
|---|---|
| `Custom kernel detected` is a WARNING | The stock kernel is running. Check `adb shell uname -r` and redo step 4 |
| `Docker hello-world failed` | `adb shell "su -c 'cat /data/docker/dockerd.log'"`. Most often DNS or certificates: `adb shell "su -c /data/local/tmp/prepare-rootfs-overrides.sh"` |
| `x509: certificate signed by unknown authority` | No CA bundle was pushed. Fix the prerequisite, then re-run the installer |
| `controller pids is not available` (Podman) | Old `containers.conf`: re-run `scripts/podman/setup-podman.sh` |
| `-p` / `ports:` → error about the network or bridge | Expected: use `--net=host` / `network_mode: host` |
| Containers not back after reboot | `adb shell "su -c 'cat /data/docker/boot.log /data/podman/boot.log'"`. Did you use `--restart=always`? |
| Warnings `No memory limit support`… | Expected: no cgroup limits on Android ([why](../how-it-works.md#why-no-cgroup-limits)) |

More: [troubleshooting › Docker & Podman](../troubleshooting.md#docker--podman).

---

[← Step 4: Flash the kernel](04-flash-kernel.md) · [Guide overview](../../README.md#step-by-step-guide) · [Step 6: Ubuntu, desktop & SSH →](06-ubuntu-desktop-ssh.md)
