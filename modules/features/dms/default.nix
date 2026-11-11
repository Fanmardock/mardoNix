{moduleWithSystem, inputs,...}: {
	# moduleWithSystem for Niri
  flake.nixosModules.dank-material-shell = moduleWithSystem ({self', ...}: {
    imports = [
      inputs.dank-material-shell.nixosModules.default
    ];
		# Native wrapper for niri instead of environment.systemPackages
    programs.dank-material-shell = {
      enable = true;
      package = self'.packages.dank-material-shell;
    };
  });
  perSystem = {inputs', ...}: {
		# Use the package provided by the input
    packages.dank-material-shell = inputs'.dank-material-shell.packages.default;
  };
}
