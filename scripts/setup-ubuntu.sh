#!/bin/bash
# Install Termux + Ubuntu chroot on SM-T970
# Fully automated — no manual Termux commands needed
# Usage: ./scripts/setup-ubuntu.sh
# Requires: ADB connected, Magisk root, PC internet

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TERMUX_VERSION="1022"
TERMUX_APK="$REPO_ROOT/downloads/termux_${TERMUX_VERSION}.apk"

UBUNTU_ROOTFS="$REPO_ROOT/downloads/ubuntu-base-arm64.tar.gz"   # Ubuntu 24.04.4 base

# Pinned downloads (official URL first, project mirror as fallback, SHA-256 checked)
# shellcheck source=lib/fetch.sh
. "$SCRIPT_DIR/lib/fetch.sh"

UBUNTU_PATH=/data/ubuntu
TERMUX_PREFIX=/data/data/com.termux/files/usr
ENTER_UBUNTU=/data/local/tmp/enter-ubuntu.sh

# Colors
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
RED='\033[0;31m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

step() { echo -e "\n${CYAN}${BOLD}[$1]${NC} $2"; }
ok()   { echo -e "  ${GREEN}OK${NC} $1"; }
skip() { echo -e "  ${DIM}SKIP${NC} $1 ${DIM}(already done)${NC}"; }
warn() { echo -e "  ${YELLOW}WARNING${NC} $1"; }
fail() { echo -e "  ${RED}ERROR${NC} $1"; exit 1; }

# Run a Termux apt command via ADB as Termux's UID with network groups
# Android restricts network by UID/groups — -G 3003 (inet) -G 9997 (everybody)
termux_pkg() {
    local TUID
    TUID=$(adb shell </dev/null 'su -c "stat -c %u /data/data/com.termux"' 2>/dev/null | tr -d '\r')
    [ -z "$TUID" ] && fail "Cannot determine Termux UID"
    adb shell </dev/null "su -G 3003 -G 9997 $TUID -c '
        export PREFIX=$TERMUX_PREFIX
        export HOME=/data/data/com.termux/files/home
        export TMPDIR=\$PREFIX/tmp
        export PATH=\$PREFIX/bin:\$PREFIX/bin/applets
        export LD_LIBRARY_PATH=\$PREFIX/lib
        apt $*
    '" 2>&1
}

echo -e "${BOLD}=== Ubuntu dev environment setup for SM-T970 ===${NC}"

# --- Step 1: Termux APK ---
step "1/7" "Termux app"

if adb shell </dev/null 'pm list packages 2>/dev/null' | grep -qE "^package:com\.termux\s*$"; then
    skip "Termux already installed"
else
    fetch_artifact "termux_${TERMUX_VERSION}.apk" || fail "Termux APK unavailable"
    echo "  Installing via ADB..."
    adb install "$TERMUX_APK"
    ok "Termux installed"
fi

# --- Step 2: Bootstrap Termux ---
step "2/7" "Termux bootstrap"

if adb shell </dev/null "su -c \"test -f $TERMUX_PREFIX/bin/bash && echo ok\"" 2>/dev/null | grep -q ok; then
    skip "Termux already bootstrapped"
else
    echo "  Opening Termux on the tablet..."
    adb shell </dev/null "am start -n com.termux/.app.TermuxActivity" 2>/dev/null || true
    echo "  Waiting for Termux to bootstrap (first launch)..."
    for _ in $(seq 1 60); do
        if adb shell </dev/null "su -c \"test -f $TERMUX_PREFIX/bin/bash && echo ok\"" 2>/dev/null | grep -q ok; then
            break
        fi
        sleep 2
    done
    if ! adb shell </dev/null "su -c \"test -f $TERMUX_PREFIX/bin/bash && echo ok\"" 2>/dev/null | grep -q ok; then
        fail "Termux bootstrap timed out. Open Termux manually and wait for the \$ prompt, then rerun."
    fi
    ok "Termux bootstrapped"
