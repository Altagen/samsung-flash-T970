# Troubleshooting

[README](../README.md) · [Guide](guide/00-before-you-start.md) · [How it works](how-it-works.md) · **Troubleshooting** · [Root shell & SSH](root-shell-and-ssh.md) · [Download mirror](mirror.md) · [Histoire (FR)](histoire-du-projet.md)

## Unlock & root

**Download Mode keeps showing `OEM LOCK : ON (U)`.** You long-pressed Vol Up on
the second screen. Power off and start over: long-press on the **first** warning
screen ([step 1](guide/01-unlock-bootloader.md), action 2).

**OEM unlocking switch missing.** The Samsung account is too new (up to 7 days),
or the tablet has not been online. Stay connected and wait.

**TWRP is gone after reboot.** Stock Android restored the recovery partition.
Flash TWRP again and boot **straight** from Download Mode into TWRP (Vol Down +
Power, then Vol Up + Power).

**Bootloader refuses TWRP / the boot image (`Error verifying vbmeta image`).** Flash
`firmware/vbmeta_disabled.img` to `VBMETA` along with the image.

**TWRP ADB Sideload: the tablet disappears from USB.** This is a known issue on
this device. `adb push file /tmp/` and install from TWRP's file browser.
`/sdcard` cannot be used because it is encrypted.

**`su` denied / no popup.** Magisk › Superuser › delete the "Shell" entry, then
run `adb shell su -c id` again and tap Grant within ~10 s.

**Magisk asks for "Additional setup" after the TWRP install.** Expected (preinit
warning). Use Install › Direct Install.

## Kernel and flashing

The way back from any bad flash: Download Mode (power off, Vol Down + Vol Up +
USB) and `heimdall flash --BOOT <last good image>`. Keep the last working
Magisk-patched image around.

**`ERROR: BOOT partition is too small`.** You used `Image-dtb` or `Image.gz-dtb`.
Use `Image.gz`: header v2 carries the DTB separately. `make-boot-img.sh`
refuses anything else.

**Bootloop, pstore shows `ReadDefaultFstab(): failed to find device default fstab`
then `Attempted to kill init!`.** The cmdline was changed. Most likely
`androidboot.force_normal_boot=1` was added. Rebuild with `make-boot-img.sh`,
which copies the stock cmdline.

