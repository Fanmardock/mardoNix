#!/bin/bash
set -ouex pipefail

## ==========================================
## 1. RIMOZIONE PREVENTIVA CONFLITTI
## ==========================================
rum remove tuned-ppd qt6ct || true

## ==========================================
## 2. STACK RAKUOS / NIRI / COMPONENTI DI SISTEMA
## ==========================================
rum install -y --allowerasing \
    niri \
    xwayland-satellite \
    dms \
    dms-greeter \
    dankcalendar-git \
    danksearch \
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
    qt6ct \
    libnotify \
    power-profiles-daemon \
    libva-utils \
    clinfo \
    vulkan-tools

## ==========================================
## 3. APPLICAZIONI, UTILITY & XBOX DRIVERS
## ==========================================
rum install -y --allowerasing \
    code \
    libvirt virt-manager qemu-kvm flatpak-builder wlr-randr \
    iotop sysstat lxqt-openssh-askpass lxpolkit parallel \
    rakuos-software-gtk \
    kmod-xpadneo \
    xpadneo-udev \
    xone \
    bluez \
    bluez-tools \
    nautilus \
    kitty \
    mpv \
    rfkill \
    gvfs \
    gvfs-mtp \
    gvfs-nfs \
    file-roller \
    gnome-calculator \
    gnome-disk-utility \
    nautilus-open-any-terminal

## ==========================================
## 4. FIX CONTROLLER XBOX (BLUETOOTH ERTM)
## ==========================================
# Disabilita ERTM: senza questo, i pad Xbox via Bluetooth continuano a disconnettersi
mkdir -p /etc/modprobe.d/
echo "options bluetooth disable_ertm=1" > /etc/modprobe.d/bluetooth-xbox.conf

## ==========================================
## 5. PULIZIA PACCHETTI IN ECESSO
## ==========================================
rum remove waybar swaylock alacritty cosmic-comp cosmic-initial-setup cosmic-settings || true
