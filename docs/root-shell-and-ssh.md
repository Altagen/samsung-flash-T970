# Root shell & SSH, from a flashed tablet to ConnectBot

[README](../README.md) · [Guide](guide/00-before-you-start.md) · [How it works](how-it-works.md) · [Troubleshooting](troubleshooting.md) · **Root shell & SSH** · [Download mirror](mirror.md) · [Histoire (FR)](histoire-du-projet.md)

Summary version: [guide, step 6](guide/06-ubuntu-desktop-ssh.md)

This page covers everything needed to work on the tablet without the PC: a root
shell, an Ubuntu chroot, `sshd` inside it, and ConnectBot as the terminal. Each
step lists the script that does it **and** the raw ADB commands, so you can
redo, check or repair any piece by hand.

```
ConnectBot (Android app, uid u0_aXXX)
   │  TCP 127.0.0.1:2222   (loopback only: invisible from Wi-Fi)
   ▼
sshd  (/usr/sbin/sshd -D, root, inside the chroot)
   │  started by start-ssh.sh: unshare -m → bind mounts → chroot /data/ubuntu
   ▼
(ubuntu) root@localhost:~#   Ubuntu 24.04, bash, apt
   ├─ docker / docker-compose → /data/docker/docker.sock (native dockerd)
   └─ /data = the real Android /data (bind mount)
```

## 0. Starting point

You need [steps 1-4](guide/00-before-you-start.md) done. Check:

```bash
adb devices                      # R52N…   device
adb shell su -c id               # uid=0(root) … context=u:r:magisk:s0
adb shell uname -r               # 4.19.325-cip128-st12+
```

Docker or Podman ([step 5](guide/05-docker-podman.md)) is optional for SSH. It
only matters if you want `docker` in your sessions.

Keep the tablet **unlocked, screen on, on Wi-Fi** during setup: Termux has to
start once in the foreground, and apt downloads go through the tablet's connection.

## The four root shells

| Shell | How | Environment | Use it for |
|---|---|---|---|
| Android root | `adb shell su` | toybox, Android `/` (read-only) | Repairs, logs, `getprop`, flashing helpers |
| Chroot root, from the PC | `adb shell -t 'su -c /data/local/tmp/enter-ubuntu.sh'` | Ubuntu bash, apt | Setup and debugging over USB |
| Chroot root, on the tablet without SSH | Termux › `su -c /data/local/tmp/enter-ubuntu.sh` (Magisk asks to grant Termux once) | Ubuntu bash | Fallback if sshd is down |
| **SSH** | ConnectBot › `root@127.0.0.1:2222`, or from the PC through `adb forward` | Ubuntu bash, `DOCKER_HOST` set | **Daily use** |

## Fast path: two scripts

```bash
scripts/setup-ubuntu.sh          # Termux + Ubuntu chroot + shell config   (= ./setup.sh option 4)
scripts/setup-ssh.sh             # sshd + key + autostart + ConnectBot     (= ./setup.sh option 6)
```

