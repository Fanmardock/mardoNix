#!/bin/bash
set -ouex pipefail

FEDORA_VERSION=$(rpm -E %fedora)

## DNF5 Speedup (Applicato al config reale)
sed -i '/^\[main\]/a max_parallel_downloads=10' /etc/dnf/dnf.conf

## System apps (Usando dnf5.real per bypassare l'overlay)
dnf5.real -y install libvirt virt-manager qemu-kvm flatpak-builder wlr-randr \
    iotop sysstat lxqt-openssh-askpass lxpolkit parallel

## User apps (Aggiunto cosmic-store, icone e le librerie Qt6 per Wayland)
dnf5.real -y install nautilus kitty mpv gnome-system-monitor
    
## Supporto Bluetooth per Nautilus e Dankshell
dnf5.real -y install gvfs blueman

## ==========================================
## COMPILAZIONE MANUALE DI RAKUOS-SOFTWARE
## ==========================================

## ==========================================
## COMPILAZIONE MANUALE DI RAKUOS-SOFTWARE (RUST/Qt6)
## ==========================================

# 1. Installiamo il compilatore Rust (cargo), git e i file di sviluppo di Qt6
dnf5.real -y install git cargo qt6-qtbase-devel qt6-qtdeclarative-devel \
    qt6-qtsvg-devel qt6-qttools-devel

# 2. Cloniamo il codice sorgente
cd /tmp
git clone https://gitlab.com/rakuos/apps/rakuos-software.git
cd rakuos-software

# 3. Compiliamo in modalità Release (ottimizzata e veloce) usando Cargo
cargo build --release

# 4. Copiamo il binario appena generato nella cartella corretta di sistema
# (Dall'errore iniziale sappiamo che il sistema cerca il binario QT proprio in quel percorso)
mkdir -p /usr/libexec/rakuos/software/
cp target/release/rakuos-software-qt /usr/libexec/rakuos/software/rakuos-software-qt

# 5. Pulizia profonda: eliminiamo cargo e le dipendenze per non appesantire l'immagine
cd /
rm -rf /tmp/rakuos-software
dnf5.real -y remove cargo qt6-qtbase-devel qt6-qtdeclarative-devel \
    qt6-qtsvg-devel qt6-qttools-devel || true
    
## Nautilus open any terminal extension
curl Lo /etc/yum.repos.d/nautilus-open-any-terminal.repo \
  https://copr.fedorainfracloud.org/coprs/monkeygold/nautilus-open-any-terminal/repo/fedora-${FEDORA_VERSION}/monkeygold-nautilus-open-any-terminal-fedora-${FEDORA_VERSION}.repo

dnf5.real -y install nautilus-open-any-terminal

## Gsettings Override (Fix per ambiente OCI senza D-Bus)
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

## Gestione Bluetooth: Spento di default all'avvio, ma sbloccabile "on the fly"
# Questa regola udev spegne l'antenna all'avvio senza killare il servizio systemd.
## Configura il Bluetooth per non connettersi automaticamente all'avvio
mkdir -p /etc/bluetooth/
cat > /etc/bluetooth/main.conf << EOF
[General]
# Impedisce al Bluetooth di accendere le antenne e cercare dispositivi al boot
AutoEnable=false
EOF

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
systemctl enable --force greetd.service
mkdir -p /etc/systemd/system/display-manager.service.wants
ln -sf /usr/lib/systemd/system/greetd.service /etc/systemd/system/display-manager.service

## -------------------------------------------------------
## SKEL: configurazione default per nuovi utenti
## -------------------------------------------------------
# Fix Bubblewrap/Chrome: Generiamo preventivamente i percorsi XDG nello skel
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
## SERVIZIO FIRSTBOOT: sincronizza skel e sana i permessi di Chrome
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
    # Forza la creazione locale delle cartelle critiche per evitare bug di bwrap
    mkdir -p "$home"/.local/share/applications; \
    mkdir -p "$home"/.config; \
    # Rimuove eventuali vecchie sandbox corrotte di Chrome create da root
    rm -rf "$home"/.var/app/com.google.Chrome; \
    # Copia i file mancanti dallo skel
    cp -rn /etc/skel/. "$home"; \
    # Sanatoria totale dei permessi: lito ogni cartella a root
    chown -R "$user":"$user" "$home"; \
    chmod -R u+rwX "$home"/.local "$home"/.config 2>/dev/null || true; \
  done; \
  touch /var/lib/skel-sync.done'

[Install]
WantedBy=multi-user.target
UNIT

systemctl enable skel-sync.service

## -------------------------------------------------------
## SERVIZIO FLATPAK: Installazione automatica al primo boot
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

## Remove COSMIC shell e waybar (Rimosso cosmic-store da questa lista nera!)
dnf5.real -y remove cosmic-comp cosmic-initial-setup cosmic-settings \
                    cosmic-settings-daemon cosmic-store waybar  || true

## CLEAN UP
dnf5.real -y clean all
rm -rf /run/dnf /run/selinux-policy /var/cache/dnf /var/cache/yum /tmp/*
