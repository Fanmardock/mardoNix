{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.windows-manager = moduleWithSystem ({...}: let
    modules = with self.nixosModules; [
      dank-material-shell
      niri
      kitty
      dfiles
    ];
  in {
    imports = modules;
  });
}
