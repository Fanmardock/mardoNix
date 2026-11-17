{moduleWithSystem, inputs,...}: {
  flake.nixosModules.dfiles = moduleWithSystem ({self',pkgs, ...}: {
    imports = [
      inputs.nix-flatpak.nixosModules.default
    ];
    services.flatpak.enable = true;
    services.flatpak.packages = [
      "info.febvre.Komikku"
      "com.bambulab.BambuStudio"
    ];

  # Optional: Automatically add Flathub or configure updates
  services.flatpak.remotes = {
    "flathub" = "https://flathub.org";
  };
  });
  
}
