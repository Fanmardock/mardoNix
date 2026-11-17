{
  moduleWithSystem,
  self,
  ...
}: {
  # Desktop Attribute, brings together all things you would need for a desktop

  # Segmenting like this makes it easier to have different types of machines
  # Using the same config, like having a "laptop" attribute if you need different
  # packages there, etc.
  flake.nixosModules.desktop = moduleWithSystem ({pkgs, unfreePkgs, ...}: let
    modules = with self.nixosModules; [
      core
      networking
      dank-material-shell
      niri
      kitty
      dfiles
    ];
  in {
    imports = modules;

    virtualisation.vmVariant.virtualisation = {
      graphics = true;
      qemu.options = [
        "-vga none"
        "-device virtio-vga-gl"
        "-display gtk,gl=on"
      ];
    };

    # Add those packages to every desktop
    environment.systemPackages =
      (with pkgs; [
        lazygit
        mpv
        blueman
        pipewire
        bluez
        bluez-tools
        quickshell
        go_1_27
      ])
      ++ [unfreePkgs.google-chrome];
  });
}
