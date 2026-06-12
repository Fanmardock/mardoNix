#!/bin/bash
set -ouex pipefail

FEDORA_VERSION=$(rpm -E %fedora)

## DNF5 Speedup (Applicato al config reale)
sed -i '/^\[main\]/a max_parallel_downloads=10' /etc/dnf/dnf.conf

## System apps (Usando dnf5.real per bypassare l'overlay)
dnf5.real -y install libvirt virt-manager qemu-kvm flatpak-builder wlr-randr \
    iotop sysstat lxqt-openssh-askpass lxpolkit parallel

## User apps (Aggiunto rfkill per consentire lo sblocco hardware)
dnf5.real -y install nautilus kitty mpv gnome-system-monitor rfkill

## Supporto Bluetooth per Nautilus e Dankshell
dnf5.real -y install gvfs blueman

## ==========================================
## INSTALLAZIONE RAKUOS-SOFTWARE
## ==========================================
mkdir -p /tmp/rakuos-install
cd /tmp/rakuos-install

# Scarichiamo l'archivio degli artefatti (RPM)
ARTIFACT_URL="https://gitlab.com/rakuos/apps/rakuos-software/-/jobs/14810203948/artifacts/download?file_type=archive"
curl -L "$ARTIFACT_URL" -o artifacts.zip

# Estraiamo gli RPM
unzip artifacts.zip

# Installiamo gli RPM nel sistema
dnf5.real install -y ./rpmbuild/RPMS/x86_64/*.rpm

# Pulizia profonda per mantenere l'immagine pulita
cd /
rm -rf /tmp/rakuos-install
## ==========================================
    
## Nautilus open any terminal extension
curl -Lo /etc/yum.repos.d/nautilus-open-any-terminal.repo \
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

## ==========================================
## GESTIONE BLUETOOTH & REDIREZIONE TOGGLE
## ==========================================
# 1. Imposta il demone per NON accendere automaticamente l'antenna all'avvio
mkdir -p /etc/bluetooth/
cat > /etc/bluetooth/main.conf << EOF
[General]
AutoEnable=false
EOF

# 2. Crea un servizio di boot personalizzato per sbloccare RFKILL in modo pulito
cat > /usr/lib/systemd/system/rakuos-bluetooth-unblock.service << 'UNIT'
[Unit]
Description=Sblocco Hardware Bluetooth per RakuOS
After=bluetooth.service
Before=display-manager.service

[Service]
Type=oneshot
ExecStart=/usr/sbin/rfkill unblock bluetooth
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT

# 3. Abilita il servizio appena creato
systemctl enable rakuos-bluetooth-unblock.service

# 4. Redirezione del comando: intercetta il clic di Dankman e apre l'interfaccia di Blueman
cat > /usr/local/bin/rfkill << 'EOF'
#!/bin/bash
if [[ "$*" == *"unblock bluetooth"* ]]; then
    exec blueman-manager &
    exit 0
fi
exec /usr/sbin/rfkill "$@"
EOF

chmod +x /usr/local/bin/rfkill
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

## Remove COSMIC shell e waybar (Mantenendo la pulizia di cosmic-store)
dnf5.real -y remove cosmic-comp cosmic-initial-setup cosmic-settings \
                    cosmic-settings-daemon cosmic-store waybar || true

## CLEAN UP
dnf5.real -y clean all
rm -rf /run/dnf /run/selinux-policy /var/cache/dnf /var/cache/yum /tmp/*
