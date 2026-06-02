#!/bin/bash
set -ouex pipefail

## -------------------------------------------------------
## DISATTIVAZIONE FORZATA PLUGIN OVERLAY RAKUOS
## -------------------------------------------------------
echo "=== Disattivazione plugin DNF di RakuOS ==="

# 1. Rinominiamo i plugin di DNF5 (Fedora moderna) se presenti
mkdir -p /tmp/disabled_plugins
if [ -d /usr/lib64/dnf5/plugins ]; then
    find /usr/lib64/dnf5/plugins -type f -name "*rakuos*" -exec mv {} /tmp/disabled_plugins/ \; || true
fi

# 2. Rinominiamo i plugin di DNF4 (vecchio DNF/Python) se presenti
if [ -d /usr/lib/python3.*/site-packages/dnf-plugins ]; then
    find /usr/lib/python3.*/site-packages/dnf-plugins -type f -name "*rakuos*" -exec mv {} /tmp/disabled_plugins/ \; || true
fi

# 3. Controlliamo se c'è un file di configurazione dnf.conf custom o drop-in di RakuOS
if [ -d /etc/dnf/dnf.conf.d ]; then
    find /etc/dnf/dnf.conf.d -type f -name "*rakuos*" -exec mv {} /tmp/disabled_plugins/ \; || true
fi

## DNF5 Speedup
sed -i '/^\[main\]/a max_parallel_downloads=10' /etc/dnf/dnf.conf

## System apps
dnf -y install libvirt virt-manager qemu-kvm flatpak-builder wlr-randr \
    iotop sysstat lxqt-openssh-askpass lxpolkit parallel

## User apps
dnf -y install nautilus kitty mpv

## Nautilus open any terminal extension
curl -Lo /etc/yum.repos.d/nautilus-open-any-terminal.repo \
  https://copr.fedorainfracloud.org/coprs/monkeygold/nautilus-open-any-terminal/repo/fedora-$(rpm -E %fedora)/monkeygold-nautilus-open-any-terminal-fedora-$(rpm -E %fedora).repo

dnf install -y nautilus-open-any-terminal

## Gsettings Override (Fix per ambiente OCI senza D-Bus)
mkdir -p /usr/share/glib-2.0/schemas/
cat > /usr/share/glib-2.0/schemas/99_nautilus-open-any-terminal.gschema.override << EOF
[com.github.stunkymonkey.nautilus-open-any-terminal]
terminal='kitty'
EOF
glib-compile-schemas /usr/share/glib-2.0/schemas

## Install Niri
dnf -y install niri

## Install Dank Linux shell (DMS)
curl --output-dir "/etc/yum.repos.d/" \
  --remote-name "https://copr.fedorainfracloud.org/coprs/avengemedia/dms/repo/fedora-$(rpm -E %fedora)/avengemedia-dms-fedora-$(rpm -E %fedora).repo"

dnf -y install quickshell dms greetd dms-greeter --allowerasing

## Verifica path reale dms-greeter
DMS_GREETER_BIN=$(which dms-greeter 2>/dev/null || echo "/usr/bin/dms-greeter")

## Configura greetd
mkdir -p /etc/greetd/
cat > /etc/greetd/config.toml << EOF
[terminal]
vt = "next"

[default_session]
user = "greeter"
command = "${DMS_GREETER_BIN} --command niri"
EOF
chmod 0755 /etc/greetd
chown -R root:root /etc/greetd

## sysusers: crea gruppo video, render e utente greeter al boot
cat > /usr/lib/sysusers.d/greetd.conf << EOF
g video 44 -
g render 989 -
u greeter - "Greetd Greeter" - /usr/sbin/nologin
m greeter video
m greeter render
EOF

## tmpfiles: crea /var/cache/dms-greeter al boot con permessi corretti
cat > /usr/lib/tmpfiles.d/dms-greeter.conf << EOF
d /var/cache/dms-greeter 2770 greeter greeter - -
Z /var/cache/dms-greeter 2770 greeter greeter - -
EOF

