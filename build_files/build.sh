#!/bin/bash
set -ouex pipefail

FEDORA_VERSION=$(rpm -E %fedora)

## DNF5 Speedup
sed -i '/^\[main\]/a max_parallel_downloads=10' /etc/dnf/dnf.conf

## System apps (Manteniamo power-profiles-daemon per il risparmio energetico)
dnf5.real -y install libvirt virt-manager qemu-kvm flatpak-builder wlr-randr \
    iotop sysstat lxqt-openssh-askpass lxpolkit parallel

dnf5.real -y install power-profiles-daemon --allowerasing

## User apps
dnf5.real -y install nautilus kitty mpv gnome-system-monitor rfkill

## Supporto Bluetooth standard di sistema (gvfs e l'interfaccia Blueman)
dnf5.real -y install gvfs blueman

## ==========================================
## INSTALLAZIONE RAKUOS-SOFTWARE (PRE-COMPILATO)
## ==========================================
mkdir -p /tmp/rakuos-install
cd /tmp/rakuos-install

echo "Recupero del binario pre-compilato di RakuOS Software..."

# PIANO A: Scarica l'ultimo rilascio stabile ufficiale dalle Release di GitLab se accessibile
curl -L "https://gitlab.com/api/v4/projects/rakuos%2Fapps%2Frakuos-software/releases/permalink/latest/downloads/rakuos-software" -o rakuos-software || true

# PIANO B (Blindato): Se le Release falliscono o sono vuote, estraiamo il binario 
# direttamente dall'immagine del Container Registry ufficiale distribuito dagli sviluppatori.
if [ ! -s rakuos-software ] || head -n 1 rakuos-software | grep -qE "(<!DOCTYPE html|<html)"; then
    echo "Nessun binario diretto nelle Release. Estraggo dall'immagine del registro ufficiale..."
    
    IMAGE_TAG="registry.gitlab.com/rakuos/apps/rakuos-software:latest"
    
    # Crea un container fittizio temporaneo per poter navigare nei suoi file
    CONTAINER_ID=$(podman create "$IMAGE_TAG")
    
    # Copia il binario già pronto fuori dal container (gestisce i due possibili percorsi standard)
    podman cp "$CONTAINER_ID:/usr/bin/rakuos-software" ./rakuos-software || podman cp "$CONTAINER_ID:/usr/local/bin/rakuos-software" ./rakuos-software
    
    # Elimina il container temporaneo di appoggio
    podman rm "$CONTAINER_ID"
fi

# Configurazione permessi e posizionamento finale nel sistema
chmod +x rakuos-software
mkdir -p /usr/bin
mv rakuos-software /usr/bin/rakuos-software

# Pulizia profonda
cd /
rm -rf /tmp/rakuos-install
## ==========================================
    
## Nautilus open any terminal extension
curl -Lo /etc/yum.repos.d/nautilus-open-any-terminal.repo \
  https://copr.fedorainfracloud.org/coprs/monkeygold/nautilus-open-any-terminal/repo/fedora-${FEDORA_VERSION}/monkeygold-nautilus-open-any-terminal-fedora-${FEDORA_VERSION}.repo

dnf5.real -y install nautilus-open-any-terminal

## Gsettings Override
mkdir -p /usr/share/glib-2.0/schemas/
cat > /usr/share/glib-2.0/schemas/99_nautilus-open-any-terminal.gschema.override << EOF
[com.github.stunkymonkey.nautilus-open-any-terminal]
terminal='kitty'
EOF
glib-compile-schemas /usr/share/glib-2.0/schemas

## Install Niri
dnf5.real -y install niri

## Install Dank Linux shell (DMS)
curl --output-dir "/etc/yum.repos.d/" \
  --remote-name "https://copr.fedorainfracloud.org/coprs/avengemedia/dms/repo/fedora-${FEDORA_VERSION}/avengemedia-dms-fedora-${FEDORA_VERSION}.repo"

dnf5.real -y install quickshell dms greetd dms-greeter --allowerasing

## ==========================================
## CONFIGURAZIONE SERVIZI DI SISTEMA (POWER)
## ==========================================
# Abilita il servizio per i profili energetici di Dankshell
systemctl enable power-profiles-daemon.service
## ==========================================

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

## sysusers
cat > /usr/lib/sysusers.d/greetd.conf << EOF
g video 44 -
g render 989 -
u greeter - "Greetd Greeter" - /usr/sbin/nologin
m greeter video
m greeter render
EOF

## tmpfiles
cat > /usr/lib/tmpfiles.d/dms-greeter.conf << EOF
d /var/cache/dms-greeter 2770 greeter greeter - -
Z /var/cache/dms-greeter 2770 greeter greeter - -
EOF

## Abilita greetd
systemctl enable --force greetd.service
mkdir -p /etc/systemd/system/display-manager.service.wants
ln -sf /usr/lib/systemd/system/greetd.service /etc/systemd/system/display-manager.service

## -------------------------------------------------------
## SKEL: configurazione default per nuovi utenti
## -------------------------------------------------------
mkdir -p /etc/skel/.local/share/applications
mkdir -p /etc/skel/.config
mkdir -p /etc/skel/.var/app

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
## SERVIZIO FIRSTBOOT
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
    mkdir -p "$home"/.local/share/applications; \
    mkdir -p "$home"/.config; \
    rm -rf "$home"/.var/app/com.google.Chrome; \
    cp -rn /etc/skel/. "$home"; \
    chown -R "$user":"$user" "$home"; \
    chmod -R u+rwX "$home"/.local "$home"/.config 2>/dev/null || true; \
  done; \
  touch /var/lib/skel-sync.done'

[Install]
WantedBy=multi-user.target
UNIT

systemctl enable skel-sync.service

## -------------------------------------------------------
## SERVIZIO FLATPAK
## -------------------------------------------------------
cat > /usr/lib/systemd/system/flatpak-provisioning.service << 'UNIT'
[Unit]
Description=Install system Flatpaks on first boot
After=network-online.target skel-sync.service
Wants=network-online.target
ConditionPathExists=!/var/lib/flatpak-provisioning.done

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/bash -c '\
  echo "Aggiunta repository Flathub..."; \
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; \
  echo "Installazione/Aggiornamento BambuStudio..."; \
  flatpak install --noninteractive --or-update flathub com.bambulab.BambuStudio || true; \
  echo "Installazione/Aggiornamento Komikku..."; \
  flatpak install --noninteractive --or-update flathub info.febvre.Komikku || true; \
  echo "Installazione/Aggiornamento Google Chrome..."; \
  flatpak install --noninteractive --or-update flathub com.google.Chrome || true; \
  touch /var/lib/flatpak-provisioning.done'

[Install]
WantedBy=multi-user.target
UNIT

systemctl enable flatpak-provisioning.service

## Enable podman socket
systemctl enable podman.socket

## Disable Origami tips
mv /etc/profile.d/origami-aliases.sh \
   /etc/profile.d/origami-aliases.sh.bak 2>/dev/null || true

## Remove COSMIC shell e waybar
dnf5.real -y remove cosmic-comp cosmic-initial-setup cosmic-settings \
                cosmic-settings-daemon cosmic-store waybar || true

## CLEAN UP
dnf5.real -y clean all
rm -rf /run/dnf /run/selinux-policy /var/cache/dnf /var/cache/yum /tmp/*
