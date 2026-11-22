# Step 7 — Daily use & maintenance

[← Step 6: Ubuntu, desktop & SSH](06-ubuntu-desktop-ssh.md) · [Guide overview](../../README.md#step-by-step-guide)

> **Goal:** run, update, roll back and uninstall without surprises.
> **Where:** PC (ADB) or directly on the tablet (ConnectBot / Termux + `su`).

## Prerequisites

- [ ] Steps 1-4 done; steps 5-6 for the parts that concern them
- [ ] For the PC commands: `adb devices` shows the tablet, `adb shell su -c id` prints `uid=0(root)`
- [ ] `output/boot-backup-magisk-stock.img` kept safe (step 2, action 9): it is your rollback

## Cheat sheet

From the PC. On the tablet, in an Android root shell (Termux › `su`), run the
part inside the quotes.

| What | Command |
|---|---|
| Ubuntu shell | `adb shell -t 'su -c /data/local/tmp/enter-ubuntu.sh'` |
| SSH from the PC | `adb forward tcp:22222 tcp:2222 && ssh -i ~/.ssh/sm-t970_ed25519 -p 22222 root@127.0.0.1` |
| Desktop | 📱 open Termux:X11, then `adb shell -t 'su -c /data/local/tmp/start-desktop.sh'` |
| Restart sshd | `adb shell "su -c 'setsid nohup /data/local/tmp/start-ssh.sh >> /data/local/tmp/ssh-boot.log 2>&1 < /dev/null &'"` |
| Restart Docker | `adb shell "su -c '/data/local/tmp/start-docker.sh'"` |
| Docker logs | `adb shell "su -c 'cat /data/docker/dockerd.log'"` |
| Boot hook logs | `adb shell "su -c 'cat /data/docker/boot.log /data/podman/boot.log /data/local/tmp/ssh-boot.log'"` |
| Disable all auto-start | `adb shell "su -c 'rm /data/adb/service.d/*.sh'" && adb reboot` |
| Update the shell config | `scripts/setup-shell.sh` |

## Rebuild or update the kernel

TWRP is not needed any more.

```bash
# 🖥️ 1. change the config or the patch, then rebuild
kernel/build-kernel.sh
kernel/make-boot-img.sh downloads/T970XXS7DXH1-boot.img.lz4 \
    output/kernel/arch/arm64/boot/Image.gz output/boot-custom.img
```

Then repeat [step 4](04-flash-kernel.md), actions 2-6: Magisk patch, then
`heimdall flash --BOOT … --VBMETA …`. Keep the previous `boot-custom-magisk.img`
until the new one is validated.

To change kernel options, use `menuconfig` in the container, then save the
result into the repo:

```bash
podman run --rm -it -v $PWD/sources:/work/sources:ro -v $PWD/output/kernel:/work/output sm8250-builder:v2 \
    make -C /work/sources O=/work/output ARCH=arm64 LLVM=1 LLVM_IAS=1 menuconfig
cp output/kernel/.config kernel/config/gts7xlwifi_containers.config
```

## Uninstall components

```bash
./scripts/uninstall.sh        # or ./setup.sh → u
```

The menu is granular: Docker, Podman, X11, SSH, Ubuntu, the whole Linux
environment, or everything. It removes the binaries, the data and the boot
hooks. The kernel, Magisk and ConnectBot stay.

## Back to stock

All from Download Mode (`adb reboot download`, or power off then Vol Down + Vol Up + USB):

| Goal | Image | Command |
|---|---|---|
| Stock kernel, keep root | Your backup from step 2, action 9 | `heimdall flash --BOOT output/boot-backup-magisk-stock.img` |
| Stock kernel, no root | Samsung's original, from `downloads/` (firmware or mirror, SHA-256 checked) | `lz4 -d downloads/T970XXS7DXH1-boot.img.lz4 output/boot-stock.img && heimdall flash --BOOT output/boot-stock.img` |
| Fully stock | The full firmware (BL, AP, CP, CSC) | Flash it with Odin or Heimdall. The bootloader stays unlocked |

Lost your backup? Root again from the stock image: flash `boot-stock.img` as
above, then let the Magisk app patch it (Install › Select and Patch a File, as in
step 4) and flash the result.

You can re-lock the bootloader from Download Mode only on a 100 % stock
firmware. Knox stays tripped (`0x1`) forever, whatever you do.

## Upgrading pinned versions

The versions in the scripts (Docker 27.3.1, compose 2.32.4, Podman 5.8.1, Ubuntu
24.04.4, Termux 0.119.0-beta.3 / F-Droid 1022, ConnectBot 1.11.1, kernel commit
`4910fe83f`) are the validated set, listed in [`SHA256SUMS`](../../SHA256SUMS) and
backed up in the [download mirror](../mirror.md). Newer releases will probably work,
but each one may hard-code a new `/run/*` or `/etc/*` path. In that case, see
[how it works › Android-ification](../how-it-works.md#android-ification-of-an-oci-runtime)
for the pattern to apply, then update `SHA256SUMS` and the mirror
([maintainer notes](../mirror.md#for-maintainers-republishing-the-release)).

## If it fails

| Problem | Fix |
|---|---|
| The tablet no longer boots after a kernel update | Download Mode, then `heimdall flash --BOOT output/boot-backup-magisk-stock.img` (or the previous `boot-custom-magisk.img`) |
| Nothing auto-starts after boot | `adb shell "su -c 'ls -l /data/adb/service.d/'"`: the scripts must be executable. Read the boot logs (cheat sheet) |
| A boot hook misbehaves and blocks you | Disable all auto-start (cheat sheet), reboot, then debug by hand |

---

[← Step 6: Ubuntu, desktop & SSH](06-ubuntu-desktop-ssh.md) · [Guide overview](../../README.md#step-by-step-guide)
