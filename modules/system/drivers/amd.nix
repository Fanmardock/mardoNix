{...}: {
  flake.nixosModules.amdDrivers = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      mesa
      rocmPackages.rocm-smi
      rocmPackages.rocminfo
      vulkan-tools
    ];
    hardware = {
      graphics = {
        enable = true;
        enable32Bit = true;
        extraPackages = with pkgs; [
          libva-vdpau-driver
          libvdpau-va-gl
          rocmPackages.clr.icd
        ];
      };
      amdgpu = {
        initrd.enable = true;
        opencl.enable = true;
      };
    };

    boot.kernelParams = [
      "amdgpu.ppfeaturemask=0xffffffff"
    ];

    # For rOCM
    systemd.tmpfiles.rules = [
      "L+ /opt/rocm - - - - ${pkgs.rocmPackages.clr}"
    ];
  };
}
