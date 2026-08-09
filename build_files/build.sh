#!/bin/bash
set -ouex pipefail

FEDORA_VERSION=$(rpm -E %fedora)

## DNF5 Speedup
sed -i '/^\[main\]/a max_parallel_downloads=10' /etc/dnf/dnf.conf

## ==========================================
## REPOSITORY ADDIZIONALI
## ==========================================
# RPM Fusion (Free e NonFree per driver hardware e codec)
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
## DRIVER HARDWARE AMD & MESA (RYZEN + RADEON)
## ==========================================
echo "Installazione Firmware e Driver AMD (Zen 2 + RDNA 3)..."
dnf5.real -y install \
    amd-ucode \
    linux-firmware \
    mesa-dri-drivers \
    mesa-vulkan-drivers \
    mesa-vulkan-drivers.i686 \
    vulkan-loader \
    vulkan-tools \
    clinfo \
    radeontop \
    mesa-va-drivers-freeworld \
    libva-utils

## ==========================================
## RESOLUTION CONFLITTO ENERGY MANAGEMENT
## ==========================================
# Rimuove tuned-ppd preinstallato prima di installare power-profiles-daemon
dnf5.real -y remove tuned-ppd || true

## ==========================================
## STACK RAKUOS / NIRI / COMPONENTI DI SISTEMA
## ==========================================
echo "Installazione stack Niri e pacchetti RakuOS..."
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
    power-profiles-daemon \
    --allowerasing

# System & User apps
dnf5.real -y install \
    libvirt virt-manager qemu-kvm flatpak-builder wlr-randr \
    iotop sysstat lxqt-openssh-askpass lxpolkit parallel \
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

## Rimozione componenti non necessari/in conflitto
dnf5.real -y remove waybar swaylock alacritty fuzzel cosmic-comp cosmic-initial-setup cosmic-settings || true

## Gsettings Override per Nautilus Terminal
mkdir -p /usr/share/glib-2.0/schemas/
cat > /usr/share/glib-2.0/schemas/99_nautilus-open-any-terminal.gschema.override << EOF
[com.github.stunkymonkey.nautilus-open-any-terminal]
terminal='kitty'
EOF
glib-compile-schemas /usr/share/glib-2.0/schemas

## ==========================================
## REGOLAZIONI DI SICUREZZA, PAM E SERVIZI
## ==========================================

# Sblocco Keyring automatico al login tramite Greetd (Da RakuOS)
if [ -f /etc/pam.d/greetd ]; then
    sed -i -E 's/^-([a-z]+[[:space:]]+.*pam_gnome_keyring\.so)/\1/' /etc/pam.d/greetd
fi

# Abilitazione servizi di sistema
systemctl enable power-profiles-daemon.service
systemctl enable bluetooth.service
systemctl enable podman.socket

# Regole Udev e Polkit per Bluetooth / DMS
mkdir -p /usr/lib/udev/rules.d
cat > /usr/lib/udev/rules.d/99-bluetooth-rfkill.rules << 'EOF'
SUBSYSTEM=="rfkill", ATTR{type}=="bluetooth", RUN+="/usr/sbin/rfkill unblock bluetooth"
EOF

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

## Configurazione Display Manager (Greetd + Niri)
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

## Sysusers e Tmpfiles per Greetd
cat > /usr/lib/sysusers.d/greetd.conf << EOF
g video 44 -
g render 989 -
u greeter - "Greetd Greeter" - /usr/sbin/nologin
m greeter video
m greeter render
EOF

mkdir -p /usr/lib/tmpfiles.d
cat > /usr/lib/tmpfiles.d/dms-greeter.conf << EOF
d /var/cache/dms-greeter 2770 greeter greeter - -
Z /var/cache/dms-greeter 2770 greeter greeter - -
EOF

systemctl enable --force greetd.service
mkdir -p /etc/systemd/system/display-manager.service.wants
ln -sf /usr/lib/systemd/system/greetd.service /etc/systemd/system/display-manager.service

## ==========================================
## ARCHITETTURA USER SETUP & UTILITY (GEMME RAKUOS)
## ==========================================

# 1. Utility RakuOS Shell Manager per gestione/ripristino DMS
cat > /usr/bin/rakuos-niri-shell << 'EOF'
#!/bin/bash
if [ "$EUID" -eq 0 ]; then
    echo "Questo script non deve essere eseguito da root!"
    exit 1
fi

install_dms() {
    systemctl --user unmask dms
    systemctl --user enable --now dms
}

rm_dms() {
    systemctl --user stop dms
    systemctl --user disable dms
}

case "$1" in
    "dms")
        install_dms
        echo "DankMaterialShell attivata correttamente."
        ;;
    "none")
        rm_dms
        echo "Shell disabilitata."
        ;;
    *)
        echo "Uso: rakuos-niri-shell <dms|none>"
        ;;
esac
EOF
chmod +x /usr/bin/rakuos-niri-shell

# 2. Servizio User Systemd per Sync Dotfiles sicuro (Stile RakuOS)
mkdir -p /usr/lib/systemd/user/
cat > /usr/lib/systemd/user/dotfiles-setup.service << 'UNIT'
[Unit]
Description=Initial User Dotfiles and Shell Setup
After=graphical-session-pre.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c '\
  FLAG="%h/.local/share/dotfiles-setup"; \
  if [ ! -f "$FLAG" ]; then \
    mkdir -p "%h/.config" "%h/.local/share"; \
    cp -rn /etc/skel/. "%h/"; \
    touch "$FLAG"; \
  fi'

[Install]
WantedBy=graphical-session.target
UNIT

# Abilita il servizio a livello globale per tutti gli utenti
systemctl enable --global dotfiles-setup.service
systemctl enable --global dms.service

## Fix Unmute Audio al Boot
mkdir -p /etc/profile.d
cat > /etc/profile.d/unmute-audio.sh << 'EOF'
if command -v amixer &> /dev/null; then
    (
        sleep 3
        amixer -c 0 set Master unmute 70% &>/dev/null || true
        amixer set Master unmute 70% &>/dev/null || true
    ) &
fi
EOF
chmod +x /etc/profile.d/unmute-audio.sh

## Pre-popolamento configurazione Niri in /etc/skel
mkdir -p /etc/skel/.config/niri/
if [ -f /ctx/dot_config/niri/config.kdl ]; then
    cp -f /ctx/dot_config/niri/config.kdl /etc/skel/.config/niri/config.kdl
fi

## Provisioning Flatpak (Prima installazione)
cat > /usr/lib/systemd/system/flatpak-provisioning.service << 'UNIT'
[Unit]
Description=Install system Flatpaks on first boot
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/var/lib/flatpak-provisioning.done

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/bash -c '\
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; \
  flatpak install --noninteractive --or-update flathub com.bambulab.BambuStudio || true; \
  flatpak install --noninteractive --or-update flathub info.febvre.Komikku || true; \
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

## CLEAN UP
dnf5.real -y clean all
rm -rf /run/dnf /run/selinux-policy /var/cache/dnf /var/cache/yum /tmp/*
