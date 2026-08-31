# Entry point per la CI / build locale della closure di mardockOS (non-flake).
#
# Ermetico: nixpkgs 24.11 STABILE è pinnato qui dentro con fetchTarball, quindi
# non dipende da canali, NIX_PATH o NIXPKGS_URL (l'installer Nix sui runner
# GitHub aggiunge un canale che altrimenti farebbe risolvere <nixpkgs> su
# master, dove questa configurazione non esiste più).
#
# NB: in nixpkgs 24.11 `pkgs.nixosSystem` NON esiste più come attributo del
# set pacchetti (vive solo come output di flake); l'entry point non-flake
# corretto è <nixpkgs>/nixos/default.nix, che prende `configuration` + `system`
# e restituisce `.system` = la toplevel della closure.
{ system ? "x86_64-linux" }:
let
  nixpkgs = fetchTarball "github:NixOS/nixpkgs?rev=nixos-24.11";
in
(import (nixpkgs + "/nixos/default.nix") {
  inherit system;
  configuration = import ./configuration.nix;
}).system
