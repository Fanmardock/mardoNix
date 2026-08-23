#!/bin/bash
set -ouex pipefail

## ==========================================
## 1. RIMOZIONE PREVENTIVA CONFLITTI
## ==========================================
# Rimozione di tuned-ppd per consentire l'installazione di power-profiles-daemon
# Rimozione di qt6ct nativo se presente, per evitare conflitti con eventuali sovrapposizioni
rum remove tuned-ppd qt6ct || true

## ==========================================
## 2. STACK RAKUOS / NIRI / COMPONENTI DI SISTEMA
## ==========================================
rum install -y --allowerasing \
    niri \
    xwayland-satellite \
    dms \
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
## 3. APPLICAZIONI & UTILITY
## ==========================================
rum install -y \
    code \
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
    gnome-disk-utility \
    nautilus-open-any-terminal

## ==========================================
## 4. RIMOZIONE COMPONENTI RIDONDANTI
## ==========================================
rum remove waybar swaylock alacritty fuzzel cosmic-comp cosmic-initial-setup cosmic-settings || true
