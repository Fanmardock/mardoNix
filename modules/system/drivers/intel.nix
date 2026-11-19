{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.intelDrivers = {
    pkgs,
    lib,
    ...
  }: {
    environment.systemPackages = with pkgs; [
      mesa
      vulkan-tools
    ];

    environment.sessionVariables = {
      LIBVA_DRIVER_NAME = "iHD";
    };

    boot.initrd.kernelModules = ["i915"];
    services.xserver.videoDrivers = ["modesetting"];

    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        vpl-gpu-rt
        intel-compute-runtime
      ];
    };
  };
}
