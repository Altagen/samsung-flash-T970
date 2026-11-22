# Step 3 — Build the kernel

[← Step 2: Root with TWRP + Magisk](02-root-twrp-magisk.md) · [Guide overview](../../README.md#step-by-step-guide) · [Step 4: Flash the kernel →](04-flash-kernel.md)

> **Goal:** `output/boot-custom.img`, the stock boot image with our kernel inside.
> **Time:** 10-30 min (6 min on a 16-thread CPU). **Where:** PC only. The tablet is not needed.

The kernel is LineageOS's tree for Samsung SM8250 devices
([android_kernel_samsung_sm8250](https://github.com/LineageOS/android_kernel_samsung_sm8250),
pinned commit `4910fe83f`): Samsung's kernel with the CIP 4.19 long-term updates
merged. On top of it come one patch and a `.config` with ~50 container options
turned on. It compiles in a container (Ubuntu 22.04 + clang-12), so the host
toolchain does not matter.

## Prerequisites

- [ ] `podman run --rm docker.io/library/alpine:3.20 true` works (or Docker with `export CONTAINER_ENGINE=docker`)
- [ ] The stock boot image in `downloads/` ([step 0](00-before-you-start.md), action 5) — `sha256sum -c --ignore-missing SHA256SUMS | grep boot`
- [ ] `git` installed and GitHub reachable (or the mirror, see below) — `git ls-remote https://github.com/LineageOS/android_kernel_samsung_sm8250.git HEAD`
- [ ] ~8 GB free — `df -h .`

## Actions

### 1. 🖥️ Get the kernel sources into `sources/`

```bash
kernel/get-sources.sh
```

```
Fetching https://github.com/LineageOS/android_kernel_samsung_sm8250.git @ 4910fe83f (shallow)...
  OK Kernel sources in …/sources (git, 4910fe83f)
```

The script fetches exactly the commit used for the validated build (one commit,
no history, ~250 MB). If GitHub or the commit is no longer available, it
downloads the same tree from the [project mirror](../mirror.md) instead
(`android_kernel_samsung_sm8250-4910fe83f.tar.xz`, SHA-256 checked).
`build-kernel.sh` also runs it automatically when `sources/` is missing.

```bash
head -4 sources/Makefile
```

```
# SPDX-License-Identifier: GPL-2.0
VERSION = 4
PATCHLEVEL = 19
SUBLEVEL = 325
```

The tree identifies itself as `4.19.325-cip128-st12`: LineageOS merged the
[CIP](https://www.cip-project.org/) long-term 4.19 updates into Samsung's kernel.
The stock Samsung kernel on the tablet reports `4.19.113`; running the newer
4.19 on stock Android 13 is exactly what this project does.

### 2. 🖥️ Build the kernel

```bash
kernel/build-kernel.sh
```

The script runs four stages, each printed as `==>` (plus `Kernel sources` first if `sources/` is missing):

1. **Toolchain image:** builds `sm8250-builder:v2` from `Containerfile.d/Containerfile` (first run only, ~3 min).
2. **Kernel patch:** applies [`kernel/patches/0001-sm-t970-container-support.patch`](../../kernel/patches/0001-sm-t970-container-support.patch), or prints `already applied`.
3. **Kernel config:** installs [`kernel/config/gts7xlwifi_containers.config`](../../kernel/config/gts7xlwifi_containers.config), runs `olddefconfig`, checks the key options (`container options present`).
4. **Compiling Image.gz.** Thousands of `warning: unknown warning option` lines are normal with clang-12.

It ends with:

```
==> Done
Kernel: …/output/kernel/arch/arm64/boot/Image.gz (22M)
```

Options: `JOBS=8 kernel/build-kernel.sh`, `CONTAINER_ENGINE=docker kernel/build-kernel.sh`,
or other paths: `kernel/build-kernel.sh /path/to/sources /path/to/out`.

#### Config vs patch: what each one does

Nothing has to be downloaded or added to the kernel: the code of every container
feature (namespaces, cgroups, OverlayFS, netfilter, IPVS…) is already in the
sources. **The `.config` turns these features on.** The default configuration
leaves several of them off (user, PID and network namespaces, the `pids` cgroup,
IPVS…).

**The patch adds no feature.** It only fixes source code that keeps the tree
from building, or the tablet from working:

[`kernel/patches/0001-sm-t970-container-support.patch`](../../kernel/patches/0001-sm-t970-container-support.patch)
touches 14 existing files (it creates none), in four groups:

| Group | Why it matters |
|---|---|
| **Build fixes** (`Makefile`, a few drivers and headers) | Without them, the tree does not compile with clang-12 |
| **Device trees** (`dts/Makefile`, `vendor/qcom/Makefile`) | Builds the Qualcomm `kona` device trees and skips boards with missing files |
| **Display** (`sde_kms.c`, `sde_encoder_phys_wb.c`) | Guards Samsung-only display calls so the display driver builds |
| **S Pen / cover sensor** (`drivers/input/keyboard/hall_ic_wacom.c`) | **Without it, the screen turns black as soon as the S Pen is docked or the cover is folded**, and the power button no longer wakes it. The patch makes the sensor always report "cover open" |

Details for each group: [how it works › the kernel](../how-it-works.md#the-kernel).
The **Verify** section below checks that the patch, including the S Pen fix,
made it into the kernel.

<details>
<summary>The same thing by hand</summary>

```bash
podman build -t sm8250-builder:v2 -f Containerfile.d/Containerfile Containerfile.d
patch -d sources -p1 < kernel/patches/0001-sm-t970-container-support.patch
mkdir -p output/kernel && cp kernel/config/gts7xlwifi_containers.config output/kernel/.config

M="podman run --rm -v $PWD/sources:/work/sources:ro -v $PWD/output/kernel:/work/output sm8250-builder:v2 \
   make -C /work/sources O=/work/output ARCH=arm64 LLVM=1 LLVM_IAS=1"
$M olddefconfig
$M -j$(nproc) Image.gz
```
</details>

### 3. 🖥️ Assemble the boot image

```bash
kernel/make-boot-img.sh \
    downloads/T970XXS7DXH1-boot.img.lz4 \
    output/kernel/arch/arm64/boot/Image.gz \
    output/boot-custom.img
```

```
Boot image: …/output/boot-custom.img (23 MiB, partition 68 MiB)
  kernel   replaced  (Image.gz)
  ramdisk  stock     (verified)
  dtb      stock     (verified)
  cmdline  stock
```

The script also accepts the firmware's `AP_…tar.md5` directly, or a plain
`boot.img`. If the host's
`unpack_bootimg` is too old (Debian 12, Ubuntu 22.04), it says so and runs
inside `sm8250-builder:v2`.

It reads every `mkbootimg` parameter from the stock image (header v2, offsets,
`os_version`, board, cmdline), swaps in the kernel, then checks that the ramdisk
and DTB are byte-identical to stock and that the image fits the partition.
Three rules it enforces, each learned the hard way:

| Rule | What happens otherwise |
|---|---|
| Use **`Image.gz`**, not `Image.gz-dtb` | 45-80 MB image → `ERROR: BOOT partition is too small`. Header v2 carries the DTB in its own section |
| Keep the **stock DTB** section | ABL/DTBO selection breaks (our DTBs lack `__symbols__`) |
| Keep the **stock cmdline** exactly | Adding `androidboot.force_normal_boot=1` → bootloop (init switches root before reading `fstab.qcom`) |

Background: [how it works › boot image](../how-it-works.md#the-boot-image).

## Verify

```bash
ls -lh output/boot-custom.img                                                       # ~23M
zcat output/kernel/arch/arm64/boot/Image.gz | strings | grep -m1 'Linux version'    # Linux version 4.19.325-cip128-st12+ … clang version 12.0.1
grep -E '^CONFIG_(USER_NS|OVERLAY_FS|VETH|CGROUP_PIDS)=' output/kernel/.config      # four "=y" lines

# The patch is in the sources AND in the compiled kernel (S Pen / cover fix as a marker)
patch -d sources -p1 -R --dry-run -s -f < kernel/patches/0001-sm-t970-container-support.patch && echo "patch applied"
zcat output/kernel/arch/arm64/boot/Image.gz | strings | grep 'cover detection disabled'  # keys:%s : cover detection disabled, reporting OPEN
```

If the last command prints nothing, the kernel was built without the patch:
do not flash it (see below).

## If it fails

| Problem | Fix |
|---|---|
| `Patch neither applies nor is already applied` | `sources/` is not the pinned commit, or was modified. Move it away and run `kernel/get-sources.sh` again |
| `get-sources.sh`: `git fetch failed` then `FAILED` | GitHub and the mirror both unreachable. Check the network and retry |
| `kona-camera-sensor-rb5-nopop.dtsi: No such file` | The patch was not applied. The script normally refuses to go on in that case: re-run it |
| Verify: `cover detection disabled` not found in `Image.gz` | The kernel was compiled from unpatched sources (e.g. built by hand, or `sources/` replaced after patching). Run `kernel/build-kernel.sh` again: it applies the patch if needed and recompiles the changed files |
| `ERROR: … is missing techpack/` | `sources/` holds another kernel tree. Move it away and run `kernel/get-sources.sh` |
| Build killed / out of memory | `JOBS=4 kernel/build-kernel.sh` |
| `Expected a header v2 boot image` | The stock image is not from an SM-T970 firmware |
| `Output … is larger than the BOOT partition` | You passed `Image` or `Image.gz-dtb`. Use `Image.gz` |

---

[← Step 2: Root with TWRP + Magisk](02-root-twrp-magisk.md) · [Guide overview](../../README.md#step-by-step-guide) · [Step 4: Flash the kernel →](04-flash-kernel.md)
