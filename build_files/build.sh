#!/bin/bash
set -ouex pipefail

FEDORA_VERSION=$(rpm -E %fedora)

## DNF5 Speedup
sed -i '/^\[main\]/a max_parallel_downloads=10' /etc/dnf/dnf.conf

## ==========================================
## REPOSITORY ADDIZIONALI
## ==========================================
# RPM Fusion (Free e NonFree)
dnf5.real -y install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm \
                    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm

## Repository DMS / Dank Linux Shell
curl --output-dir "/etc/yum.repos.d/" \
  --remote-name "https://copr.fedorainfracloud.org/coprs/avengemedia/dms/repo/fedora-${FEDORA_VERSION}/avengemedia-dms-fedora-${FEDORA_VERSION}.repo"

## Repository Nautilus Open Any Terminal
curl -Lo /etc/yum.repos.d/nautilus-open-any-terminal.repo \
  https://copr.fedorainfracloud.org/coprs/monkeygold/nautilus-open-any-terminal/repo/fedora-${FEDORA_VERSION}/monkeygold-nautilus-open-any-terminal-fedora-${FEDORA_VERSION}.repo

## ==========================================
## CONFIGURAZIONE GRUPPI CORE (SYSUSERS)
## ==========================================
echo "Configurazione gruppi core tramite sysusers.d..."
mkdir -p /usr/lib/sysusers.d
cat > /usr/lib/sysusers.d/core-groups.conf << EOF
g audio     - -
g video     - -
g render    - -
g disk      - -
g kvm       - -
g input     - -
g tty       - -
g clock     - -
g utmp      - -
g plugdev   - -
g lp        - -
g bluetooth - -
EOF

# Crea l'utente di sistema tss se mancante (richiesto da tpm2/tmpfiles)
getent passwd tss &>/dev/null || useradd -r -g tss -d /var/empty -s /usr/sbin/nologin -c "TPM2 TSS User" tss

## ==========================================
## INSTALLAZIONE PACCHETTI E COMPONENTI NIRI
## ==========================================

# 1. Core Niri, DMS & Componenti di integrazione RakuOS
dnf5.real -y install \
    niri \
    xwayland-satellite \
    dms \
    dms-greeter \
    quickshell \
    greetd \
    xdg-desktop-portal \
    xdg-desktop-portal-gnome \
    xdg-desktop-portal-gtk \
    xdg-user-dirs-gtk \
    wl-clipboard \
    wtype \
    wl-mirror \
    gnome-keyring \
    gnome-keyring-pam \
    fprintd-pam \
    pipewire \
    wireplumber \
    pavucontrol \
    blueman \
    ddcutil \
    adw-gtk3-theme \
    qt6ct-kde \
    libnotify \
    --allowerasing

# 2. System & User apps
dnf5.real -y install \
    libvirt virt-manager qemu-kvm flatpak-builder wlr-randr \
    iotop sysstat lxqt-openssh-askpass lxpolkit parallel \
    power-profiles-daemon \
    cosmic-store \
    akmod-xpadneo \
    nautilus \
    kitty \
    mpv \
    rfkill \
    gvfs \
    gvfs-mtp \
    gvfs-nfs \
    file-roller \
    gnome-calculator \
    gnome-disk-utility

dnf5.real -y install nautilus-open-any-terminal

## Gsettings Override per Nautilus Terminal
mkdir -p /usr/share/glib-2.0/schemas/
cat > /usr/share/glib-2.0/schemas/99_nautilus-open-any-terminal.gschema.override << EOF
[com.github.stunkymonkey.nautilus-open-any-terminal]
terminal='kitty'
EOF
glib-compile-schemas /usr/share/glib-2.0/schemas

## ==========================================
## FIX E CONFIGURAZIONI DI SISTEMA
## ==========================================

# Sblocco Keyring automatico al login tramite Greetd (Da RakuOS)
if [ -f /etc/pam.d/greetd ]; then
    sed -i -E 's/^-([a-z]+[[:space:]]+.*pam_gnome_keyring\.so)/\1/' /etc/pam.d/greetd
fi

# Configurazione servizi hardware
systemctl enable power-profiles-daemon.service
systemctl enable bluetooth.service
systemctl enable podman.socket

# Regola Udev per Bluetooth attivo al boot
echo "Configurazione regola Udev per il Bluetooth attivo al boot..."
mkdir -p /usr/lib/udev/rules.d
cat > /usr/lib/udev/rules.d/99-bluetooth-rfkill.rules << 'EOF'
SUBSYSTEM=="rfkill", ATTR{type}=="bluetooth", RUN+="/usr/sbin/rfkill unblock bluetooth"
EOF

