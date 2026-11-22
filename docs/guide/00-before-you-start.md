# Step 0 — Before you start

[Guide overview](../../README.md#step-by-step-guide) · [Step 1: Unlock the bootloader →](01-unlock-bootloader.md)

> **Goal:** a Linux PC with every tool and file needed for steps 1-7, and a tablet
> that matches the tested firmware. **Time:** 15 min, plus downloads. **Where:** PC.

Every step of this guide follows the same layout: **Prerequisites** (each with a
command to check it), **Actions** (each marked 🖥️ PC or 📱 tablet),
**Verify** (expected output), and **If it fails**.

## Prerequisites

- [ ] A Linux PC (tested on Arch / CachyOS; Debian 12+ and Ubuntu 22.04+ work)
- [ ] About **10 GB** of free disk space (downloads, kernel sources and build) — `df -h .`
- [ ] A **USB-C data cable** (some charging cables carry no data)
- [ ] A Galaxy Tab S7+ **Wi-Fi**, model **SM-T970**, firmware **T970XXS7DXH1** (checked in action 4)
- [ ] A Samsung account and a Wi-Fi network for the tablet

## Actions

### 1. 🖥️ Install the tools

```bash
# Arch / CachyOS
sudo pacman -S --needed android-tools heimdall lz4 podman git curl unzip patch openssh

# Debian 12+ / Ubuntu 22.04+
sudo apt install adb heimdall-flash lz4 podman git curl unzip patch openssh-client
```

| Tool | Used in | Note |
|---|---|---|
| `adb` | steps 1-7 | Ubuntu 22.04 names the package `android-tools-adb` |
| `heimdall` | steps 2, 4 | Samsung's Download Mode protocol (the Odin equivalent) |
| `podman` | steps 2, 3 | Kernel toolchain container. Docker works too: `export CONTAINER_ENGINE=docker` |
| `mkbootimg`, `unpack_bootimg`, `avbtool` | steps 2, 3 | Optional on the host. Arch's `android-tools` has them; otherwise the scripts use pinned copies inside the toolchain container |
| `ssh`, `ssh-keygen` | step 6 | SSH into the tablet |

### 2. 🖥️ Allow heimdall to use USB without root

Arch's heimdall package installs a udev rule. On Debian/Ubuntu, check that one
exists, or add it:

```bash
ls /usr/lib/udev/rules.d/ /etc/udev/rules.d/ | grep -i heimdall || {
  echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="04e8", ATTR{idProduct}=="685d", TAG+="uaccess"' \
    | sudo tee /etc/udev/rules.d/60-heimdall.rules
  sudo udevadm control --reload-rules
}
```

### 3. 🖥️ Get the repository

```bash
git clone https://github.com/Altagen/samsung-flash-T970.git
cd samsung-flash-T970
```

**All commands in this guide are run from this directory.**

### 4. 📱 Check the tablet

Settings › About tablet › Software information:

| Field | Must be |
|---|---|
| Model number | **SM-T970**. The SM-T976 (5G) uses another firmware and is untested |
| Build number | **…T970XXS7DXH1** |

The kernel sources, the stock `boot.img` and the firmware on the tablet must be
the **same build**. With another build, either flash T970XXS7DXH1 first (Odin or
Heimdall, full firmware), or use the sources and firmware matching your build.
The second option is untested and the patch may need adapting.

### 5. 🖥️ Download the third-party files into `downloads/`

```bash
scripts/fetch-downloads.sh
```

```
  get     twrp-gts7xl-3.6.0_11-A12-1a7_ianmacd.img  <-  https://github.com/…/releases/download/v1.0.0/…
  ok      twrp-gts7xl-3.6.0_11-A12-1a7_ianmacd.img (checksum verified)
  get     Magisk-v30.7.apk  <-  https://github.com/topjohnwu/Magisk/releases/download/v30.7/Magisk-v30.7.apk
  ok      Magisk-v30.7.apk (checksum verified)
  …
All files present and verified in downloads/.
```

The script downloads the 10 pinned files (≈ 420 MB): TWRP, Magisk, the stock
boot image, Docker, docker-compose, Podman, Termux, Termux:X11, the Ubuntu base
rootfs and ConnectBot. For each one it tries the **official URL first**, falls
back to the project's [download mirror](../mirror.md) if the link is dead or
serves a different file, and **always checks the SHA-256** against
[`SHA256SUMS`](../../SHA256SUMS).

Files without a stable official URL come from the mirror: TWRP (XDA only),
the Termux:X11 nightly (moved upstream), and the stock boot image (inside a
7.6 GB Samsung firmware).

<details>
<summary>Prefer the official stock boot image? Extract it from Samsung's firmware</summary>

Download the full firmware `SM-T970 … T970XXS7DXH1` (≈ 7.6 GB, e.g. from SamFw,
region EUX was used), then:

```bash
unzip -j downloads/SM-T970_*T970XXS7DXH1*.zip 'AP_*' -d downloads/     # adapt the zip name
tar -xOf downloads/AP_T970XXS7DXH1_*.tar.md5 boot.img.lz4 > downloads/T970XXS7DXH1-boot.img.lz4
sha256sum -c --ignore-missing SHA256SUMS | grep boot                   # must be OK: same file as the mirror
```
</details>

The kernel sources are fetched in [step 3](03-build-kernel.md) (git, about 250 MB).

## Verify

```bash
for t in adb heimdall lz4 podman git curl patch ssh ssh-keygen; do
  command -v $t >/dev/null && echo "ok   $t" || echo "MISSING $t"; done
podman run --rm docker.io/library/alpine:3.20 echo "podman ok"
sha256sum -c --ignore-missing SHA256SUMS
```

Expected:

- no `MISSING` line;
- `podman ok`;
- `OK` (or `Réussi`, depending on your locale) for the 10 downloaded files;
- `scripts/fetch-downloads.sh` ended with `All files present and verified`.

[`SHA256SUMS`](../../SHA256SUMS) lists the exact files validated on the device.
Versions are pinned on purpose.

## Before step 1

- **Back up the tablet.** The unlock in step 1 wipes it completely.
- Memorise the key combos:

| Action | How |
|---|---|
| **Download Mode**, from off | Hold **Vol Down + Vol Up**, plug the USB cable. On the warning screen, short **Vol Up** = continue |
| **Download Mode**, from Android | `adb reboot download` |
| **Leave Download Mode** / **force reboot** | Hold **Vol Down + Power** ~7 s |
| **Recovery** | Hold **Vol Up + Power** until the logo appears (USB unplugged) |

## If it fails

| Problem | Fix |
|---|---|
| `podman run` fails with a user namespace / `newuidmap` error | Rootless podman needs subuids: `sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER`, then log out and back in |
| `sha256sum` reports `FAILED` | Corrupted file: delete it and run `scripts/fetch-downloads.sh` again |
| `fetch-downloads.sh`: `FAILED … no source served the expected file` | No network, or both the official link and the mirror are down. Retry later, or get the file by hand from the sources in [docs/mirror.md](../mirror.md) and drop it into `downloads/` |

---

[Guide overview](../../README.md#step-by-step-guide) · [Step 1: Unlock the bootloader →](01-unlock-bootloader.md)
