# mardockOS — entry point di build (flake).
#
# Ermetico e stabile: l'input `nixpkgs` è pinnato alla branch di release
# `nixos-24.11` (NON master/unstable). La flake locka il rev esatto in
# /nix/store, quindi ogni build usa sempre lo stesso 24.11.
#
# `lib.nixosSystem` è l'entry point standard per NixOS 24.11 (il vecchio
# attributo `pkgs.nixosSystem` non esiste più nel set pacchetti).
{
  description = "mardockOS — NixOS configuration (CI build test)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
  in {
    # Costruisce il sistema NixOS completo.
    # `.system` == nixosConfigurations.mardock.config.system.build.toplevel,
    # cioè la toplevel = l'intera closure (tutti i pacchetti compilati).
    nixosConfigurations.mardock = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [ ./nixos/configuration.nix ];
    };
  };
}
