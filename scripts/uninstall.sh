#!/bin/bash
# Uninstall script for SM-T970 container & Linux environment
# Removes components installed by setup.sh and sub-scripts
# Usage: ./scripts/uninstall.sh           (interactive)
#        ./scripts/uninstall.sh 6 --yes   (non-interactive: choice + auto-confirm)
# Requires: ADB connected, Magisk root

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}OK${NC} $1"; }
info() { echo -e "  ${DIM}$1${NC}"; }
warn() { echo -e "  ${YELLOW}WARNING${NC} $1"; }
fail() { echo -e "  ${RED}ERROR${NC} $1"; exit 1; }

CLI_CHOICE="${1:-}"
CLI_YES=false
[[ "${2:-}" == "--yes" ]] && CLI_YES=true

echo -e "${BOLD}"
echo "  +------------------------------------------------------+"
echo "  |  Samsung Galaxy Tab S7+ (SM-T970)                    |"
echo "  |  Uninstall — Container & Linux Environment           |"
echo "  +------------------------------------------------------+"
echo -e "${NC}"

# --- Pre-checks ---
if ! adb devices 2>/dev/null | grep -q "device$"; then
    fail "No device found. Connect the tablet via USB."
fi

if ! adb shell </dev/null 'su -c "id"' 2>/dev/null | grep -q "uid=0"; then
    fail "Root not available."
fi

# --- Detect current state ---
HAS_DOCKER=false
HAS_PODMAN=false
HAS_UBUNTU=false
HAS_X11=false
HAS_SSH=false
HAS_TERMUX=false

adb shell </dev/null 'su -c "test -f /data/local/tmp/docker/dockerd && echo ok"' 2>/dev/null | grep -q ok && HAS_DOCKER=true
adb shell </dev/null 'su -c "test -f /data/local/tmp/podman/bin/podman && echo ok"' 2>/dev/null | grep -q ok && HAS_PODMAN=true
adb shell </dev/null 'su -c "test -f /data/ubuntu/bin/bash && echo ok"' 2>/dev/null | grep -q ok && HAS_UBUNTU=true
adb shell </dev/null 'pm list packages 2>/dev/null' | grep -q "com.termux.x11" && HAS_X11=true
adb shell </dev/null 'su -c "test -f /data/local/tmp/start-ssh.sh && echo ok"' 2>/dev/null | grep -q ok && HAS_SSH=true
adb shell </dev/null 'pm list packages 2>/dev/null' | grep -qE "^package:com\.termux\s*$" && HAS_TERMUX=true

echo -e "${BOLD}Currently installed:${NC}"
$HAS_DOCKER && ok "Docker" || info "Docker: not installed"
$HAS_PODMAN && ok "Podman" || info "Podman: not installed"
$HAS_UBUNTU && ok "Ubuntu chroot" || info "Ubuntu chroot: not installed"
$HAS_X11    && ok "Termux:X11" || info "Termux:X11: not installed"
$HAS_SSH    && ok "SSH server (chroot)" || info "SSH server: not installed"
$HAS_TERMUX && ok "Termux" || info "Termux: not installed"

echo ""
echo -e "${BOLD}What do you want to uninstall?${NC}"
echo ""
echo "  1) Docker only"
echo "  2) Podman only"
echo "  3) Docker + Podman (both)"
echo "  4) X11 desktop environment only"
echo "  5) SSH server only"
echo "  6) Ubuntu chroot only"
echo "  7) Termux + Ubuntu + X11 + SSH (all Linux env)"
echo "  8) Everything (Docker + Podman + Termux + Ubuntu + X11 + SSH)"
echo ""
echo -e "  ${DIM}Kernel and Magisk are NOT affected.${NC}"
echo ""
if [ -n "$CLI_CHOICE" ]; then
    CHOICE="$CLI_CHOICE"
    echo -e "  Choice: $CHOICE"
else
    read -rp "  Choice [1-8]: " CHOICE
fi

