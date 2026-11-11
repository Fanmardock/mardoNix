{...}: {
  # Define flake part nixosModule "bootloader" and pass in pkgs
  flake.nixosModules.bootloader = {pkgs, ...}: {
    # Normal nix code
    boot = {
      loader = {
        # Set bootloader timeout
        timeout = 2;
        efi = {
          # Enable efi var mutation
          canTouchEfiVariables = true;
        };
        # Enable grub
        grub = {
          efiSupport = true;
          # Fix resolution issues
          device = "nodev";
        };
      };

      # Set kernel to latest available version
      kernelPackages = pkgs.linuxPackages_latest;
    };
  };
}
