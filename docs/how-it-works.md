# How it works

[README](../README.md) · [Guide](guide/00-before-you-start.md) · **How it works** · [Troubleshooting](troubleshooting.md) · [Root shell & SSH](root-shell-and-ssh.md) · [Download mirror](mirror.md) · [Histoire (FR)](histoire-du-projet.md)

This page explains **why** the project is built the way it is: what a kernel
does on an Android tablet, why replacing it is delicate, and what it takes to
run Docker on a system that was never meant for it. You do not need it to
follow the [step-by-step guide](guide/00-before-you-start.md), but it helps
when something goes wrong or when you want to adapt the project to another device.

It starts with the big picture and a glossary, then goes deeper section by
section. Each section opens with an **In short** summary.

## The big picture

Docker and Podman are "container runtimes". A container is an application
packaged with everything it needs, which runs isolated from the rest of the
system while sharing the host's kernel. That isolation is provided by
the **kernel**, the core of the operating system that manages processes,
memory, files and the network.

Android uses the Linux kernel, but the configuration used for this tablet leaves
several container features off: user, PID and network namespaces, the `pids`
cgroup, POSIX message queues, IPVS… The code for all of them is already in the
kernel sources; it is simply not compiled in. So the project solves three
problems, in this order:

1. **Boot a kernel we built ourselves**, without Android noticing anything
   apart from the kernel itself (→ [the boot image](#the-boot-image)).
2. **Turn on the container features** in that kernel while keeping every Samsung
   driver: screen, S Pen, Wi-Fi… (→ [the kernel](#the-kernel)).
3. **Run Linux container software on Android.** Android is Linux underneath,
   but its file layout is very different from Ubuntu's or Debian's, and Docker
   expects the latter (→ [Android-ification](#android-ification-of-an-oci-runtime)).

```
            what we change                         what stays stock
 ┌──────────────────────────────────┐   ┌────────────────────────────────────┐
 │ kernel (Image.gz) + Magisk root  │   │ bootloader, Android 13, One UI,    │
 │ Docker/Podman in /data           │   │ apps, drivers' firmware, ramdisk,  │
 │ optional: Ubuntu in /data/ubuntu │   │ device tree, kernel command line   │
 └──────────────────────────────────┘   └────────────────────────────────────┘
```

## Glossary

| Term | Meaning here |
|---|---|
| **Kernel** | The core of the OS. On Android, it lives in the `boot` partition. It is the only system component this project replaces |
| **Bootloader / ABL** | The first program that runs at power-on. On Qualcomm chips it is called ABL (*Android Boot Loader*). It loads the kernel and decides what is allowed to boot |
| **OEM unlock** | Samsung's switch that lets the bootloader run images Samsung did not sign. It permanently trips **Knox**, Samsung's hardware warranty and security fuse |
| **Download Mode / heimdall** | Samsung's flashing mode, entered with a key combo. `heimdall` is the open-source Linux tool that writes partitions in this mode (the equivalent of Samsung's Windows tool, Odin) |
| **Recovery / TWRP** | A small maintenance system on its own partition. TWRP is a community recovery that can install things like Magisk |
| **Magisk** | The standard Android root solution. It patches the boot image so that `su` (superuser) works, and runs our scripts at boot (`service.d`) |
| **boot.img** | The image written to the `boot` partition. It contains the kernel, a ramdisk, a device tree and the kernel command line |
| **Ramdisk / init** | A tiny file system loaded with the kernel. It holds `init`, the first program the kernel starts, which mounts the real system |
| **Device tree (DTB / DTBO)** | A description of the hardware (which chip, which pins, which screen) that the kernel reads at boot. DTB = base description for the chip, DTBO = overlay with Samsung's board-specific details |
| **Kernel command line (cmdline)** | Options passed to the kernel at boot, stored in `boot.img` |
| **AVB / vbmeta / dm-verity** | Android Verified Boot: the bootloader checks a signature (stored in the `vbmeta` partition) before booting, and `dm-verity` checks the system partition while it runs. We turn verification off so that our unsigned images boot |
| **FBE / Keymaster / ROT** | File-Based Encryption encrypts user data. The keys are protected by Keymaster in the secure zone of the chip, and bound to the bootloader's Root of Trust (ROT), i.e. its locked/unlocked state |
| **SM8250 / kona** | Qualcomm's codename for the Snapdragon 865 chip in the tablet |
| **CIP** | Civil Infrastructure Platform, a project that maintains Linux 4.19 for the long term. Our kernel tree includes its updates |
| **LineageOS** | A community Android distribution. We only use its kernel source tree for Samsung SM8250 devices, not its system |
| **Namespaces** | The kernel feature that gives a container its own view of processes, network, users, mounts… |
| **cgroups** | The kernel feature that limits and accounts for a group of processes' CPU, memory, etc. |
| **OverlayFS** | A file system that stacks image layers. Docker and Podman use it to store images |
| **OCI runtime** | The standard low-level program that actually starts a container (`runc`, `crun`). Docker and Podman drive it |
| **chroot** | Running programs with another directory as their `/`. That is how Ubuntu runs "inside" Android here |
| **Termux** | A Linux terminal app for Android. We only use some of its tools (`mount`, `unshare`, the X server) |
| **SELinux** | The mandatory access control layer of Android. It stays enforcing; Magisk gives root the rights it needs |

## How the tablet boots

**In short:** each stage checks or prepares the next one. We replace one link
(the kernel), and make sure everything around it stays exactly as Samsung expects.

```
power on
  └─ ABL (bootloader)  checks vbmeta → loads boot.img → picks the device tree
       └─ kernel       starts drivers, reads the device tree and the cmdline
            └─ init    (from the ramdisk) mounts system / vendor, unlocks /data (FBE)
                 └─ Android 13 + One UI
                      └─ Magisk service.d → our scripts: Docker, Podman, sshd
```

## The boot image

**In short:** we take Samsung's own `boot.img` and swap only the kernel inside
it. Changing anything else, even one option on the command line, prevents
Android from starting.

The SM-T970 uses a **header v2** `boot.img`:

```
boot.img (header v2, 68 MiB partition)
├── kernel    Image.gz                      ← the only part we replace
├── ramdisk   first-stage init, fstab.qcom  ← stock (Magisk adds itself here)
├── dtb       3 × kona base DTBs            ← stock
└── header    offsets, os_version 11.0.0, patch level 2024-08, board, cmdline
```

**Device tree.** ABL picks the base DTB by `qcom,msm-id`, then applies Samsung's
overlay from the `dtbo` partition by `qcom,board-id` (here DTBO #3,
"PV Rev0.4, board-id 6"). Overlays need `__symbols__` in the base DTB. Samsung
builds its DTBs with `dtc -@`, and a plain kernel build does not. So we
**keep Samsung's DTB section** and ship only `Image.gz`.

### The `force_normal_boot` trap

AOSP documentation says init needs `androidboot.force_normal_boot=1` to tell a
normal boot from a recovery boot. On this device **ABL adds it by itself at
runtime**, and it does not appear in the stock cmdline. Writing it into the boot
image cmdline makes Samsung's first-stage init switch root to
`/first_stage_ramdisk` *before* reading `/fstab.qcom`. Init then finds no fstab,
cannot mount `/system`, and the kernel panics with `Attempted to kill init!`.
This one flag caused 12 bootloops (v3→v14).

Rule: **cmdline byte-identical to stock.** `make-boot-img.sh` copies it from the
stock image.

### Verified boot

**In short:** a 4 KiB file tells the bootloader "do not check signatures".

`firmware/vbmeta_disabled.img` (generated by `firmware/make-vbmeta-disabled.sh`)
is an empty vbmeta with flags = 3 (verity disabled + verification disabled). Once
it is flashed, the bootloader accepts any boot or recovery image. Samsung's
yellow "bootloader unlocked" warning stays on screen at each boot.

### Encryption keys and the Root of Trust

**In short:** right after the unlock, the tablet may refuse to open its own
encrypted data. One factory reset fixes it for good.

Samsung's Keymaster binds the file-based-encryption keys to the bootloader's
Root of Trust, computed from `device_state` and the unlock counter (`ulcnt`). It
does **not** depend on the boot image itself. Keys created before the unlock
(ROT `06…`) cannot be opened after it (ROT `07…`): `vold` fails with
`enablefilecrypto_failed` and recovery offers "Retry / Factory reset". **One**
factory reset regenerates the keys. After that, any custom kernel boots with the
same ROT.

## The kernel

**In short:** a maintained kernel source tree for this chip, plus a few fixes,
compiled with the container features turned on.

**Sources:** LineageOS's
[`android_kernel_samsung_sm8250`](https://github.com/LineageOS/android_kernel_samsung_sm8250),
branch `lineage-23.2`, pinned at commit `4910fe83f` (fetched by `kernel/get-sources.sh`).
It is Samsung's SM8250 kernel (Qualcomm `techpack/`, Samsung drivers) with the
CIP 4.19 long-term updates merged, hence `4.19.325-cip128-st12`, against
`4.19.113` for the stock kernel. It runs on the **stock** Samsung Android 13
(T970XXS7DXH1): only the kernel changes, not the system.

**Patch or configuration?** Two different things, often confused:

- the **configuration** (`.config`) decides *which* features are compiled into
  the kernel. Every container feature already exists in the sources: turning it
  on is a matter of configuration, nothing has to be downloaded or added;
- the **patch** changes *source code*. Here it only fixes what prevents the tree
  from building or the tablet from working (build errors, device trees, display,
  S Pen sensor). It adds no container feature.

**Configuration:** a kernel is built from thousands of `CONFIG_…` options. The
tree's default for this tablet is assembled from `kona_defconfig` plus Samsung's
fragments `kona-sec-common.config` and `gts7xlwifi.config`
(`arch/arm64/configs/vendor/`). Some container options are already on there
(`OVERLAY_FS`, `VETH`, `BRIDGE`, `MEMCG`, `IP_NF_NAT`…); the others were turned
on with `make menuconfig`, then checked with Docker's `check-config.sh`. The
result is the complete file [`kernel/config/gts7xlwifi_containers.config`](../kernel/config/gts7xlwifi_containers.config).
Among the container options:

| Area | Options |
|---|---|
| Namespaces | `NAMESPACES`, `USER_NS`, `PID_NS`, `NET_NS`, `IPC_NS`, `UTS_NS` |
| Cgroups | `CGROUPS`, `MEMCG`, `CGROUP_PIDS`, `CGROUP_DEVICE`, `CGROUP_FREEZER`, `CPUSETS`, `CGROUP_BPF`, `CFS_BANDWIDTH`, `BLK_CGROUP` |
| Storage | `OVERLAY_FS`, `BTRFS_FS`, `EXT4_FS_POSIX_ACL` |
| Network | `VETH`, `BRIDGE`, `BRIDGE_NETFILTER`, `IP_NF_*`, `IP6_NF_*`, `NF_NAT`, `IP_VS*`, `VXLAN`, `IPVLAN`, `MACVLAN`, `NF_TABLES` |
| Security | `SECCOMP_FILTER`, `KEYS`, `SECURITY_SELINUX`, `SECURITY_APPARMOR` |
| Debug | `IKCONFIG_PROC` (exposes the running config as `/proc/config.gz`) |

**Patch** (`kernel/patches/0001-sm-t970-container-support.patch`, 14 files):

| Part | Files | Why |
|---|---|---|
| Build with clang-12 | `Makefile`, `lockdep.c`, `rcu/update.c`, `fault-inject.c`, `sec_cmd.c`, `synaptics_dsx_rmi_dev.c`, `pinctrl-msm.c`, `msm_pcie.h`, `sec_gps_bcm4753.c` | Relax `-Werror`, add missing includes and stubs. The tree does not build as is outside Samsung's own toolchain |
| Device trees | `arch/arm64/boot/dts/Makefile`, `vendor/qcom/Makefile` | Enable the vendor DTS directory, add `kona*.dtb`, drop IoT/RB5 boards with missing includes |
| Display | `sde_encoder_phys_wb.c`, `sde_kms.c` | Guard Samsung-only display calls behind `CONFIG_DISPLAY_SAMSUNG` |
| Cover / S Pen | `hall_ic_wacom.c` | Always report the back cover as **open** (see below) |

**Where Samsung's hardware support lives.** Drivers for the tablet's own hardware
are Samsung code, already in the tree and enabled by Samsung's per-device
fragment (`arch/arm64/configs/vendor/samsung/gts7xlwifi.config`), not by
`kona_defconfig` (which covers the Qualcomm chip). Our `.config` keeps them as they are.
The S Pen, for example:

| Component | Source | Enabled by |
|---|---|---|
| S Pen digitizer (Wacom W9021) | `drivers/input/wacom/` (`wacom_i2c.c`, `wacom_i2c_sec.c`, `w9020_flash.c`…) | `CONFIG_INPUT_WACOM`, `CONFIG_EPEN_WACOM_W9021` |
| S Pen / back cover hall sensor (the one we patch) | `drivers/input/keyboard/hall_ic_wacom.c` | `CONFIG_WACOM_HALL` |
| Other hall sensors (main cover, logical aggregate) | `drivers/input/…` | `CONFIG_SENSORS_HALL`, `CONFIG_LOGICAL_HALL` |
| Hardware description (I²C bus, pins, interrupts) | `arch/arm64/boot/dts/samsung/gts7xl/`, `samsung/drivers/input_gts7xl_common.dtsi` | device trees (on the tablet: Samsung's stock DTB + the `dtbo` partition, both left untouched) |

**The hall sensor.** A hall sensor detects magnets. The `hall_wacom` sensor
reports `SW_MACHINE_COVER` whenever a magnet is near: S Pen docked, back cover
folded, even during S Pen use. With the custom kernel, Samsung's framework
(`SEP_UNION_CoverManager`) then blanks the screen, and it **cancels power-button
wake-ups** while a "generic" cover is attached
(`!@Screen__On : Cancel (coverType: 0)`). This is what the project first took
for a display driver bug. The patch skips the sensor read at start-up and always
reports "open". The trade-off: closing a Book Cover no longer puts the tablet to sleep.

`xt_qtaguid`, the patch usually described as mandatory for Docker on Android, is
**not** needed: this Android 13 tree no longer contains that module.

## Where things live

**In short:** everything we install sits in `/data`, the only place on Android
that is writable and survives reboots.

| Path | Content | Why there |
|---|---|---|
| `/data/local/tmp/{docker,podman}/` | Static binaries, wrappers | Writable by root, survives reboots |
| `/data/docker`, `/data/podman` | Images, containers, volumes | Device-encrypted area, usable at boot. Termux's own directory (`/data/data/com.termux`) is encrypted per app with the user's credentials, and OverlayFS and fscrypt keys misbehave there (`ENOKEY`) |
| `/data/ubuntu` | Ubuntu chroot | Same reason |
| `/data/adb/service.d/*.sh` | Boot hooks | Magisk runs them as root late in the boot, once `/data` is decrypted |

## Android-ification of an OCI runtime

**In short:** Docker expects a classic Linux system (`/run`, `/etc/resolv.conf`,
a writable root…). Android has none of that, so the scripts recreate each missing
piece before starting the runtime, and again at every boot.

Every container runtime assumes a POSIX distribution. Android is not one. The
same gaps show up for Docker, Podman, LXC or anything else, and each one has a fix:

| Gap on Android | Fix (where) |
|---|---|
| `/` is read-only (dm-verity) | `mount -o rw,remount /`, `mkdir` the mount points, then remount `ro` (wrappers) |
| No `/run/*` | One **tmpfs** (RAM file system) per path: `/run/lock`, `/run/containers`, `/run/crun`, `/run/podman`… Must be tmpfs, not bind mounts to `/data`, or Podman detects a stale boot ID (`podman-wrapper.sh`, `start-docker.sh`) |
| Paths hard-coded despite configs | containerd and dockerd still use `/run/containerd` and `/run/docker` for FIFOs and plugins, so these are mounted anyway |
| No `/dev/shm` | `mount -t tmpfs` (Podman's lock manager needs it) |
| No `/var/run/docker.sock` | `-H unix:///data/docker/docker.sock`, plus `DOCKER_HOST` in the chroot and SSH sessions |
| No `/etc/resolv.conf` (DNS), no CA bundle (TLS) | Recreated at **every boot** from copies in `/data` (`prepare-rootfs-overrides.sh`). Writes to `/` only live in RAM |
| No `/etc/containers/` | Same. Some libraries ignore the `CONTAINERS_*` variables and read fixed paths |
| No `/etc/passwd` | `HOME=/data/podman USER=root` (`getpwuid(0)` fails) |
| Cgroups not mounted where runtimes expect them | `mount-cgroups.sh` mounts the v1 hierarchies, including Samsung's `schedtune` |
| No systemd to start services | Magisk `service.d` |
| `umask 0000` in boot hooks | Set `umask 0022` explicitly (sshd refuses a world-writable `/run/sshd`) |

### Why no cgroup limits

**In short:** Android already uses every resource controller for its own needs,
so containers run without CPU or memory limits.

Android 12+ mounts cgroup **v2** at `/sys/fs/cgroup` with **no controllers
enabled**, and binds every real controller (cpu, memory, …) to **v1**
hierarchies under `/dev/{cpuctl,memcg,stune,…}` for zygote, the scheduler (EAS)
and thermal management. A controller can only belong to one hierarchy. crun sees
cgroup2, looks for `pids` there, and fails.

| Option | Verdict |
|---|---|
| `cgroup_no_v1=all` on the cmdline | Breaks Android (init, thermal) |
| Rewrite Android userspace for v2 | Out of scope |
| **`cgroups = "disabled"`** in `containers.conf` `[containers]` | **Chosen.** Everything runs, `--memory`/`--cpus` are ignored |

This is an Android userspace constraint, not a kernel one: the kernel has full
v2 support. Note that the setting must sit in `[containers]`, not `[engine]`:
compose goes through the REST API, which only honours `[containers]`.

### Why not a chroot for the runtimes

**In short:** running Docker inside the Ubuntu chroot hits kernel and encryption
limits, so the runtimes run directly on Android and Ubuntu only hosts the
command-line clients.

| Attempt | Failure |
|---|---|
| Podman in proot (Termux) | proot's `ptrace` layer blocks `clone(CLONE_NEWUSER)` |
| Podman/Docker in a real chroot | `remount /, flags 0x44000: invalid argument`: the kernel refuses `MS_REC\|MS_PRIVATE` on a shared chroot root. This is a hard check, confirmed upstream |
| LXC in a chroot | Worked once, then `ENOKEY` on `execve` after `pivot_root`: the encryption key is missing from the child's keyring |

So the runtimes run **natively** on Android, and the Ubuntu chroot only hosts the
*clients* (`docker` talks to the daemon through its socket).

## The desktop

**In short:** an Android app provides the X server, and a small bridge lets
Ubuntu's XFCE desktop draw into it.

```
Termux:X11 app ── X server (abstract socket @…/.X11-unix/X0)
      ▲
      │ socat UNIX-LISTEN:/tmp/.X11-unix/X0 ↔ ABSTRACT-CONNECT
      │
chroot /data/ubuntu ── dbus ── startxfce4 (DISPLAY=:0, GDK_SCALE=2, Xft.dpi 192)
```

The chroot cannot see Linux "abstract" sockets, so `socat` bridges the X server's
socket to a regular file socket. XFCE's window manager (xfwm4) draws directly to
X surfaces and works. Mutter-based desktops (GNOME Shell, Cinnamon/Muffin,
Budgie) composite through OpenGL and display nothing on Termux:X11, even with
software OpenGL (llvmpipe) working. MATE (Marco) and LXQt (Openbox) should work,
but are untested.

---

[README](../README.md) · [Guide](guide/00-before-you-start.md) · **How it works** · [Troubleshooting](troubleshooting.md) · [Root shell & SSH](root-shell-and-ssh.md) · [Download mirror](mirror.md) · [Histoire (FR)](histoire-du-projet.md)