RM_DOCKER=false
RM_PODMAN=false
RM_X11=false
RM_SSH=false
RM_UBUNTU=false
RM_TERMUX=false

case "$CHOICE" in
    1) RM_DOCKER=true ;;
    2) RM_PODMAN=true ;;
    3) RM_DOCKER=true; RM_PODMAN=true ;;
    4) RM_X11=true ;;
    5) RM_SSH=true ;;
    6) RM_UBUNTU=true ;;
    7) RM_TERMUX=true; RM_UBUNTU=true; RM_X11=true; RM_SSH=true ;;
    8) RM_DOCKER=true; RM_PODMAN=true; RM_TERMUX=true; RM_UBUNTU=true; RM_X11=true; RM_SSH=true ;;
    *) fail "Invalid choice." ;;
esac

# Confirm
echo ""
COMPONENTS=""
$RM_DOCKER && COMPONENTS="$COMPONENTS Docker"
$RM_PODMAN && COMPONENTS="$COMPONENTS Podman"
$RM_X11    && COMPONENTS="$COMPONENTS X11"
$RM_SSH    && COMPONENTS="$COMPONENTS SSH"
$RM_UBUNTU && COMPONENTS="$COMPONENTS Ubuntu"
$RM_TERMUX && COMPONENTS="$COMPONENTS Termux"
echo -e "${RED}${BOLD}Will uninstall:${NC}${RED}$COMPONENTS${NC}"
echo -e "${DIM}This will stop running services and delete data.${NC}"
if $CLI_YES; then
    echo "  --yes: auto-confirmed"
    CONFIRM="y"
else
    read -rp "  Are you sure? [y/N]: " CONFIRM
fi
[[ "$CONFIRM" =~ ^[yY]$ ]] || { echo "Cancelled."; exit 0; }

echo ""

# ===== Docker =====
if $RM_DOCKER && $HAS_DOCKER; then
    echo -e "${CYAN}${BOLD}Uninstalling Docker...${NC}"

    # Stop dockerd
    echo "  Stopping dockerd..."
    adb shell </dev/null 'su -c "
        pid=\$(pidof dockerd 2>/dev/null) && kill \$pid 2>/dev/null
        sleep 2
        pid=\$(pidof containerd 2>/dev/null) && kill \$pid 2>/dev/null
    "' 2>/dev/null || true

    # Stop all containers first (they'll be removed with /data/docker)
    adb shell </dev/null 'su -c "
        /data/local/tmp/docker/docker -H unix:///data/docker/docker.sock kill \$(/data/local/tmp/docker/docker -H unix:///data/docker/docker.sock ps -q) 2>/dev/null
    "' 2>/dev/null || true

    # Remove binaries
    echo "  Removing Docker binaries..."
    adb shell </dev/null 'su -c "rm -rf /data/local/tmp/docker"'

    # Remove data
    echo "  Removing /data/docker (images, containers, volumes)..."
    adb shell </dev/null 'su -c "rm -rf /data/docker"'

    # Remove Magisk boot service
    echo "  Removing Magisk boot service..."
    adb shell </dev/null 'su -c "rm -f /data/adb/service.d/docker-boot.sh"'

    # Cleanup temp files
    adb shell </dev/null 'su -c "rm -f /data/local/tmp/daemon.json /data/local/tmp/containerd-config.toml /sdcard/docker-boot.sh"' 2>/dev/null || true

    ok "Docker uninstalled"
    echo ""
fi