fi

# --- Step 3: Install mount-utils in Termux ---
step "3/7" "Termux mount-utils"

if adb shell </dev/null "su -c \"test -f $TERMUX_PREFIX/bin/mount && echo ok\"" 2>/dev/null | grep -q ok; then
    skip "mount-utils already installed"
else
    # Fix dpkg directory ownership (su creates them as root on fresh install)
    TUID=$(adb shell </dev/null 'su -c "stat -c %u /data/data/com.termux"' 2>/dev/null | tr -d '\r')
    adb shell </dev/null "su -c 'chown -R $TUID:$TUID $TERMUX_PREFIX/var/lib/dpkg $TERMUX_PREFIX/var/cache/apt $TERMUX_PREFIX/var/log/apt 2>/dev/null'" 2>/dev/null || true
    echo "  Installing mount-utils via Termux apt..."
    termux_pkg update -qq 2>/dev/null || true
    termux_pkg install -y mount-utils 2>&1 | tail -3 || true
    if adb shell </dev/null "su -c \"test -f $TERMUX_PREFIX/bin/mount && echo ok\"" 2>/dev/null | grep -q ok; then
        ok "mount-utils installed"
    else
        fail "mount-utils installation failed"
    fi
fi
# unshare comes from util-linux, part of the Termux bootstrap (not mount-utils)
if ! adb shell </dev/null "su -c \"test -x $TERMUX_PREFIX/bin/unshare && echo ok\"" 2>/dev/null | grep -q ok; then
    fail "$TERMUX_PREFIX/bin/unshare missing (Termux package util-linux). Install it in Termux: pkg install util-linux"
fi
ok "unshare available"

# --- Step 4: Ubuntu rootfs ---
step "4/7" "Ubuntu rootfs"

if adb shell </dev/null "su -c \"test -f $UBUNTU_PATH/bin/bash && echo ok\"" 2>/dev/null | grep -q ok; then
    skip "Ubuntu rootfs already installed at $UBUNTU_PATH"
else
    fetch_artifact ubuntu-base-arm64.tar.gz || fail "Ubuntu base rootfs unavailable"

    echo "  Pushing rootfs to tablet..."
    adb push "$UBUNTU_ROOTFS" /data/local/tmp/ubuntu-rootfs.tar.gz

    echo "  Extracting (this takes ~30 seconds)..."
    adb shell </dev/null "su -c \"
        mkdir -p $UBUNTU_PATH
        chattr -i $UBUNTU_PATH/etc/resolv.conf 2>/dev/null
        cd $UBUNTU_PATH
        tar xzf /data/local/tmp/ubuntu-rootfs.tar.gz
        rm -f /data/local/tmp/ubuntu-rootfs.tar.gz
    \"" 2>&1

    # DNS: remove systemd-resolved symlink, write real resolv.conf, protect it
    adb shell </dev/null "su -c \"
        rm -f $UBUNTU_PATH/etc/resolv.conf
        printf 'nameserver 8.8.8.8\nnameserver 8.8.4.4\n' > $UBUNTU_PATH/etc/resolv.conf
        chattr +i $UBUNTU_PATH/etc/resolv.conf 2>/dev/null
    \""

    if adb shell </dev/null "su -c \"test -f $UBUNTU_PATH/bin/bash && echo ok\"" 2>/dev/null | grep -q ok; then
        ok "Ubuntu rootfs extracted to $UBUNTU_PATH"
    else
        fail "Ubuntu rootfs extraction failed"
    fi
fi

# --- Step 5: Push chroot script ---
step "5/7" "Pushing enter-ubuntu.sh"

adb push "$SCRIPT_DIR/enter-ubuntu.sh" /data/local/tmp/enter-ubuntu.sh
adb shell </dev/null 'su -c "chmod +x /data/local/tmp/enter-ubuntu.sh"'
ok "enter-ubuntu.sh pushed"

# --- Step 6: Bootstrap apt + configure for chroot ---
step "6/7" "Configuring Ubuntu for chroot use"

