#!/bin/bash
# Samsung Galaxy Tab S7+ (SM-T970) — Container & Linux environment setup
# Master installer — runs sub-scripts based on user choices
#
# Prerequisites: OEM Unlock done, TWRP + Magisk installed, custom kernel flashed
# Usage: ./setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}*${NC} $1"; }
info() { echo -e "  ${DIM}$1${NC}"; }
fail() { echo -e "\n  ${RED}ERROR${NC} $1"; exit 1; }

# --- Pre-checks ---
echo -e "${BOLD}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║  Samsung Galaxy Tab S7+ (SM-T970)                   ║"
echo "  ║  Container & Linux Environment Setup                ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${CYAN}Checking prerequisites...${NC}"

# ADB connection
if ! adb devices 2>/dev/null | grep -q "device$"; then
    fail "No device found. Connect the tablet via USB and enable USB Debugging."
fi
ok "ADB connected"

# Magisk root
if ! adb shell </dev/null 'su -c "id"' 2>/dev/null | grep -q "uid=0"; then
    fail "Root not available. Install Magisk first (see docs/guide/02-root-twrp-magisk.md)."
fi
ok "Magisk root active"

# Custom kernel (check for user namespaces support)
if adb shell </dev/null 'su -c "cat /proc/sys/kernel/unprivileged_userns_clone"' 2>/dev/null | grep -q "1" || \
   adb shell </dev/null 'su -c "zcat /proc/config.gz 2>/dev/null | grep CONFIG_USER_NS=y"' 2>/dev/null | grep -q "y" || \
   adb shell </dev/null 'su -c "test -f /sys/fs/cgroup/cgroup.controllers && echo ok"' 2>/dev/null | grep -q "ok"; then
    ok "Custom kernel detected"
else
    echo -e "  ${YELLOW}WARNING${NC} Could not verify custom kernel. Containers may not work."
    echo -e "  ${DIM}If you haven't flashed the custom kernel yet, see docs/guide/03-build-kernel.md.${NC}"
    read -rp "  Continue anyway? [y/N]: " CONT
    [[ "$CONT" =~ ^[yY]$ ]] || exit 0
fi

echo ""

# --- Detect current state ---
HAS_DOCKER=false
HAS_PODMAN=false
HAS_TERMUX=false
HAS_UBUNTU=false
HAS_X11=false
HAS_SSH=false

adb shell </dev/null 'su -c "test -f /data/local/tmp/docker/dockerd && echo ok"' 2>/dev/null | grep -q ok && HAS_DOCKER=true
adb shell </dev/null 'su -c "test -f /data/local/tmp/podman/bin/podman && echo ok"' 2>/dev/null | grep -q ok && HAS_PODMAN=true
adb shell </dev/null 'su -c "test -f /data/data/com.termux/files/usr/bin/bash && echo ok"' 2>/dev/null | grep -q ok && HAS_TERMUX=true
adb shell </dev/null 'su -c "test -f /data/ubuntu/bin/bash && echo ok"' 2>/dev/null | grep -q ok && HAS_UBUNTU=true
adb shell </dev/null 'pm list packages 2>/dev/null' | grep -q "com.termux.x11" && HAS_X11=true
adb shell </dev/null 'su -c "test -f /data/local/tmp/start-ssh.sh && echo ok"' 2>/dev/null | grep -q ok && HAS_SSH=true

echo -e "${BOLD}Current state:${NC}"
$HAS_DOCKER && ok "Docker installed" || info "Docker not installed"
$HAS_PODMAN && ok "Podman installed" || info "Podman not installed"
$HAS_TERMUX && ok "Termux installed" || info "Termux not installed"
$HAS_UBUNTU && ok "Ubuntu chroot installed" || info "Ubuntu chroot not installed"
$HAS_X11    && ok "Termux:X11 installed" || info "X11 not installed"
$HAS_SSH    && ok "SSH server installed" || info "SSH server not installed"

echo ""
echo -e "${BOLD}What do you want to do?${NC}"
echo ""
echo "  1) Docker only"
echo "  2) Podman only"
echo "  3) Docker + Podman (both)"
echo "  4) Ubuntu dev environment (Termux + Ubuntu chroot)"
echo "  5) X11 graphical desktop (requires Ubuntu)"
echo "  6) SSH server in chroot (for ConnectBot/JuiceSSH — requires Ubuntu)"
echo "  7) Everything (Docker + Podman + Ubuntu + X11 + SSH)"
echo ""
echo -e "  ${RED}u) Uninstall components${NC}"
echo ""
echo -e "  ${DIM}Already-installed components will be skipped automatically.${NC}"
echo ""
read -rp "  Choice [1-7/u]: " MAIN_CHOICE

if [[ "$MAIN_CHOICE" =~ ^[uU]$ ]]; then
    exec "$SCRIPT_DIR/scripts/uninstall.sh"
fi

INSTALL_DOCKER=false
INSTALL_PODMAN=false
INSTALL_UBUNTU=false
INSTALL_X11=false
INSTALL_SSH=false

case "$MAIN_CHOICE" in
    1) INSTALL_DOCKER=true ;;
    2) INSTALL_PODMAN=true ;;
    3) INSTALL_DOCKER=true; INSTALL_PODMAN=true ;;
    4) INSTALL_UBUNTU=true ;;
    5) INSTALL_UBUNTU=true; INSTALL_X11=true ;;
    6) INSTALL_UBUNTU=true; INSTALL_SSH=true ;;
    7) INSTALL_DOCKER=true; INSTALL_PODMAN=true; INSTALL_UBUNTU=true; INSTALL_X11=true; INSTALL_SSH=true ;;
    *) fail "Invalid choice." ;;
esac

echo ""