# Regola Polkit per DMS Bluetooth
echo "Configurazione regole Polkit per il gruppo wheel..."
mkdir -p /usr/share/polkit-1/rules.d
cat > /usr/share/polkit-1/rules.d/99-bluetooth-dms.rules << 'EOF'
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.login1.set-rfkill-state" ||
         action.id.indexOf("org.bluez.") === 0) &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF

## Configurazione Display Manager (Greetd)
DMS_GREETER_BIN=$(which dms-greeter 2>/dev/null || echo "/usr/bin/dms-greeter")

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

## sysusers greetd
cat > /usr/lib/sysusers.d/greetd.conf << EOF
g video 44 -
g render 989 -
u greeter - "Greetd Greeter" - /usr/sbin/nologin
m greeter video
m greeter render
EOF

## tmpfiles greetd
mkdir -p /usr/lib/tmpfiles.d
cat > /usr/lib/tmpfiles.d/dms-greeter.conf << EOF
d /var/cache/dms-greeter 2770 greeter greeter - -
Z /var/cache/dms-greeter 2770 greeter greeter - -
EOF

## Abilita greetd
systemctl enable --force greetd.service
mkdir -p /etc/systemd/system/display-manager.service.wants
ln -sf /usr/lib/systemd/system/greetd.service /etc/systemd/system/display-manager.service

## -------------------------------------------------------
## FIX UNMUTE AUDIO AD OGNI LOGIN
## -------------------------------------------------------
mkdir -p /etc/profile.d
cat > /etc/profile.d/unmute-audio.sh << 'EOF'
if command -v amixer &> /dev/null; then
    (
        sleep 3
        amixer -c 0 set Master unmute 70% &>/dev/null || true
        amixer -c 0 set Speaker unmute 70% &>/dev/null || true
        amixer -c 0 set Front unmute 70% &>/dev/null || true
        amixer set Master unmute 70% &>/dev/null || true
        amixer set Speaker unmute 70% &>/dev/null || true
    ) &
fi
EOF
chmod +x /etc/profile.d/unmute-audio.sh

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
## SERVIZIO REFRESH UTENTI E LIVELLO PERMESSI
## -------------------------------------------------------
cat > /usr/lib/systemd/system/skel-sync.service << 'UNIT'
[Unit]
Description=Sync system groups and etc skel configuration for local users
After=local-fs.target systemd-sysusers.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/bash -c '\
  echo "Allineamento gruppi hardware per gli utenti locali..."; \
  for home in /var/home/*/; do \
    [ -d "$home" ] || continue; \
    user=$(basename "$home"); \
    uid=$(id -u "$user" 2>/dev/null) || continue; \
    [ "$uid" -ge 1000 ] || continue; \
    echo "Assegnazione gruppi hardware a $user..."; \
    /usr/sbin/usermod -aG audio,video,render,input,kvm,lp,bluetooth "$user" || true; \
  done; \
  if [ ! -f /var/lib/skel-sync.done ]; then \
    for home in /var/home/*/; do \
      [ -d "$home" ] || continue; \
      user=$(basename "$home"); \
      uid=$(id -u "$user" 2>/dev/null) || continue; \
      [ "$uid" -ge 1000 ] || continue; \
      echo "Inizializzazione skel iniziale in $home"; \
      mkdir -p "$home"/.local/share/applications; \
      mkdir -p "$home"/.config; \
      rm -rf "$home"/.var/app/com.google.Chrome; \
      cp -rn /etc/skel/. "$home"; \
      chown -R "$user":"$user" "$home"; \
      chmod -R u+rwX "$home"/.local "$home"/.config 2>/dev/null || true; \
    done; \
    touch /var/lib/skel-sync.done; \
  fi'

[Install]
WantedBy=multi-user.target
UNIT

systemctl enable skel-sync.service

## -------------------------------------------------------
## SERVIZIO FLATPAK PROVISIONING
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

mkdir -p /etc/modprobe.d
cat > /etc/modprobe.d/bluetooth-xbox-ertm.conf << EOF
options bluetooth disable_ertm=1
EOF

## Disable Origami tips
mv /etc/profile.d/origami-aliases.sh \
   /etc/profile.d/origami-aliases.sh.bak 2>/dev/null || true

## Remove redundant shells e composants
dnf5.real -y remove cosmic-comp cosmic-initial-setup cosmic-settings waybar swaylock alacritty fuzzel || true

## CLEAN UP
dnf5.real -y clean all
rm -rf /run/dnf /run/selinux-policy /var/cache/dnf /var/cache/yum /tmp/*
