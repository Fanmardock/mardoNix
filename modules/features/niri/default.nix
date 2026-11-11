{moduleWithSystem, inputs, ...}: {
	# moduleWithSystem for Niri
  flake.nixosModules.niri = moduleWithSystem ({self', ...}: {
    imports = [
      inputs.niri.nixosModules.niri
    ];
		# Native wrapper for niri instead of environment.systemPackages
    programs.niri = {
      enable = true;
      package = self'.packages.niri;
    };
  });
  perSystem = {inputs', ...}: {
		# Use the package provided by the input
    packages.niri = inputs'.niri.packages.default;
  };
}