# ===== Podman =====
if $RM_PODMAN && $HAS_PODMAN; then
    echo -e "${CYAN}${BOLD}Uninstalling Podman...${NC}"

    # Kill any running podman processes
    echo "  Stopping Podman processes..."
    adb shell </dev/null 'su -c "
        killall conmon crun 2>/dev/null
        killall podman 2>/dev/null
    "' 2>/dev/null || true

    # Remove binaries
    echo "  Removing Podman binaries..."
    adb shell </dev/null 'su -c "rm -rf /data/local/tmp/podman"'

    # Remove data
    echo "  Removing /data/podman (storage, configs)..."
    adb shell </dev/null 'su -c "rm -rf /data/podman"'

    # Remove /etc/containers (if we created it)
    adb shell </dev/null 'su -c "
        mount -o rw,remount / 2>/dev/null
        rm -rf /etc/containers 2>/dev/null
        mount -o ro,remount / 2>/dev/null
    "' 2>/dev/null || true

    # Remove Magisk boot service
    echo "  Removing Magisk boot service..."
    adb shell </dev/null 'su -c "rm -f /data/adb/service.d/podman-boot.sh"'

    # Cleanup temp files
    adb shell </dev/null 'su -c "rm -f /data/local/tmp/containers.conf /data/local/tmp/storage.conf /data/local/tmp/registries.conf /data/local/tmp/policy.json /sdcard/podman-boot.sh"' 2>/dev/null || true

    ok "Podman uninstalled"
    echo ""
fi

# ===== X11 desktop =====
if $RM_X11; then
    echo -e "${CYAN}${BOLD}Uninstalling X11 desktop...${NC}"

    # Kill desktop session
    echo "  Stopping desktop session..."
    adb shell </dev/null 'su -c "
        killall xfce4-session xfwm4 xfdesktop xfce4-panel cinnamon cinnamon-session socat 2>/dev/null
    "' 2>/dev/null || true

    # Remove desktop packages from Ubuntu chroot (if chroot exists and not being removed)
    if $HAS_UBUNTU && ! $RM_UBUNTU; then
        echo "  Removing desktop packages from Ubuntu chroot..."
        adb shell </dev/null "su -c \"/data/local/tmp/enter-ubuntu.sh bash -c 'export DEBIAN_FRONTEND=noninteractive; apt remove -y --autoremove xfce4 xfce4-terminal cinnamon cinnamon-session dbus-x11 xterm 2>/dev/null; apt clean'\"" 2>&1 | tail -3
    fi

    # Remove start-desktop scripts
    echo "  Removing desktop scripts..."
    adb shell </dev/null 'su -c "rm -f /data/local/tmp/start-desktop.sh /data/local/tmp/start-desktop-inner.sh"'

    # Uninstall Termux:X11 app
    if $HAS_X11; then
        echo "  Uninstalling Termux:X11 app..."
        adb uninstall com.termux.x11 2>/dev/null || true
    fi

    ok "X11 desktop uninstalled"
    echo ""
fi

# ===== SSH server =====
if $RM_SSH; then
    echo -e "${CYAN}${BOLD}Uninstalling SSH server...${NC}"

    # Kill sshd inside chroot
    echo "  Stopping sshd..."
    adb shell </dev/null 'su -c "
        for pid in $(pidof sshd 2>/dev/null); do
            root=$(readlink /proc/$pid/root 2>/dev/null)
            case \"$root\" in
                /data/ubuntu*) kill $pid 2>/dev/null ;;
            esac
        done
    "' 2>/dev/null || true

    # Remove openssh-server from chroot (if chroot exists and not being removed)
    if $HAS_UBUNTU && ! $RM_UBUNTU; then
        echo "  Removing openssh-server from Ubuntu chroot..."
        adb shell </dev/null "su -c \"/data/local/tmp/enter-ubuntu.sh bash -c 'export DEBIAN_FRONTEND=noninteractive; apt remove -y --autoremove openssh-server 2>/dev/null; apt clean'\"" 2>&1 | tail -3
        # Clean chroot ssh state
        adb shell </dev/null 'su -c "
            rm -rf /data/ubuntu/etc/ssh
            rm -rf /data/ubuntu/root/.ssh
            rm -rf /data/ubuntu/run/sshd
        "' 2>/dev/null || true
    fi

    # Remove start-ssh scripts
    echo "  Removing start-ssh scripts..."
    adb shell </dev/null 'su -c "rm -f /data/local/tmp/start-ssh.sh /data/local/tmp/start-ssh-inner.sh /data/local/tmp/ssh-boot.log"'

    # Remove Magisk boot service
    echo "  Removing Magisk boot service..."
    adb shell </dev/null 'su -c "rm -f /data/adb/service.d/ssh-boot.sh"'

    ok "SSH server uninstalled"
    echo -e "  ${DIM}Note: the PC-side keypair at \$HOME/.ssh/sm-t970_ed25519 is NOT touched.${NC}"
    echo ""