## Abilita greetd come display manager principale
systemctl enable greetd.service
mkdir -p /etc/systemd/system/display-manager.service.wants
ln -sf /usr/lib/systemd/system/greetd.service /etc/systemd/system/display-manager.service

## -------------------------------------------------------
## SKEL: configurazione default per nuovi utenti
## -------------------------------------------------------
mkdir -p /etc/skel/.config/systemd/user/graphical-session.target.wants
ln -sf /usr/lib/systemd/user/dms.service \
  /etc/skel/.config/systemd/user/graphical-session.target.wants/dms.service

## Config niri
mkdir -p /etc/skel/.config/niri/
if [ -f /ctx/dot_config/niri/config.kdl ]; then
    cp -f /ctx/dot_config/niri/config.kdl /etc/skel/.config/niri/config.kdl
else
    echo "WARNING: /ctx/dot_config/niri/config.kdl non trovato!"
fi

## -------------------------------------------------------
## SERVIZIO FIRSTBOOT: sincronizza skel sugli utenti esistenti
## -------------------------------------------------------
cat > /usr/lib/systemd/system/skel-sync.service << 'UNIT'
[Unit]
Description=Sync /etc/skel to existing user homes on first boot
After=local-fs.target systemd-sysusers.service
ConditionPathExists=!/var/lib/skel-sync.done

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/bash -c '\
  for home in /var/home/*/; do \
    [ -d "$home" ] || continue; \
    user=$(basename "$home"); \
    uid=$(id -u "$user" 2>/dev/null) || continue; \
    [ "$uid" -ge 1000 ] || continue; \
    echo "Syncing skel to $home"; \
    cp -rn /etc/skel/. "$home"; \
    chown -R "$user":"$user" "$home"; \
  done; \
  touch /var/lib/skel-sync.done'

[Install]
WantedBy=multi-user.target
UNIT

systemctl enable skel-sync.service

## Enable podman socket
systemctl enable podman.socket

## Disable Origami tips
mv /etc/profile.d/origami-aliases.sh \
   /etc/profile.d/origami-aliases.sh.bak 2>/dev/null || true

## Remove COSMIC shell e waybar
dnf -y remove cosmic-comp cosmic-initial-setup cosmic-settings \
              cosmic-settings-daemon cosmic-store waybar || true

## CLEAN UP
dnf clean all
rm -rf /run/dnf /run/selinux-policy /var/cache/dnf /var/cache/yum /tmp/*

## -------------------------------------------------------
## RIPRISTINO PLUGIN RAKUOS (Importante per il runtime del sistema)
## -------------------------------------------------------
echo "=== Ripristino plugin DNF di RakuOS ==="
if [ -d /tmp/disabled_plugins ] && [ "$(ls -A /tmp/disabled_plugins)" ]; then
    # Se i plugin erano in dnf5, li rimettiamo al loro posto
    if [ -d /usr/lib64/dnf5/plugins ]; then
        find /tmp/disabled_plugins -type f -name "*dnf5*" -exec cp {} /usr/lib64/dnf5/plugins/ \; || true
    fi
    # Se erano in Python (dnf4), li rimettiamo al loro posto
    PY_DIR=$(ls -d /usr/lib/python3.*/site-packages/dnf-plugins 2>/dev/null | head -n 1)
    if [ -n "$PY_DIR" ]; then
        find /tmp/disabled_plugins -type f -name "*py*" -exec cp {} "$PY_DIR/" \; || true
    fi
    # Ripristino drop-in config
    if [ -d /etc/dnf/dnf.conf.d ]; then
        find /tmp/disabled_plugins -type f -not -name "*.py" -not -name "*.so" -exec cp {} /etc/dnf/dnf.conf.d/ \; || true
    fi
fi
rm -rf /tmp/disabled_plugins
