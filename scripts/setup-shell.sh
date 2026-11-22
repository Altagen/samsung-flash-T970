#!/bin/bash
# Install the chroot shell configuration (coloured prompt, ls colours, history,
# tab completion, DOCKER_HOST) for root in the Ubuntu chroot.
# Called by setup-ubuntu.sh; can be run alone on an existing install.
#
# Usage: ./scripts/setup-shell.sh
# Requires: ADB connected, Magisk root, Ubuntu chroot (setup-ubuntu.sh)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENTER_UBUNTU=/data/local/tmp/enter-ubuntu.sh
SOURCE_LINE='[ -r /etc/sm-t970.bashrc ] && . /etc/sm-t970.bashrc'

GREEN='\033[0;32m'; RED='\033[0;31m'; DIM='\033[2m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}OK${NC} $1"; }
fail() { echo -e "  ${RED}ERROR${NC} $1"; exit 1; }

adb shell </dev/null 'su -c "test -f /data/ubuntu/bin/bash && echo ok"' 2>/dev/null | grep -q ok \
    || fail "Ubuntu chroot not found. Run setup-ubuntu.sh first."

# 1. /etc/sm-t970.bashrc
adb push "$SCRIPT_DIR/chroot/sm-t970.bashrc" /data/local/tmp/sm-t970.bashrc >/dev/null
adb shell </dev/null 'su -c "
    mv /data/local/tmp/sm-t970.bashrc /data/ubuntu/etc/sm-t970.bashrc
    chown 0:0 /data/ubuntu/etc/sm-t970.bashrc
    chmod 644 /data/ubuntu/etc/sm-t970.bashrc
"'
ok "/etc/sm-t970.bashrc installed"

# 2. Source it at the end of /root/.bashrc (once)
adb shell </dev/null "su -c \"
    [ -f /data/ubuntu/root/.bashrc ] || cp /data/ubuntu/etc/skel/.bashrc /data/ubuntu/root/.bashrc
    grep -qF '/etc/sm-t970.bashrc' /data/ubuntu/root/.bashrc || printf '\n# SM-T970 chroot settings\n%s\n' '$SOURCE_LINE' >> /data/ubuntu/root/.bashrc
\""
ok "/root/.bashrc sources it"

# 3. Tab completion engine
if adb shell </dev/null 'su -c "test -r /data/ubuntu/usr/share/bash-completion/bash_completion && echo ok"' 2>/dev/null | grep -q ok; then
    echo -e "  ${DIM}bash-completion already installed${NC}"
else
    adb shell </dev/null "su -c \"$ENTER_UBUNTU bash -c 'DEBIAN_FRONTEND=noninteractive apt install -y -qq bash-completion >/dev/null 2>&1'\"" || true
    if adb shell </dev/null 'su -c "test -r /data/ubuntu/usr/share/bash-completion/bash_completion && echo ok"' 2>/dev/null | grep -q ok; then
        ok "bash-completion installed"
    else
        echo -e "  ${DIM}bash-completion not installed (apt failed?) — prompt and colours work anyway${NC}"
    fi
fi

echo -e "  ${DIM}Open a new SSH session (or enter-ubuntu.sh) to get the new prompt.${NC}"
