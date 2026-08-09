#!/bin/bash
set -ouex pipefail

## ==========================================
## 1. ESECUZIONE BUILD BASE (INTEL / GENERICA)
## ==========================================
# Esegue prima lo script base universale per includere tutti i pacchetti,
# servizi systemd, Greetd, DMS e dotfiles.
/ctx/build.sh

## ==========================================
## 2. CHIPSET AMD & MICROCODE CPU (RYZEN)
## ==========================================
echo "Installazione microcode CPU e utility per chipset AMD..."
dnf5.real -y install \
    microcode_ctl \
    cpupower \
    lm_sensors \
    --skip-unavailable || true

## ==========================================
## 3. STACK GRAFICO & UTILITY PER GPU RADEON
## ==========================================
echo "Configurazione accelerazione grafica e driver Vulkan/VA-API per AMD..."
dnf5.real -y install \
    mesa-dri-drivers \
    mesa-vulkan-drivers \
    mesa-vulkan-drivers.i686 \
    vulkan-loader \
    vulkan-tools \
    libva-utils \
    radeontop \
    rocm-smi \
    --allowerasing || true

## ==========================================
## 4. OTTIMIZZAZIONI KERNEL & MODPROBE PER AMD
## ==========================================

# A. Modprobe: forza l'uso di amdgpu e sblocca il Power Management completo della GPU
mkdir -p /etc/modprobe.d
cat > /etc/modprobe.d/amdgpu.conf << EOF
# Supporto per GPU dedicate ed integrate AMD
options amdgpu si_support=1
options amdgpu cik_support=1
# Abilita il controllo dinamico di ventole, clock e stati di potenza (Overdrive/PM)
options amdgpu ppfeaturemask=0xffffffff
EOF

# B. Variabili di ambiente globali per Wayland/Niri (Mesa RADV & VA-API)
mkdir -p /etc/profile.d
cat > /etc/profile.d/amd-performance.sh << 'EOF'
# Driver Vulkan predefinito (RADV di Mesa, altamente performante)
export AMD_VULKAN_ICD=RADV
# Driver per accelerazione video hardware VA-API/VDPAU via RadeonSI
export LIBVA_DRIVER_NAME=radeonsi
export VDPAU_DRIVER=radeonsi
# Abilita il multithreading e la cache degli shader OpenGL su Mesa
export mesa_glthread=true
EOF
chmod +x /etc/profile.d/amd-performance.sh

# C. Kernel Sysctl Tweaks per memoria e reattività su Ryzen
mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/99-amd-performance.conf << EOF
# Ottimizza l'uso dello swap per prevenire micro-stuttering sotto carico grafico
vm.swappiness=10
vm.vfs_cache_pressure=50
EOF

## ==========================================
## 5. PULIZIA FINALE CACHE DNF
## ==========================================
dnf5.real -y clean all
rm -rf /run/dnf /run/selinux-policy /var/cache/dnf /var/cache/yum /tmp/*