Already installed before the shell config existed? `scripts/setup-shell.sh`
on its own adds the coloured prompt and completion ([details](#shell-configuration)).

`setup-ssh.sh` ends with a self-test, so a run that finishes means sshd is up
and a key login works:

```
[7/8] Start sshd and test the connection
  OK sshd listening on 127.0.0.1:2222
  OK SSH login works: root@Ubuntu 24.04.x LTS DOCKER_HOST=unix:///data/docker/docker.sock
[8/8] ConnectBot app
  OK ConnectBot installed
```

The only manual part left is the [ConnectBot key import (§8)](#8-connectbot). Both
scripts are idempotent: run them again at any time and finished steps are skipped.

Options: `setup-ssh.sh --pubkey ~/.ssh/id_ed25519.pub` (use your own key) and
`--no-connectbot`.

The rest of this page is what those scripts do, command by command.

---

## 1. Termux (provides `mount` and `unshare`)

Android's toybox `mount` cannot do `--make-rprivate`, and the chroot needs it to
get a private mount namespace. Termux provides real `mount` (package
`mount-utils`) and `unshare` (package `util-linux`, already in Termux's bootstrap).

```bash
scripts/fetch-downloads.sh termux_1022.apk          # official F-Droid URL, mirror fallback, SHA-256 checked
adb install downloads/termux_1022.apk
adb shell am start -n com.termux/.app.TermuxActivity       # first launch = bootstrap (~30 s)
adb shell "su -c 'test -f /data/data/com.termux/files/usr/bin/bash && echo bootstrapped'"
```

Termux's apt refuses to run as root, and Android only lets apps whose UID is in
the right groups use the network. So run apt **as Termux's UID** with the inet
(3003) and everybody (9997) groups:

```bash
TUID=$(adb shell su -c 'stat -c %u /data/data/com.termux' | tr -d '\r')
P=/data/data/com.termux/files/usr
adb shell su -c "chown -R $TUID:$TUID $P/var/lib/dpkg $P/var/cache/apt $P/var/log/apt"
adb shell "su -G 3003 -G 9997 $TUID -c 'export PREFIX=$P HOME=/data/data/com.termux/files/home; \
  export TMPDIR=$P/tmp PATH=$P/bin:$P/bin/applets LD_LIBRARY_PATH=$P/lib; \
  apt update; apt install -y mount-utils'"
adb shell su -c "ls -l $P/bin/mount $P/bin/unshare"      # both must exist
```

Install Termux from F-Droid, not from the Play Store: the Play Store build is outdated.

## 2. Ubuntu rootfs in `/data/ubuntu`

`/data/ubuntu` sits outside the per-app encrypted area, so it is readable at boot
and does not depend on Termux.

```bash
scripts/fetch-downloads.sh ubuntu-base-arm64.tar.gz
adb push downloads/ubuntu-base-arm64.tar.gz /data/local/tmp/ubuntu-rootfs.tar.gz
adb shell "su -c 'mkdir -p /data/ubuntu && cd /data/ubuntu && tar xzf /data/local/tmp/ubuntu-rootfs.tar.gz && rm /data/local/tmp/ubuntu-rootfs.tar.gz'"

# DNS: replace the systemd-resolved symlink by a static file, made immutable so no package can swap it back
adb shell "su -c \"rm -f /data/ubuntu/etc/resolv.conf; printf 'nameserver 8.8.8.8\nnameserver 8.8.4.4\n' > /data/ubuntu/etc/resolv.conf; chattr +i /data/ubuntu/etc/resolv.conf\""
```

## 3. `enter-ubuntu.sh`, the chroot entry point

```bash
adb push scripts/enter-ubuntu.sh /data/local/tmp/enter-ubuntu.sh
adb shell su -c 'chmod 755 /data/local/tmp/enter-ubuntu.sh'
adb shell su -c '/data/local/tmp/enter-ubuntu.sh cat /etc/os-release' | head -2   # test
adb shell -t 'su -c /data/local/tmp/enter-ubuntu.sh'                               # interactive
```

What it does, in order (the order matters):

1. `unshare -m`: a new mount namespace, so nothing leaks into Android;
2. `mount --make-rprivate /`, then bind `/data/ubuntu` onto itself;
3. bind `/data` → `/data/ubuntu/data`, **before** the chroot (after it, the path would point to an empty directory);
4. bind `/dev`;
5. `chroot` with `env -i` (Android variables like `BOOTCLASSPATH` break Ubuntu tools);
6. inside: mount `proc`, `sys`, a fresh `devpts`, `tmpfs` on `/dev/shm` and `/run`, and `cgroup2`;
7. link `docker`, `docker-compose` and `podman` into `/usr/local/bin`, and export `DOCKER_HOST`.

Prepare apt once (ubuntu-base lacks `gpgv`):

```bash
adb shell "su -c \"/data/local/tmp/enter-ubuntu.sh bash -c 'apt -o Acquire::AllowInsecureRepositories=true update; apt --allow-unauthenticated install -y gpgv; apt update'\""
```

`setup-ubuntu.sh` also blocks snap and pins the Mozilla PPA (for Firefox). SSH
does not need either.

### Shell configuration

Out of the box, Ubuntu's `/root/.bashrc` colours the prompt only for
`TERM=xterm-color`. ConnectBot announces `xterm-256color` or `screen`, so you
get a plain white `root@localhost:~#`, no completion and a `C` locale. This is
still Ubuntu, just unconfigured. `scripts/setup-shell.sh` (run by
`setup-ubuntu.sh`, or alone on an existing install) fixes it:

```bash
scripts/setup-shell.sh
```

| Piece | Where | Effect |
|---|---|---|
| [`scripts/chroot/sm-t970.bashrc`](../scripts/chroot/sm-t970.bashrc) | `/etc/sm-t970.bashrc` | Prompt `(ubuntu) root@localhost:~#` in colour, `ls`/`grep` colours, `ll`, 10k history, `LANG=C.UTF-8`, `DOCKER_HOST` |
| one line appended to `/root/.bashrc` | `/root/.bashrc` | Sources the file above in every interactive shell (SSH and `enter-ubuntu.sh`) |
| `bash-completion` (apt) | chroot | Tab completion for apt, docker, git… |

Edit `/etc/sm-t970.bashrc` in the chroot to customise it. Personal additions go
in `/root/.bashrc`. Both live in `/data/ubuntu` and survive reboots.

By hand:

```bash
adb push scripts/chroot/sm-t970.bashrc /data/local/tmp/
adb shell "su -c 'mv /data/local/tmp/sm-t970.bashrc /data/ubuntu/etc/ && chmod 644 /data/ubuntu/etc/sm-t970.bashrc'"
adb shell "su -c \"echo '[ -r /etc/sm-t970.bashrc ] && . /etc/sm-t970.bashrc' >> /data/ubuntu/root/.bashrc\""
adb shell "su -c \"/data/local/tmp/enter-ubuntu.sh bash -c 'apt install -y bash-completion'\""
```

## 4. openssh-server

```bash
adb shell "su -c \"/data/local/tmp/enter-ubuntu.sh bash -c 'DEBIAN_FRONTEND=noninteractive apt install -y openssh-server'\""
adb shell su -c 'ls -l /data/ubuntu/usr/sbin/sshd'
```

The post-install script complains that it cannot start the service (there is no
systemd in a chroot). That message is harmless: we start sshd ourselves.

## 5. Key and configuration

**Key pair on the PC.** It is dedicated to the tablet and has no passphrase,
because ConnectBot will hold it:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/sm-t970_ed25519 -N '' -C sm-t970-chroot
```

**`authorized_keys`:**

```bash
adb push ~/.ssh/sm-t970_ed25519.pub /data/local/tmp/ak
adb shell "su -c 'mkdir -p /data/ubuntu/root/.ssh && chmod 700 /data/ubuntu/root/.ssh \
  && mv /data/local/tmp/ak /data/ubuntu/root/.ssh/authorized_keys \
  && chmod 600 /data/ubuntu/root/.ssh/authorized_keys && chown -R 0:0 /data/ubuntu/root/.ssh'"
```

**`/data/ubuntu/etc/ssh/sshd_config`** (exactly what `setup-ssh.sh` writes):

```
Port 2222
ListenAddress 127.0.0.1
PermitRootLogin yes
PasswordAuthentication no
PubkeyAuthentication yes
UsePAM no
SetEnv DOCKER_HOST=unix:///data/docker/docker.sock
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
SyslogFacility AUTH
LogLevel INFO
```

| Line | Why |
|---|---|
| `Port 2222`, `ListenAddress 127.0.0.1` | Only apps on the tablet itself can connect. Nothing is exposed on Wi-Fi |
| `PermitRootLogin yes` + keys only | Single-user device: root is the working account, and passwords are off |
| `UsePAM no` | There is no PAM stack worth having in the chroot. Root's `*` password field does not block key logins |
| `SetEnv DOCKER_HOST=…` | **Required.** sshd does not pass its own environment to sessions, so without this line `docker` looks for `/var/run/docker.sock` and fails |

```bash
adb push sshd_config /data/local/tmp/sshd_config
adb shell "su -c 'mv /data/local/tmp/sshd_config /data/ubuntu/etc/ssh/sshd_config && chmod 644 /data/ubuntu/etc/ssh/sshd_config'"
adb shell "su -c \"/data/local/tmp/enter-ubuntu.sh bash -c 'ssh-keygen -A && sshd -t && echo config OK'\""
```

## 6. Launchers and boot hook

```bash
adb push scripts/start-ssh.sh scripts/start-ssh-inner.sh /data/local/tmp/
adb shell su -c 'chmod 755 /data/local/tmp/start-ssh.sh /data/local/tmp/start-ssh-inner.sh'

adb push scripts/magisk-service.d/ssh-boot.sh /data/local/tmp/ssh-boot.sh
adb shell "su -c 'mkdir -p /data/adb/service.d && mv /data/local/tmp/ssh-boot.sh /data/adb/service.d/ && chmod 755 /data/adb/service.d/ssh-boot.sh'"
```

| Script | Runs | Does |
|---|---|---|
| `start-ssh.sh` | Android side (as root) | Kills any sshd whose root is `/data/ubuntu`, then performs the same namespace and bind sequence as `enter-ubuntu.sh` and chroots into… |
| `start-ssh-inner.sh` | inside the chroot | `umask 0022`, mounts `proc`, `sys`, `devpts`, `/dev/shm`, `/run`, `cgroup2`, creates `/run/sshd` (0755 root), links the docker CLIs, then `exec sshd -D -e` |
| `ssh-boot.sh` | Magisk, at every boot | Waits for `sys.boot_completed`, then for the **first unlock** (Termux's binaries are encrypted until then), then launches `start-ssh.sh` |

## 7. Start and test

Start sshd detached from the adb session. If you run it with `adb shell -t`,
sshd runs in the foreground and dies when you close the terminal.

```bash
adb shell "su -c 'setsid nohup /data/local/tmp/start-ssh.sh >> /data/local/tmp/ssh-boot.log 2>&1 < /dev/null &'"
adb shell su -c 'grep -i ":08AE 00000000:0000 0A" /proc/net/tcp'    # a line = listening on 2222
```

From the PC, through USB:

```bash
adb forward tcp:22222 tcp:2222
ssh -i ~/.ssh/sm-t970_ed25519 -p 22222 root@127.0.0.1
(ubuntu) root@localhost:~# docker ps
```

To save typing, add an entry to `~/.ssh/config`:

```
Host tab
    HostName 127.0.0.1
    Port 22222
    User root
    IdentityFile ~/.ssh/sm-t970_ed25519
```

After that, `adb forward tcp:22222 tcp:2222 && ssh tab` is enough. `scp` and
`sftp` work too.

## 8. ConnectBot

**Install** it (`setup-ssh.sh` does this from F-Droid):

```bash
scripts/fetch-downloads.sh connectbot_11101000.apk
adb install downloads/connectbot_11101000.apk
```

**Import the key.** This is the one step that cannot be scripted: ConnectBot
stores keys as serialized Java objects in its private database.

```bash
adb push ~/.ssh/sm-t970_ed25519 /sdcard/Download/sm-t970_ed25519
```

1. ConnectBot › **⋮ › Manage Pubkeys › ⋮ › Import** › pick `Download/sm-t970_ed25519`.
2. Long-press the imported key › enable **Load key on start**, so it is
   unlocked automatically (the key has no passphrase).
3. Delete the copy: `adb shell rm /sdcard/Download/sm-t970_ed25519`. Shared
   storage is readable by other apps.

**Create the host**: ConnectBot › **+** › type `root@127.0.0.1:2222` (protocol
ssh) › save. On the first connection, accept the host key fingerprint. You land
on `(ubuntu) root@localhost:~#`.

Useful host settings: font size, **Post-login automation** (e.g. `tmux new -A -s main`),
and *Stay connected*. With `apt install tmux`, sessions survive ConnectBot being
killed, and the next connection reattaches.

## 9. What happens at boot

```
boot → Magisk late_start service → service.d/*.sh run in parallel
  docker-boot.sh   sleep 30 → prepare-rootfs-overrides → start-docker      (no unlock needed)
  podman-boot.sh   sleep 30 → overrides, cgroups, restart containers       (no unlock needed)
  ssh-boot.sh      wait boot_completed → wait first unlock → start-ssh.sh
                                                  └─ sshd up ~5 s after you unlock
```

Log: `/data/local/tmp/ssh-boot.log`. sshd's own messages (`-e`) are written
there too.

## 10. Everyday operations

| Task | Command (from the PC; from Android root, drop the `adb shell`) |
|---|---|
| Is sshd up? | `adb shell "su -c 'pidof sshd; tail -5 /data/local/tmp/ssh-boot.log'"` |
| Restart sshd | `adb shell "su -c 'setsid nohup /data/local/tmp/start-ssh.sh >> /data/local/tmp/ssh-boot.log 2>&1 < /dev/null &'"` |
| Stop sshd | `adb shell "su -c 'kill \$(pidof sshd)'"` |
| Disable autostart | `adb shell su -c 'rm /data/adb/service.d/ssh-boot.sh'` |
| Add a key | append it to `/data/ubuntu/root/.ssh/authorized_keys` (or `setup-ssh.sh --pubkey other.pub`, which **replaces** the file) |
| Expose on Wi-Fi | `ListenAddress 0.0.0.0` in `sshd_config`, then restart. Keys only, but think twice |
| Remove SSH | `scripts/uninstall.sh` › SSH (keeps the chroot; the PC key and ConnectBot stay) |

Without a PC, from the tablet: open Termux, run `su`, then any command above
without the `adb shell` wrapper.

## 11. Troubleshooting

**Am I really in Ubuntu?** Run these in the session:

```bash
cat /etc/os-release | head -1     # PRETTY_NAME="Ubuntu 24.04.x LTS"   (Android has no such file)
echo $0 $BASH_VERSION              # -bash 5.2…                         (Android: /system/bin/sh, mksh)
ls /system 2>/dev/null | head -1   # nothing                             (Android: app, bin, etc…)
apt --version; which docker        # apt 2.7.x, /usr/local/bin/docker
```

| Symptom | Check / fix |
|---|---|
| Plain white prompt, no colours, no Tab completion | The shell config is not installed: run `scripts/setup-shell.sh` ([details](#shell-configuration)), then open a new session |
| ConnectBot: `Connection refused` | sshd is down: `pidof sshd`. After a reboot, unlock the tablet and wait ~5 s, then read `ssh-boot.log` |
| Log: `waiting for the first unlock` and nothing after | The tablet has not been unlocked since boot. Unlock it |
| Log: `/run/sshd must be owned by root and not group or world-writable` | Old `start-ssh-inner.sh` without `umask 0022`. Run `setup-ssh.sh` again |
| `Permission denied (publickey)` | Wrong key in ConnectBot, or `authorized_keys` permissions wrong (must be 600, `/root/.ssh` 700, owner root) |
| `Host key verification failed` (PC) | Host keys regenerated (chroot reinstalled): `ssh-keygen -R "[127.0.0.1]:22222"` |
| `Cannot connect to the Docker daemon at unix:///var/run/docker.sock` | `SetEnv DOCKER_HOST` is missing from `sshd_config` (installs before November 2026). Run `setup-ssh.sh` again, or `export DOCKER_HOST=unix:///data/docker/docker.sock` |
| `docker: command not found` | Docker is not installed (step 5), or the symlink is missing: reconnect, since `start-ssh-inner.sh` recreates links when sshd starts. Restart sshd after installing Docker |
| `PTY allocation request failed` | `devpts` not mounted in the chroot namespace. Restart sshd with `start-ssh.sh` |
| No DNS inside the chroot | `cat /etc/resolv.conf`. If it is broken: `chattr -i /data/ubuntu/etc/resolv.conf`, rewrite it, then `chattr +i` |

## Files on the tablet

| Path | From | Role |
|---|---|---|
| `/data/data/com.termux/files/usr/bin/{mount,unshare}` | Termux (`mount-utils`, `util-linux`) | Namespace and propagation tools |
| `/data/ubuntu/` | `ubuntu-base-24.04-arm64` | The chroot |
| `/data/local/tmp/enter-ubuntu.sh` | `scripts/` | Interactive chroot entry |
| `/data/local/tmp/start-ssh.sh`, `start-ssh-inner.sh` | `scripts/` | sshd launcher (outer, inner) |
| `/data/adb/service.d/ssh-boot.sh` | `scripts/magisk-service.d/` | Boot autostart |
| `/data/ubuntu/etc/ssh/sshd_config` | generated by `setup-ssh.sh` | Port 2222, loopback, keys only, `DOCKER_HOST` |
| `/data/ubuntu/etc/ssh/ssh_host_*` | `ssh-keygen -A` | Host keys |
| `/data/ubuntu/root/.ssh/authorized_keys` | `~/.ssh/sm-t970_ed25519.pub` | Allowed key |
| `/data/ubuntu/etc/sm-t970.bashrc` + last line of `/data/ubuntu/root/.bashrc` | `scripts/chroot/sm-t970.bashrc` via `setup-shell.sh` | Prompt, colours, completion, env |
| `/data/local/tmp/ssh-boot.log` | `ssh-boot.sh`, sshd `-e` | Log |

## Known gap

`podman` in the chroot links to `podman-chroot-wrapper.sh`, which runs the
Podman binary **inside** the chroot. Nothing beyond "it is on the PATH" was
validated there, and `podman run` from a chroot is expected to hit the kernel's
`remount /` restriction ([why](how-it-works.md#why-not-a-chroot-for-the-runtimes)). For Podman containers, use the native wrapper from Android
root (`/data/local/tmp/podman/podman-wrapper.sh run …`), or use Docker from SSH.

---

[README](../README.md) · [Guide](guide/00-before-you-start.md) · [How it works](how-it-works.md) · [Troubleshooting](troubleshooting.md) · **Root shell & SSH** · [Download mirror](mirror.md) · [Histoire (FR)](histoire-du-projet.md)
