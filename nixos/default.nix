# Entry point per la build della closure di mardockOS (CI).
# Usa nixpkgs 24.11 stabile (pinned via NIXPKGS_URL) e il nostro
# nixos/configuration.nix, senza flake reference.
let
  system = "x86_64-linux";
  pkgs = import <nixpkgs> { inherit system; };
in
(pkgs.nixosSystem {
  nodes.mardock = import ./configuration.nix;
}).mardock.config.system.build.toplevel
