{
  moduleWithSystem,
  inputs,
  ...
}: {
  flake.nixosModules.foot = moduleWithSystem ({self', ...}: {
    environment.systemPackages = with self'.packages; [
      foot
    ];
  });
  # PerSystem, gives access to self' and inputs', as well as some helper functions
  perSystem = {
    inputs',
    pkgs,
    ...
  }: {
	# Simple wrapper for foot, sets background color to bright red
    packages.foot = inputs.wrappers.wrappers.foot.wrap {
      inherit pkgs;
      settings = {
        colors-dark.background = "FF0000";
      };
    };
  };
}
