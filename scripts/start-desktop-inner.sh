#!/bin/bash
# Inner script — runs inside Ubuntu chroot
# Called by start-desktop.sh, not directly

export PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DISPLAY=:0
export TERM=xterm-256color
export HOME=/root
export USER=root
export XDG_RUNTIME_DIR=/run/user/0
export XDG_SESSION_TYPE=x11
unset TMPDIR
unset XAUTHORITY

# GTK scaling for high-DPI (SM-T970: 2800x1752, 12.4")
export GDK_SCALE=2
export GDK_DPI_SCALE=0.5
export QT_SCALE_FACTOR=2

mountpoint -q /proc          || mount -t proc proc /proc
mountpoint -q /sys           || mount -t sysfs sys /sys
mkdir -p /dev/pts /dev/shm /run /run/user/0 /run/dbus /sys/fs/cgroup
mountpoint -q /dev/pts       || mount -t devpts -o newinstance,ptmxmode=0666,mode=0620,gid=5 devpts /dev/pts
[ -e /dev/ptmx ] || ln -sf /dev/pts/ptmx /dev/ptmx
mountpoint -q /dev/shm       || mount -t tmpfs tmpfs /dev/shm
mountpoint -q /run           || mount -t tmpfs tmpfs /run
mkdir -p /run/user/0 /run/dbus
mountpoint -q /sys/fs/cgroup || mount -t cgroup2 cgroup2 /sys/fs/cgroup

# X11 socket bridge: socat proxies from file socket to abstract socket
mkdir -p /tmp/.X11-unix
rm -f /tmp/.X11-unix/X0
socat UNIX-LISTEN:/tmp/.X11-unix/X0,fork ABSTRACT-CONNECT:/data/data/com.termux/files/usr/tmp/.X11-unix/X0 &

# Set DPI via Xresources (applied before WM starts, survives sessions)
cat > /root/.Xresources << 'XREOF'
Xft.dpi: 192
Xcursor.size: 48
XREOF
xrdb -merge /root/.Xresources 2>/dev/null

# XFCE settings: write xfconf XML for panel, icons, fonts, cursor
# These persist in /root/.config/xfce4/ across restarts
mkdir -p /root/.config/xfce4/xfconf/xfce-perchannel-xml

# xsettings: DPI, cursor size, icon theme size, font hinting
cat > /root/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml << 'XSEOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Xft" type="empty">
    <property name="DPI" type="int" value="192"/>
    <property name="Antialias" type="int" value="1"/>
    <property name="HintStyle" type="string" value="hintslight"/>
    <property name="RGBA" type="string" value="rgb"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="CursorThemeSize" type="int" value="48"/>
    <property name="FontName" type="string" value="Sans 11"/>
  </property>
</channel>
XSEOF

# xfce4-panel: bigger panel (48px) for high-DPI
cat > /root/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml << 'PANELEOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=6;x=0;y=0"/>
      <property name="size" type="uint" value="48"/>
      <property name="length" type="uint" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="2"/>
        <value type="int" value="3"/>
        <value type="int" value="4"/>
        <value type="int" value="5"/>
        <value type="int" value="6"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="applicationsmenu"/>
    <property name="plugin-2" type="string" value="tasklist"/>
    <property name="plugin-3" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-4" type="string" value="systray"/>
    <property name="plugin-5" type="string" value="clock"/>
    <property name="plugin-6" type="string" value="actions"/>
  </property>
</channel>
PANELEOF

# xfce4-desktop: icon size
cat > /root/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml << 'DESKEOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="desktop-icons" type="empty">
    <property name="icon-size" type="uint" value="64"/>
    <property name="font-size" type="double" value="12"/>
  </property>
</channel>
DESKEOF

# xfwm4: window title font size
cat > /root/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml << 'WMEOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="title_font" type="string" value="Sans Bold 11"/>
    <property name="theme" type="string" value="Default"/>
  </property>
</channel>
WMEOF

# Build LD_PRELOAD library to fake non-root UID for apps that refuse root
FAKEUID_SO=/usr/local/lib/fakeuid.so
if [ ! -f "$FAKEUID_SO" ]; then
    if command -v gcc >/dev/null 2>&1; then
        mkdir -p /usr/local/lib
        cat > /tmp/fakeuid.c << 'FAKEC'
#include <sys/types.h>
uid_t getuid(void)  { return 1000; }
uid_t geteuid(void) { return 1000; }
FAKEC
        gcc -shared -o "$FAKEUID_SO" /tmp/fakeuid.c 2>/dev/null && rm -f /tmp/fakeuid.c
    fi
fi

# Create 'fake-root' wrapper
cat > /usr/local/bin/fake-root << 'WRAPPER'
#!/bin/bash
if [ -f /usr/local/lib/fakeuid.so ]; then
    exec env LD_PRELOAD=/usr/local/lib/fakeuid.so "$@"
else
    echo "Error: /usr/local/lib/fakeuid.so not found. Install gcc: sudo apt install gcc"
    exit 1
fi
WRAPPER
chmod +x /usr/local/bin/fake-root

# Docker/Podman CLI
mkdir -p /usr/local/bin
[ -f /data/local/tmp/docker/docker ] && ln -sf /data/local/tmp/docker/docker /usr/local/bin/docker 2>/dev/null
[ -f /data/local/tmp/docker/docker-compose ] && ln -sf /data/local/tmp/docker/docker-compose /usr/local/bin/docker-compose 2>/dev/null
[ -f /data/local/tmp/podman/podman-chroot-wrapper.sh ] && ln -sf /data/local/tmp/podman/podman-chroot-wrapper.sh /usr/local/bin/podman 2>/dev/null
export DOCKER_HOST=unix:///data/docker/docker.sock

# Start dbus
dbus-daemon --system --fork 2>/dev/null || true

# Fix polkit setuid helper (broken in chroot, causes D-Bus permission errors)
chmod 4755 /usr/lib/polkit-1/polkit-agent-helper-1 2>/dev/null

echo "Starting desktop on DISPLAY=:0"
echo "Switch to the Termux:X11 app on the tablet."
echo "For apps that refuse root (Firefox, Chrome): use 'fake-root firefox'"
exec startxfce4
