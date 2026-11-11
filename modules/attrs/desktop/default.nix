{
  moduleWithSystem,
  self,
  ...
}: {
  # Desktop Attribute, brings together all things you would need for a desktop

  # Segmenting like this makes it easier to have different types of machines
  # Using the same config, like having a "laptop" attribute if you need different
  # packages there, etc.
  flake.nixosModules.desktop = moduleWithSystem ({pkgs, ...}: let
    modules = with self.nixosModules; [
      core
      networking
      hyprland
      dank-material-shell
      niri
    ];
  in {
    imports = modules;

    # Add lazygit to every desktop
    environment.systemPackages = with pkgs; [
      lazygit
    ];
  });
}
