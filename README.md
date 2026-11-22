# Docker & Podman on a Galaxy Tab S7+ (SM-T970)

[Guide: start here](docs/guide/00-before-you-start.md) · [How it works](docs/how-it-works.md) · [Troubleshooting](docs/troubleshooting.md) · [Root shell & SSH](docs/root-shell-and-ssh.md) · [Download mirror](docs/mirror.md) · [Histoire (FR)](docs/histoire-du-projet.md) · [Dossier de recherche (FR)](docs/research/README.md)

**Real Linux containers on a stock Android tablet.** This project turns a
Samsung Galaxy Tab S7+ into a small Linux workstation that runs Docker and
Podman locally, while Android 13, the S Pen, 120 Hz, Wi-Fi and Bluetooth keep
working exactly as before.

## Why

A tablet with a Snapdragon 865, 6-8 GB of RAM and a keyboard cover is a decent
machine for development, but out of the box it cannot run containers. The
usual workaround is to work remotely: a VPN to a server at home, plus SSH or a
remote desktop. This project takes the other path and runs the containers **on
the tablet itself**.

The blocker is the **kernel**, the core of the system. Its default configuration
for this tablet leaves off several features containers rely on (user, PID and
network namespaces, the `pids` cgroup, IPVS…). The code is there, it is just not
compiled in. So the main job is to build a kernel with those features turned on, get the tablet
to boot it without breaking anything, then adapt Docker and Podman to Android,
which is Linux underneath but very different from a regular distribution.

## What you end up with

- Android 13 / One UI exactly as before, on the stock Samsung system, with root (Magisk).
- **Docker** and/or **Podman**, with `docker compose`, running natively and restarted at every boot.
- Optionally, an **Ubuntu 24.04** environment with `apt`, reachable over **SSH** from a terminal app on the tablet (ConnectBot), and an **XFCE desktop**.
- Everything installed from a Linux PC with scripts, over USB.