# 6a: Bootstrap gpgv if missing (ubuntu-base may lack it)
if adb shell </dev/null "su -c \"$ENTER_UBUNTU dpkg -l gpgv 2>/dev/null\"" | grep -q "^ii"; then
    echo -e "  ${DIM}gpgv present${NC}"
else
    echo "  Installing gpgv..."
    adb shell </dev/null "su -c \"$ENTER_UBUNTU bash -c 'export DEBIAN_FRONTEND=noninteractive; apt -o Acquire::AllowInsecureRepositories=true update -qq 2>&1 && apt --allow-unauthenticated install -y gpgv 2>&1'\"" 2>&1 | tail -3 || true
fi

# 6b: Run apt update
echo "  Running apt update..."
adb shell </dev/null "su -c \"$ENTER_UBUNTU bash -c 'export DEBIAN_FRONTEND=noninteractive; apt update -qq 2>&1'\"" 2>&1 | tail -3 || true

# 6c: Block snap (useless in chroot) and add Mozilla PPA for real Firefox .deb
echo "  Blocking snap + adding Mozilla APT repo for Firefox..."
adb shell </dev/null "su -c \"$ENTER_UBUNTU bash -c '
    export DEBIAN_FRONTEND=noninteractive

    # Block snap — it cannot work in a chroot
    if [ ! -f /etc/apt/preferences.d/no-snap.pref ]; then
        mkdir -p /etc/apt/preferences.d
        cat > /etc/apt/preferences.d/no-snap.pref << SNAPEOF
Package: snapd
Pin: release a=*
Pin-Priority: -10
SNAPEOF
    fi

    # Remove snap-based firefox transitional package if present
    apt remove -y firefox 2>/dev/null || true

    # Add Mozilla official APT repo (real .deb Firefox)
    if [ ! -f /etc/apt/sources.list.d/mozilla.list ]; then
        apt install -y software-properties-common 2>&1 | tail -3
        add-apt-repository -y ppa:mozillateam/ppa 2>&1 | tail -3

        # Prioritize PPA Firefox over snap transitional package
        cat > /etc/apt/preferences.d/mozilla-firefox.pref << FFEOF
Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001

Package: firefox
Pin: version 1:1snap*
Pin-Priority: -1
FFEOF
        apt update -qq 2>&1 | tail -3
    fi
'\"" 2>&1

ok "Ubuntu configured (snap blocked, Mozilla PPA added)"

# 6d: root shell configuration (coloured prompt, completion, DOCKER_HOST)
"$SCRIPT_DIR/setup-shell.sh"

# --- Step 7: Verify ---
step "7/7" "Verifying Ubuntu chroot"

VERIFY=$(adb shell </dev/null "su -c \"$ENTER_UBUNTU cat /etc/os-release\"" 2>/dev/null | head -3)
if [ -n "$VERIFY" ]; then
    echo "$VERIFY" | sed 's/^/  /'
    ok "Ubuntu chroot works"
else
    warn "Could not verify (try manually: adb shell -t 'su -c /data/local/tmp/enter-ubuntu.sh')"
fi

# Verify apt works
if adb shell </dev/null "su -c \"$ENTER_UBUNTU apt list --installed 2>/dev/null\"" | grep -q "gpgv"; then
    ok "apt works (gpgv verified)"
else
    warn "apt may not be fully functional"
fi

echo ""
echo -e "${GREEN}${BOLD}Ubuntu setup complete.${NC}"
echo ""
echo -e "${BOLD}Usage:${NC}"
echo -e "  ${CYAN}adb shell -t 'su -c /data/local/tmp/enter-ubuntu.sh'${NC}"
echo ""
echo -e "${BOLD}Install Firefox:${NC}"
echo -e "  ${CYAN}apt install -y firefox${NC}  ${DIM}(real .deb, not snap)${NC}"
echo ""
echo "Inside the chroot, docker and podman CLIs are available if installed."
