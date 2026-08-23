#!/bin/bash
set -ouex pipefail

## ==========================================
## 1. ESECUZIONE BUILD BASE (Rifiuta errori silenziosi)
## ==========================================
if [ -f /ctx/build.sh ]; then
    bash /ctx/build.sh
fi

## ==========================================
## 2. OPTIMIZATION ISA (x86-64-v3 per AMD)
## ==========================================
export CFLAGS="-O2 -pipe -march=x86-64-v3 -mtune=znver3"
export CXXFLAGS="-O2 -pipe -march=x86-64-v3 -mtune=znver3"

## ==========================================
## 3. PACCHETTI E DRIVER SPECIFICI AMD
## ==========================================
dnf5.real -y install \
    amd-ucode \
    mesa-dri-drivers \
    mesa-vulkan-drivers \
    mesa-va-drivers \
    mesa-vdpau-drivers \
    rocm-opencl \
    rocm-smi \
    radeontop \
    --allowerasing

## ==========================================
## 4. REGOLAZIONI KERNEL & SWAP PER AMD
## ==========================================
# Configurazione Sysctl ottimizzata per architettura AMD/Ryzen
mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/99-amd-performance.conf << 'EOF'
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=5
vm.dirty_ratio=10
EOF

## ==========================================
## 5. CLEAN UP
## ==========================================
dnf5.real -y clean all
rm -rf /run/dnf /run/selinux-policy /var/cache/dnf /var/cache/yum /tmp/*
