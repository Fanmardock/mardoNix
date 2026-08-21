#!/bin/bash
set -oux pipefail

## ==========================================
## 0. CONFIGURAZIONE OPTIMIZATION ISA (x86-64-v3)
## ==========================================
# Imposta i flag di compilazione per l'architettura x86-64-v3 (AVX2, BMI2, FMA)
export CFLAGS="-O2 -pipe -march=x86-64-v3 -mtune=generic"
export CXXFLAGS="-O2 -pipe -march=x86-64-v3 -mtune=generic"
export LDFLAGS="-Wl,-O1,--sort-common"

# Inietta la macro RPM per la build di eventuali pacchetti locali su x86-64-v3
mkdir -p /etc/rpm
cat > /etc/rpm/macros.override << 'EOF'
%_target_cpu x86_64
%optflags -O2 -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -fstack-protector-strong --param=ssp-buffer-size=4 -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection -march=x86-64-v3 -mtune=generic
EOF

## ==========================================
## 1. ESECUZIONE BUILD BASE (RAKUOS COMMON)
## ==========================================
echo "=== Esecuzione script base RakuOS ==="
if [ -f /ctx/build.sh ]; then
    bash /ctx/build.sh || echo "WARNING: build.sh ha terminato con alcuni warning, continuo con la personalizzazione AMD..."
else
    echo "ERROR: /ctx/build.sh non trovato!"
    exit 1
fi

## ==========================================
## 2. PULIZIA DRIVER INTEL / CONFLITTI
## ==========================================
echo "=== Rimozione driver Intel dedicati ==="
dnf5.real -y remove \
    intel-media-driver \
    libva-intel-driver || true

## ==========================================
## 3. CHIPSET AMD & MICROCODE CPU (RYZEN)
## ==========================================
echo "=== Installazione microcode CPU e utility per chipset AMD ==="
dnf5.real -y install \
    microcode_ctl \
    cpupower \
    lm_sensors \
    --skip-unavailable \
    --allowerasing || true

## ==========================================
## 4. STACK GRAFICO & UTILITY PER GPU RADEON
## ==========================================
echo "=== Configurazione accelerazione grafica e driver Vulkan/VA-API per AMD ==="
dnf5.real -y install \
    mesa-dri-drivers \
    mesa-vulkan-drivers \
    mesa-vulkan-drivers.i686 \
    vulkan-loader \
    vulkan-tools \
    libva-utils \
    radeontop \
    rocm-smi \
    --skip-unavailable \
    --allowerasing || true

## ==========================================
## 5. OTTIMIZZAZIONI KERNEL & MODPROBE PER AMD
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
## 6. PULIZIA FINALE CACHE DNF
## ==========================================
echo "=== Pulizia cache ==="
dnf5.real -y clean all
rm -rf /run/dnf /run/selinux-policy /var/cache/dnf /var/cache/yum /tmp/*