# --- Docker ---
if $INSTALL_DOCKER; then
    if $HAS_DOCKER; then
        echo -e "${GREEN}${BOLD}Docker:${NC} ${DIM}already installed, skipping.${NC}"
    else
        echo -e "${CYAN}${BOLD}Installing Docker...${NC}"
        "$SCRIPT_DIR/scripts/docker/setup-docker.sh"
    fi
    echo ""
fi

# --- Podman ---
if $INSTALL_PODMAN; then
    if $HAS_PODMAN; then
        echo -e "${GREEN}${BOLD}Podman:${NC} ${DIM}already installed, skipping.${NC}"
    else
        echo -e "${CYAN}${BOLD}Installing Podman...${NC}"
        "$SCRIPT_DIR/scripts/podman/setup-podman.sh"
    fi
    echo ""
fi

# --- First run (rootfs + daemons) ---
if $INSTALL_DOCKER || $INSTALL_PODMAN; then
    echo -e "${CYAN}${BOLD}Preparing runtime environment...${NC}"
    adb shell </dev/null 'su -c /data/local/tmp/prepare-rootfs-overrides.sh' 2>&1

    if $INSTALL_DOCKER || $HAS_DOCKER; then
        if ! adb shell </dev/null 'su -c "pidof dockerd"' >/dev/null 2>&1; then
            echo "  Starting Docker daemon..."
            adb shell </dev/null 'su -c /data/local/tmp/start-docker.sh' 2>&1
        fi
    fi
    echo ""

    # Quick validation
    echo -e "${CYAN}${BOLD}Validating...${NC}"
    if $INSTALL_DOCKER || $HAS_DOCKER; then
        if adb shell </dev/null 'su -c "/data/local/tmp/docker/docker -H unix:///data/docker/docker.sock run --rm --net=host hello-world"' 2>&1 | grep -q "Hello from Docker"; then
            ok "Docker: hello-world OK"
        else
            echo -e "  ${YELLOW}WARNING${NC} Docker hello-world failed. Check logs: adb shell </dev/null 'su -c cat /data/docker/dockerd.log'"
        fi
    fi
    if $INSTALL_PODMAN || $HAS_PODMAN; then
        if adb shell </dev/null 'su -c "/data/local/tmp/podman/podman-wrapper.sh run --rm --net=host hello-world"' 2>&1 | grep -q "Hello from Docker"; then
            ok "Podman: hello-world OK"
        else
            echo -e "  ${YELLOW}WARNING${NC} Podman hello-world failed."
        fi
    fi
    echo ""
fi

# --- Ubuntu ---
if $INSTALL_UBUNTU; then
    if $HAS_UBUNTU && $HAS_TERMUX; then
        echo -e "${GREEN}${BOLD}Ubuntu:${NC} ${DIM}already installed, skipping.${NC}"
    else
        echo -e "${CYAN}${BOLD}Installing Ubuntu dev environment...${NC}"
        "$SCRIPT_DIR/scripts/setup-ubuntu.sh"
    fi
    echo ""
fi

# --- X11 ---
if $INSTALL_X11; then
    echo -e "${CYAN}${BOLD}Setting up X11 graphical environment...${NC}"
    "$SCRIPT_DIR/scripts/setup-x11.sh"
    echo ""
fi

# --- SSH ---
if $INSTALL_SSH; then
    if $HAS_SSH; then
        echo -e "${GREEN}${BOLD}SSH server:${NC} ${DIM}already installed, skipping.${NC}"
    else
        echo -e "${CYAN}${BOLD}Setting up SSH server in chroot...${NC}"
        "$SCRIPT_DIR/scripts/setup-ssh.sh"
    fi
    echo ""
fi

# --- Summary ---
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║${NC}  ${GREEN}Setup complete!${NC}                                     ${BOLD}║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

if $INSTALL_DOCKER || $HAS_DOCKER; then
    echo -e "${BOLD}Docker:${NC}"
    echo -e "  ${CYAN}adb shell </dev/null 'su -c \"/data/local/tmp/docker/docker -H unix:///data/docker/docker.sock ps\"'${NC}"
    echo ""
fi

if $INSTALL_PODMAN || $HAS_PODMAN; then
    echo -e "${BOLD}Podman:${NC}"
    echo -e "  ${CYAN}adb shell </dev/null 'su -c \"/data/local/tmp/podman/podman-wrapper.sh ps\"'${NC}"
    echo ""
fi

if $HAS_UBUNTU || $INSTALL_UBUNTU; then
    echo -e "${BOLD}Ubuntu shell (with docker/podman CLI):${NC}"
    echo -e "  ${CYAN}adb shell -t 'su -c /data/local/tmp/enter-ubuntu.sh'${NC}"
    echo ""
fi

if $HAS_X11 || $INSTALL_X11; then
    echo -e "${BOLD}X11 Desktop:${NC}"
    echo "  1. Open Termux:X11 app on the tablet"
    echo -e "  2. ${CYAN}adb shell -t 'su -c /data/local/tmp/start-desktop.sh'${NC}"
    echo ""
fi

if $HAS_SSH || $INSTALL_SSH; then
    echo -e "${BOLD}SSH server (chroot):${NC}"
    echo -e "  Running now and at every boot. Restart: ${CYAN}adb shell \"su -c 'setsid nohup /data/local/tmp/start-ssh.sh >> /data/local/tmp/ssh-boot.log 2>&1 < /dev/null &'\"${NC}"
    echo -e "  Connect from Android (ConnectBot): ${CYAN}root@127.0.0.1:2222${NC}"
    echo -e "  Key: ${CYAN}~/.ssh/sm-t970_ed25519${NC}"
    echo ""
fi

echo -e "${DIM}Everything auto-starts on reboot via Magisk service.d${NC}"