| | |
|---|---|
| **Device** | Samsung Galaxy Tab S7+ Wi-Fi, SM-T970 (Snapdragon 865 / SM8250 "kona") |
| **Firmware** | T970XXS7DXH1, Android 13 / One UI 5.1.1 |
| **Kernel** | LineageOS [`android_kernel_samsung_sm8250`](https://github.com/LineageOS/android_kernel_samsung_sm8250) (Samsung kernel + CIP 4.19.325), pinned commit, + 1 patch + container `.config` |
| **Runtimes** | Docker 27.3.1 + compose 2.32.4 · Podman 5.8.1 + `podman compose` |
| **Extras** | Ubuntu 24.04 chroot · SSH into it (ConnectBot) · XFCE desktop (Termux:X11) |
| **Status** | Done and validated (April 2026): multi-reboot persistence, auto-start via Magisk |

> [!WARNING]
> Unlocking the bootloader **permanently trips Knox**, Samsung's warranty and
> security fuse (warranty void; Samsung Pay and Secure Folder stop working), and
> wipes the tablet. Everything here is at your own risk.

## How it works, in one minute

1. **Unlock the bootloader** so the tablet accepts software Samsung did not sign.
2. **Get root** with Magisk, which also lets us run scripts at every boot.
3. **Replace only the kernel.** We build a kernel with the container features,
   put it inside Samsung's own boot image in place of the original, and flash
   it. Everything else in the boot image stays byte-identical to stock, which is
   the main reason Android keeps working.
4. **Run Docker and Podman directly on Android**, with scripts that recreate the
   files and directories a regular Linux system has and Android lacks.

```
 Linux PC                                Galaxy Tab S7+
 ────────                                ─────────────────────────────────────────────
 build the kernel (in a container)  ─┐   boot partition
 assemble the boot image             ├─USB─▶  └─ our kernel + Magisk (root)
 install everything over adb        ─┘           ├─ Docker / Podman     data in /data
                                                 ├─ boot scripts        auto-start
                                                 └─ Ubuntu (optional)   apt, SSH, XFCE
```

The details, and a glossary of the acronyms, are in [How it works](docs/how-it-works.md).

## Step-by-step guide

Follow the steps in order. Each one lists its prerequisites, the exact commands
to type on the PC, what to do on the tablet, and how to check the result.
Total: about 1 h 30 the first time.

| # | Step | Where | Time |
|---|------|-------|------|
| 0 | [Before you start](docs/guide/00-before-you-start.md): tools, downloads, checks | PC | 15 min |
| 1 | [Unlock the bootloader](docs/guide/01-unlock-bootloader.md) | Tablet | 15 min |
| 2 | [Root with TWRP + Magisk](docs/guide/02-root-twrp-magisk.md) | Both | 20 min |
| 3 | [Build the kernel](docs/guide/03-build-kernel.md) | PC | 10-30 min |
| 4 | [Flash the kernel](docs/guide/04-flash-kernel.md) | Both | 15 min |
| 5 | [Install Docker / Podman](docs/guide/05-docker-podman.md) | PC (adb) | 5 min |
| 6 | [Ubuntu, desktop & SSH](docs/guide/06-ubuntu-desktop-ssh.md) (optional) | PC (adb) | 20 min |
| 7 | [Daily use & maintenance](docs/guide/07-maintenance.md): update, uninstall, back to stock | Both | — |

Already rooted with the custom kernel? Go straight to [step 5](docs/guide/05-docker-podman.md).

### What it looks like at the end

From ConnectBot on the tablet (or over SSH from the PC):

```console
(ubuntu) root@localhost:~# docker run --rm --net=host hello-world
Hello from Docker!
(ubuntu) root@localhost:~# apt install -y build-essential
```

## Documentation

- [How it works](docs/how-it-works.md): boot image anatomy, what the kernel patch does,
  the "Android-ification" of OCI runtimes, why there are no cgroup limits.
- [Root shell & SSH](docs/root-shell-and-ssh.md): every ADB command behind the chroot,
  sshd and ConnectBot, so you can rebuild or repair the setup by hand.
- [Troubleshooting](docs/troubleshooting.md): every failure we hit, with the fix.
- [Download mirror](docs/mirror.md): every pinned third-party file, its official source,
  license, checksum, and the backup copy attached to the `v1.0.0` release.
- [Histoire du projet](docs/histoire-du-projet.md) (FR): the full story, from
  bootloop v1 to a working desktop, including all the dead ends.
- [Dossier de recherche](docs/research/README.md) (FR): the complete research
  journal, the "Warranty Void" talk (slides as a single-page site + script), raw logs.

## Known limitations

| Limitation | Why |
|---|---|
| No `--memory` / `--cpus` limits | Android binds all cgroup controllers to v1 for its own use ([details](docs/how-it-works.md#why-no-cgroup-limits)) |
| Rootful only | Android has no subuid/subgid |
| `--net=host` only | Bridge networking (netavark/CNI) not tested |
| No systemd | Auto-start through Magisk `service.d` |
| XFCE only for the desktop | Compositing WMs (Mutter: GNOME, Cinnamon) render nothing on Termux:X11 |
| Book Cover sleep disabled | The patched `hall_ic_wacom` driver always reports the cover as open |

## Repository layout

```
.
├── setup.sh                     # Interactive installer for steps 5-6 (Docker, Podman, Ubuntu, X11, SSH)
├── SHA256SUMS                   # Checksums of every pinned download (+ the generated vbmeta)
├── Containerfile.d/Containerfile# Toolchain image: Ubuntu 22.04 + clang-12 + pinned AOSP boot tools
├── kernel/
│   ├── build-kernel.sh          # Patch + configure + compile Image.gz in the container
│   ├── make-boot-img.sh         # Stock boot.img + our Image.gz -> boot image
│   ├── config/gts7xlwifi_containers.config
│   └── patches/0001-sm-t970-container-support.patch
├── firmware/make-vbmeta-disabled.sh # Generates the AVB-disabled vbmeta image
├── scripts/
│   ├── docker/  podman/         # Runtime configs + PC-side installers
│   ├── magisk-service.d/        # Boot-time auto-start (docker, podman, ssh)
│   ├── setup-{ubuntu,shell,x11,ssh}.sh # PC-side installers for the Linux environment
│   ├── chroot/sm-t970.bashrc    # Root shell config installed in the chroot
│   ├── start-*.sh / enter-ubuntu.sh   # Tablet-side launchers
│   ├── mount-cgroups.sh  prepare-rootfs-overrides.sh
│   └── uninstall.sh
├── docs/                        # Guide, internals, troubleshooting, story, research (journal, talk, logs)
├── downloads/                   # Third-party binaries you download (git-ignored)
├── sources/                     # Samsung kernel sources (git-ignored)
└── output/                      # Build artifacts (git-ignored)
```

## Credits

- [ivonblog](https://ivonblog.com/en-us/posts/sony-xperia-5-ii-docker-kernel/): Docker on a
  Sony Xperia 5 II with a custom kernel, the write-up that showed native Docker on Android was possible
- [mgoltzsche/podman-static](https://github.com/mgoltzsche/podman-static): static Podman for arm64
- [topjohnwu/Magisk](https://github.com/topjohnwu/Magisk): root, `magiskpolicy`, `service.d`
- [ianmacd](https://github.com/ianmacd): TWRP build for gts7xl
- [Termux](https://termux.dev) and [Termux:X11](https://github.com/termux/termux-x11)

## License

Scripts, configs and docs: [MIT](LICENSE). The kernel patch and `.config` are
GPL-2.0, like the Linux kernel they apply to.

---

[Guide: start here](docs/guide/00-before-you-start.md) · [How it works](docs/how-it-works.md) · [Troubleshooting](docs/troubleshooting.md) · [Root shell & SSH](docs/root-shell-and-ssh.md) · [Download mirror](docs/mirror.md) · [Histoire (FR)](docs/histoire-du-projet.md) · [Dossier de recherche (FR)](docs/research/README.md)