fi

# ===== Ubuntu chroot =====
if $RM_UBUNTU && $HAS_UBUNTU; then
    echo -e "${CYAN}${BOLD}Uninstalling Ubuntu chroot...${NC}"

    # Kill any processes in the chroot
    echo "  Stopping chroot processes..."
    adb shell </dev/null 'su -c "
        killall xfce4-session xfwm4 xfdesktop xfce4-panel cinnamon socat sshd 2>/dev/null
    "' 2>/dev/null || true

    echo "  Removing Ubuntu rootfs (/data/ubuntu)..."
    adb shell </dev/null 'su -c "chattr -i /data/ubuntu/etc/resolv.conf 2>/dev/null; rm -rf /data/ubuntu"'

    # Remove helper scripts
    echo "  Removing helper scripts..."
    adb shell </dev/null 'su -c "rm -f /data/local/tmp/enter-ubuntu.sh /data/local/tmp/start-desktop.sh /data/local/tmp/start-desktop-inner.sh /data/local/tmp/start-ssh.sh /data/local/tmp/start-ssh-inner.sh /data/local/tmp/ssh-boot.log /data/local/tmp/setup-user.sh /data/local/tmp/fix-xfce.sh /data/local/tmp/test-x11.sh /data/local/tmp/test-x11-v2.sh /data/local/tmp/ubuntu-cmd.tmp"'

    # Remove Magisk SSH boot service (if present) — sshd can't start without chroot
    adb shell </dev/null 'su -c "rm -f /data/adb/service.d/ssh-boot.sh"' 2>/dev/null || true

    ok "Ubuntu chroot uninstalled"
    echo ""
fi

# ===== Termux =====
if $RM_TERMUX && $HAS_TERMUX; then
    echo -e "${CYAN}${BOLD}Uninstalling Termux...${NC}"

    echo "  Uninstalling Termux app (this removes all Termux data)..."
    adb uninstall com.termux 2>/dev/null || true

    # The app data at /data/data/com.termux is auto-removed by Android
    # Ubuntu rootfs at /data/ubuntu is NOT removed here (use option 5/6/7)

    ok "Termux uninstalled"
    echo ""
fi

# ===== Shared cleanup =====
echo -e "${CYAN}${BOLD}Cleaning up shared files...${NC}"

# Remove mount-cgroups and prepare-rootfs-overrides only if both Docker and Podman are gone
if ($RM_DOCKER || ! $HAS_DOCKER) && ($RM_PODMAN || ! $HAS_PODMAN); then
    adb shell </dev/null 'su -c "rm -f /data/local/tmp/mount-cgroups.sh /data/local/tmp/prepare-rootfs-overrides.sh /data/local/tmp/ca-certificates.crt /sdcard/ca-certificates.crt"' 2>/dev/null || true
    ok "Shared helper scripts removed"
fi

# Remove empty service.d if no services left
adb shell </dev/null 'su -c "
    rmdir /data/adb/service.d 2>/dev/null
"' 2>/dev/null || true

echo ""
echo -e "${BOLD}+------------------------------------------------------+${NC}"
echo -e "${BOLD}|${NC}  ${GREEN}Uninstall complete.${NC}                                  ${BOLD}|${NC}"
echo -e "${BOLD}+------------------------------------------------------+${NC}"
echo ""
echo -e "${DIM}Kernel and Magisk are untouched.${NC}"
echo -e "${DIM}To reinstall: ./setup.sh${NC}"
