#!/bin/bash
set -ouex pipefail

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
glib-compile-schemas /usr/share/glib-2.0/schemas
gsettings set com.github.stunkymonkey.nautilus-open-any-terminal terminal kitty

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

## Abilita greetd come display manager
systemctl enable --force greetd.service

## -------------------------------------------------------
## SKEL: configurazione default per nuovi utenti
## -------------------------------------------------------

## dms.service abilitato nella sessione grafica
mkdir -p /etc/skel/.config/systemd/user/graphical-session.target.wants
ln -sf /usr/lib/systemd/user/dms.service \
  /etc/skel/.config/systemd/user/graphical-session.target.wants/dms.service

## Config niri — copiata da build_files/dot_config/Niri/config.kdl
## Debug: mostra cosa è disponibile nel contesto di build
echo "=== Contenuto /ctx ==="
find /ctx -type f | sort

mkdir -p /etc/skel/.config/niri/
cp -f /ctx/dot_config/niri/config.kdl /etc/skel/.config/niri/config.kdl

## -------------------------------------------------------
## SERVIZIO FIRSTBOOT: sincronizza skel sugli utenti esistenti
## Necessario perché bootc switch non ricrea le home esistenti
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
    su - "$user" -c "systemctl --user daemon-reload" || true; \
    su - "$user" -c "systemctl --user enable dms.service" || true; \
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
dnf5 -y clean all
rm -rf /run/dnf /run/selinux-policy /var/lib/dnf
