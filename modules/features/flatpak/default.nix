{inputs, ...}: {
  flake.nixosModules.flatpak = {
    imports = [
      inputs.nix-flatpak.nixosModules.nix-flatpak
    ];

    services.flatpak = {
      enable = true;
      packages = [
        "info.febvre.Komikku"
        "com.bambulab.BambuStudio"
      ];
    };
  };
}
