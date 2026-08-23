#!/bin/bash
set -ouex pipefail

if [ -f /ctx/build.sh ]; then
    bash /ctx/build.sh
fi

export CFLAGS="-O2 -pipe -march=znver3 -mtune=znver3"
export CXXFLAGS="-O2 -pipe -march=znver3 -mtune=znver3"

rum install -y \
    linux-firmware \
    mesa-dri-drivers \
    mesa-vulkan-drivers \
    mesa-va-drivers \
    mesa-vdpau-drivers \
    rocm-opencl \
    rocm-smi \
    radeontop

mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/99-amd-performance.conf << 'EOF'
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=5
vm.dirty_ratio=10
EOF

rm -rf /run/dnf /run/selinux-policy /var/cache/dnf /var/cache/yum /tmp/*
