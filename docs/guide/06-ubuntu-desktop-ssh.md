# Step 6 — Ubuntu, desktop & SSH

[← Step 5: Docker / Podman](05-docker-podman.md) · [Guide overview](../../README.md#step-by-step-guide) · [Step 7: Daily use & maintenance →](07-maintenance.md)

> **Goal:** an Ubuntu 24.04 root shell on the tablet, reachable from ConnectBot
> over SSH, plus an optional XFCE desktop. **Time:** 20 min. **Where:** PC (ADB),
> plus a few taps on the tablet.

```
Android ─ Magisk su
   ├─ Docker / Podman (native, step 5)
   └─ Termux (only for its mount / unshare / X server binaries)
        └─ unshare -m → chroot /data/ubuntu   (Ubuntu 24.04, apt)
             ├─ docker, docker-compose          → talk to the native daemon
             ├─ sshd on 127.0.0.1:2222          (6.2) ← ConnectBot
             └─ XFCE on Termux:X11              (6.3, optional)
```

Every command behind these scripts, the files they put on the tablet, and the
boot sequence are detailed in **[Root shell & SSH](../root-shell-and-ssh.md)**.

## Prerequisites

- [ ] [Step 4](04-flash-kernel.md) done (custom kernel + root) — `adb shell su -c id`
- [ ] Optional: [step 5](05-docker-podman.md), to get `docker` in the shell
- [ ] Tablet **unlocked, screen on, on Wi-Fi** for the whole step (Termux must start in the foreground once, and apt downloads go through the tablet)
- [ ] `ssh` and `ssh-keygen` on the PC — `command -v ssh ssh-keygen`

## 6.1 Ubuntu chroot

### 1. 🖥️ Install

```bash
./setup.sh            # option 4   (same as: scripts/setup-ubuntu.sh)
```

The script runs seven numbered stages:

| Stage | What it does |
|---|---|
| `[1/7]` | Download Termux from F-Droid and `adb install` it |
| `[2/7]` | **📱 Termux opens on the tablet** and bootstraps itself (~30 s). Do not close it |
| `[3/7]` | Install `mount-utils` in Termux, as Termux's UID with the network groups (`su -G 3003 -G 9997`); check for `unshare` |
| `[4/7]` | Download and push the Ubuntu 24.04 base rootfs into `/data/ubuntu`, write a static, immutable `resolv.conf` |
| `[5/7]` | Push `enter-ubuntu.sh` |
| `[6/7]` | `apt update`, block snap, add the Mozilla PPA; install the **root shell config** (coloured `(ubuntu)` prompt, completion, UTF-8: `scripts/setup-shell.sh`) |
| `[7/7]` | Check: prints `PRETTY_NAME="Ubuntu 24.04.x LTS"` |

### 2. 🖥️ Open a shell

```bash
adb shell -t 'su -c /data/local/tmp/enter-ubuntu.sh'
```

```
(ubuntu) root@localhost:/# apt install -y build-essential git
(ubuntu) root@localhost:/# docker ps          # native Docker, if step 5 was done
(ubuntu) root@localhost:/# exit
```

## 6.2 SSH + ConnectBot (recommended daily terminal)

### 1. 🖥️ Install sshd, the key and ConnectBot

```bash
./setup.sh            # option 6   (same as: scripts/setup-ssh.sh [--pubkey ~/.ssh/id_ed25519.pub])
```

| Stage | What it does |
|---|---|
| `[1/8]` | Create (or reuse) the key pair `~/.ssh/sm-t970_ed25519` on the PC |
| `[2/8]` | `apt install openssh-server` in the chroot |
| `[3/8]` | Write `sshd_config`: **127.0.0.1:2222 only** (not reachable from Wi-Fi), keys only, `DOCKER_HOST` for sessions |
| `[4/8]` | Install the public key in `/root/.ssh/authorized_keys`, generate host keys |
| `[5/8]` | Push `start-ssh.sh` + `start-ssh-inner.sh` |
| `[6/8]` | Boot autostart: `/data/adb/service.d/ssh-boot.sh` |
| `[7/8]` | Start sshd and **test a real key login from the PC** |
| `[8/8]` | Install ConnectBot from F-Droid |

A successful run includes:

```
  OK sshd listening on 127.0.0.1:2222
  OK SSH login works: root@Ubuntu 24.04.x LTS DOCKER_HOST=unix:///data/docker/docker.sock
```

### 2. 🖥️ Hand the private key to the tablet

```bash
adb push ~/.ssh/sm-t970_ed25519 /sdcard/Download/sm-t970_ed25519
```

### 3. 📱 Set up ConnectBot

This is the only manual part: ConnectBot keeps its keys in a private database.

1. Open **ConnectBot** › **⋮** › **Manage Pubkeys** › **⋮** › **Import** › pick `Download/sm-t970_ed25519`.
2. Long-press the imported key › tick **Load key on start**.
3. Back on the main screen › **+** › type `root@127.0.0.1:2222` › **Enter**
   (or the ✓ button).
4. Accept the host key fingerprint ("Are you sure you want to continue connecting?" › **Yes**).

You land on `(ubuntu) root@localhost:~#`.

### 4. 🖥️ Remove the key copy from shared storage

```bash
adb shell rm /sdcard/Download/sm-t970_ed25519
```

### Use it from the PC too

```bash
adb forward tcp:22222 tcp:2222
ssh -i ~/.ssh/sm-t970_ed25519 -p 22222 root@127.0.0.1
```

## 6.3 XFCE desktop (optional)

### 1. 🖥️ Install

```bash
./setup.sh            # option 5   (same as: scripts/setup-x11.sh; ~300 MB of apt downloads on the tablet)
```

### 2. 📱 + 🖥️ Start it

1. 📱 Open the **Termux:X11** app (a black screen is normal).
2. 🖥️ `adb shell -t 'su -c /data/local/tmp/start-desktop.sh'`
3. 📱 Switch back to Termux:X11. XFCE appears, scaled for the 2800×1752 screen.

In the desktop:

- **Firefox:** `apt install -y firefox` (a real `.deb` from the Mozilla PPA; the snap does not work in a chroot).
- **Apps that refuse to run as root** (Firefox, Chrome, VS Code): `fake-root firefox`.
- **Desktop environment:** only XFCE. GNOME and Cinnamon (Mutter) render a black
  screen on Termux:X11, see [troubleshooting](../troubleshooting.md#desktop).

## Verify

In a ConnectBot session (or over `ssh` from the PC):

```bash
head -1 /etc/os-release        # PRETTY_NAME="Ubuntu 24.04.x LTS"
echo $0                        # -bash
docker ps                      # the containers from step 5
```

Then 🖥️ `adb reboot`, 📱 unlock the tablet, wait ~10 s, and reconnect from
ConnectBot. It must work with no other action: sshd restarts about 5 s after the
first unlock.

## If it fails

| Problem | Fix |
|---|---|
| `[2/7]` `Termux bootstrap timed out` | The tablet was locked or Termux was closed. Open Termux by hand, wait for the `$` prompt, then re-run the script |
| `[3/7]` `mount-utils installation failed` | No network for Termux: check the tablet's Wi-Fi, then re-run |
| `[7/8]` `sshd is not listening` | `adb shell "su -c 'tail -20 /data/local/tmp/ssh-boot.log'"` |
| `[7/8]` `SSH self-test failed: … Permission denied` | Key mismatch: re-run with `--pubkey ~/.ssh/sm-t970_ed25519.pub` |
| ConnectBot: `Connection refused` | sshd is down. After a reboot: unlock and wait. Otherwise restart it ([commands](../root-shell-and-ssh.md#10-everyday-operations)) |
| ConnectBot: `Permission denied (publickey)` | The key is not imported or not loaded: redo 6.2 action 3 |
| Plain white prompt, no colours | `scripts/setup-shell.sh`, then open a new session |
| `docker: Cannot connect to the Docker daemon` | Docker is not installed (step 5), or the install predates the fix: re-run `scripts/setup-ssh.sh` |

More: [Root shell & SSH › troubleshooting](../root-shell-and-ssh.md#11-troubleshooting).

---

[← Step 5: Docker / Podman](05-docker-podman.md) · [Guide overview](../../README.md#step-by-step-guide) · [Step 7: Daily use & maintenance →](07-maintenance.md)