**Recovery says "Retry / Factory reset", `/data/log/enablefilecrypto_failed*`.**
The FBE keys were created under the pre-unlock Root of Trust
([details](how-it-works.md#encryption-keys-and-the-root-of-trust)). Do **one**
factory reset. It is never needed again for later kernels.

**Screen goes black with the S Pen docked or the cover folded; power button does
nothing.** You are running a kernel without the `hall_ic_wacom.c` part of the
patch. Check that the patch was applied (`build-kernel.sh` reports it).

**Display at 60 Hz.** Power saving mode is on after a reset. Turn it off. The
kernel exposes both modes (`dumpsys display` shows 120 and 60 Hz).

**Build fails on `kona-camera-sensor-rb5-nopop.dtsi`.** The patch was not applied
(it removes the IoT/RB5 DTBs).

**Read the logs of a crashed boot.** Boot back to a working kernel, then:

```bash
adb shell su -c 'cat /sys/fs/pstore/console-ramoops-0' > pstore.log
grep -iE 'init:|panic|execv|mount' pstore.log
```

**Check the running config.** `adb shell su -c 'zcat /proc/config.gz' > running.config`,
then run Docker's `check-config.sh` on the PC, not on the tablet.

## Docker & Podman

| Error | Fix |
|---|---|
| `mkdir /run/…: read-only file system` | A runtime hits a new `/run` path. Add a `mount -t tmpfs` for it in `start-docker.sh` / `podman-wrapper.sh` |
| `lookup registry-1.docker.io on [::1]:53` | No DNS. Run `prepare-rootfs-overrides.sh` (done at boot) |
| `x509: certificate signed by unknown authority` | No CA bundle. Same script. The source is `/data/local/tmp/ca-certificates.crt`, pushed from the PC |
| `controller pids is not available` | `cgroups = "disabled"` is missing or sits in `[engine]` instead of `[containers]` |
| `current system boot ID differs from cached boot ID` | `rm -rf /data/podman/run/* /data/podman/tmp/*` (the boot hook does it) |
| `unable to resolve HOME directory: user: unknown userid 0` | Call Podman through `podman-wrapper.sh` (it sets `HOME`/`USER`) |
| `failed to create 2048 locks in /libpod_lock` | `/dev/shm` missing. The wrapper mounts it |
| `no policy.json file found` | `/etc/containers/` is rebuilt at boot by `prepare-rootfs-overrides.sh`. Run it |
| Script kills itself when stopping dockerd | Never `pkill -f dockerd` in a script whose name contains "dockerd". Use `pidof` |
| `WARNING: No memory limit support` (and cpu, cpuset, io…) | Expected, see [no cgroup limits](how-it-works.md#why-no-cgroup-limits) |
| Containers not back after reboot | Check `/data/docker/boot.log` and `/data/podman/boot.log`. Containers need `--restart=always` or `unless-stopped` |

## Ubuntu, desktop & SSH

**apt in Termux: `Cannot run 'pkg' as root`.** Use the scripts. They run apt as
Termux's UID with `su -G 3003 -G 9997 <uid>` (inet + everybody groups).

**No DNS in the chroot / `resolv.conf` became a symlink.** It is protected with
`chattr +i`. To edit or delete it, run `chattr -i /etc/resolv.conf` first. The
uninstaller does this.

**`rm -rf /data/ubuntu` or re-extracting the rootfs fails.** Same immutable flag: `chattr -i /data/ubuntu/etc/resolv.conf`.

**`/data` is empty inside the chroot.** `/data` must be bind-mounted **before**
`chroot`. `enter-ubuntu.sh` does it in the right order.

**`apt install firefox` installs a snap stub.** The setup pins the Mozilla PPA.
Run `scripts/setup-x11.sh` again if the pin is gone.

**Firefox / Chrome / VS Code refuse to start as root.** `fake-root <app>`.

### Desktop

**Black screen in Termux:X11.** Open the Termux:X11 app *before* running
`start-desktop.sh`. If the X server does not start, the script tells you to
open the app and retry.

**Cinnamon / GNOME: black screen with only a cursor.** This cannot work: Mutter's
GL compositing does not present on Termux:X11 (tried: `XDG_SESSION_TYPE=x11`,
`LIBGL_ALWAYS_SOFTWARE=1`, `cinnamon2d`, `META_DEBUG_NO_COMPOSITE=1`). Use XFCE.

### SSH

- **Plain white prompt in ConnectBot, no colours:** you are in Ubuntu, but the shell is unconfigured. Run `scripts/setup-shell.sh`.

See the SSH table in [Root shell & SSH › troubleshooting](root-shell-and-ssh.md#11-troubleshooting).
The most common cases:

- **`Connection refused` after a reboot:** sshd waits for the first unlock. Unlock the tablet, then check `/data/local/tmp/ssh-boot.log`.
- **`Cannot connect to the Docker daemon at unix:///var/run/docker.sock` in SSH:** the `sshd_config` lacks `SetEnv DOCKER_HOST`. Run `scripts/setup-ssh.sh` again.
- **`/run/sshd must be owned by root…`:** old `start-ssh-inner.sh` (umask bug). Run `scripts/setup-ssh.sh` again.

---

[README](../README.md) · [Guide](guide/00-before-you-start.md) · [How it works](how-it-works.md) · **Troubleshooting** · [Root shell & SSH](root-shell-and-ssh.md) · [Download mirror](mirror.md) · [Histoire (FR)](histoire-du-projet.md)
