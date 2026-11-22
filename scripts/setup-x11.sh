#!/bin/bash
# Install Termux:X11 + XFCE desktop environment on SM-T970
# Fully automated — no manual Termux commands needed
# Usage: ./scripts/setup-x11.sh
# Requires: Termux + Ubuntu chroot already installed (setup-ubuntu.sh)
#           PC internet (for APK download) + tablet Wi-Fi (for apt packages)
#
# Note: Only XFCE is supported. Compositing-based DEs (Cinnamon, GNOME Shell)
# do not work with Termux:X11 — their Mutter compositor renders to an offscreen
# GL buffer whose presentation is incompatible with Termux:X11's X server.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TERMUX_X11_APK="$REPO_ROOT/downloads/termux-x11-arm64.apk"
# shellcheck source=lib/fetch.sh
. "$SCRIPT_DIR/lib/fetch.sh"

TERMUX_PREFIX=/data/data/com.termux/files/usr
ENTER_UBUNTU=/data/local/tmp/enter-ubuntu.sh

DE_PACKAGES="xfce4 xfce4-terminal dbus-x11 xterm socat gcc file"
DE_CHECK="xfce4-session"

# Colors
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
RED='\033[0;31m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

step() { echo -e "\n${CYAN}${BOLD}[$1]${NC} $2"; }
ok()   { echo -e "  ${GREEN}OK${NC} $1"; }
skip() { echo -e "  ${DIM}SKIP${NC} $1 ${DIM}(already done)${NC}"; }
warn() { echo -e "  ${YELLOW}WARNING${NC} $1"; }
fail() { echo -e "  ${RED}ERROR${NC} $1"; exit 1; }

# Run a Termux apt command via ADB as Termux's UID with network groups
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

echo -e "${BOLD}=== XFCE X11 desktop setup for SM-T970 ===${NC}"

# --- Pre-checks ---
if ! adb shell </dev/null 'su -c "test -f /data/ubuntu/bin/bash && echo ok"' 2>/dev/null | grep -q ok; then
    fail "Ubuntu chroot not found. Run setup-ubuntu.sh first."
fi

# --- Step 1: Termux:X11 APK ---
step "1/5" "Termux:X11 app"

if adb shell </dev/null 'pm list packages 2>/dev/null' | grep -q "com.termux.x11"; then
    skip "Termux:X11 app already installed"
else
    # pinned build: the upstream "nightly" URL moves, so this usually comes from the mirror
    fetch_artifact termux-x11-arm64.apk || fail "Termux:X11 APK unavailable"
    echo "  Installing via ADB..."
    adb install "$TERMUX_X11_APK"
    ok "Termux:X11 app installed"
fi

# --- Step 2: termux-x11 server package (automated) ---
step "2/5" "termux-x11 server package"

if adb shell </dev/null "su -c \"test -f $TERMUX_PREFIX/bin/termux-x11 && echo ok\"" 2>/dev/null | grep -q ok; then
    skip "termux-x11 package already installed"
else
    echo "  Adding x11-repo to Termux..."
    termux_pkg install -y x11-repo 2>/dev/null | tail -3
    echo "  Installing termux-x11-nightly..."
    termux_pkg install -y termux-x11-nightly | tail -3

    if adb shell </dev/null "su -c \"test -f $TERMUX_PREFIX/bin/termux-x11 && echo ok\"" 2>/dev/null | grep -q ok; then
        ok "termux-x11 installed"
    else
        fail "termux-x11 installation failed"
    fi
fi

# --- Step 3: XFCE desktop environment ---
step "3/5" "XFCE desktop environment"

if adb shell </dev/null "su -c '$ENTER_UBUNTU which $DE_CHECK'" 2>/dev/null | grep -q "$DE_CHECK"; then
    skip "XFCE already installed in Ubuntu chroot"
else
    echo "  Installing XFCE + tools in Ubuntu chroot..."
    echo -e "  ${DIM}This will take several minutes (~300 MB download).${NC}"
    echo ""
    adb shell </dev/null "su -c \"$ENTER_UBUNTU bash -c 'export DEBIAN_FRONTEND=noninteractive; apt update -qq && apt install -y $DE_PACKAGES'\"" 2>&1 | tail -20
    echo ""

    if adb shell </dev/null "su -c '$ENTER_UBUNTU which $DE_CHECK'" 2>/dev/null | grep -q "$DE_CHECK"; then
        ok "XFCE installed"
    else
        fail "XFCE installation failed"
    fi
fi

# --- Step 4: Disable broken chroot services ---
step "4/5" "Disabling PackageKit + polkit + light-locker"

adb shell </dev/null "su -c \"$ENTER_UBUNTU bash -c '
    # PackageKit: broken in chroot, spams D-Bus errors
    chmod -x /usr/libexec/packagekitd 2>/dev/null
    mkdir -p /etc/PackageKit && echo Enabled=false > /etc/PackageKit/PackageKit.conf

    # Polkit: fix setuid helper permissions
    chmod 4755 /usr/lib/polkit-1/polkit-agent-helper-1 2>/dev/null

    # Disable autostart entries that crash in chroot
    for f in polkit-gnome-authentication-agent-1 light-locker xiccd; do
        if [ -f /etc/xdg/autostart/\$f.desktop ]; then
            grep -q \"Hidden=true\" /etc/xdg/autostart/\$f.desktop 2>/dev/null || echo \"Hidden=true\" >> /etc/xdg/autostart/\$f.desktop
        fi
    done
'\"" 2>&1
ok "Broken services disabled"

# --- Step 5: Push start scripts ---
step "5/5" "Pushing start scripts"

chmod +x "$SCRIPT_DIR/start-desktop.sh" "$SCRIPT_DIR/start-desktop-inner.sh"
adb push "$SCRIPT_DIR/start-desktop.sh" /data/local/tmp/start-desktop.sh
adb push "$SCRIPT_DIR/start-desktop-inner.sh" /data/local/tmp/start-desktop-inner.sh
adb push "$SCRIPT_DIR/enter-ubuntu.sh" /data/local/tmp/enter-ubuntu.sh
adb shell </dev/null 'su -c "chmod +x /data/local/tmp/start-desktop.sh /data/local/tmp/start-desktop-inner.sh /data/local/tmp/enter-ubuntu.sh"'
ok "All scripts pushed"

echo ""
echo -e "${GREEN}${BOLD}XFCE X11 setup complete.${NC}"
echo ""
echo -e "${BOLD}To start the desktop:${NC}"
echo "  1. Open the Termux:X11 app on the tablet (black screen is normal)"
echo "  2. From your PC or Termux:"
echo -e "     ${CYAN}adb shell -t 'su -c /data/local/tmp/start-desktop.sh'${NC}"
echo "  3. Switch to the Termux:X11 app — XFCE desktop should appear"
echo ""
echo -e "${BOLD}To run apps that refuse root (Firefox, Chrome, VS Code):${NC}"
echo -e "  ${CYAN}fake-root firefox${NC}"
echo ""
echo -e "${BOLD}To install Firefox (.deb, not snap):${NC}"
echo -e "  ${CYAN}apt install -y firefox${NC}"
