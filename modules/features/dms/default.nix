{moduleWithSystem, inputs,...}: {
	# moduleWithSystem for Niri
  flake.nixosModules.dank-material-shell = moduleWithSystem ({self', ...}: {
		# Native wrapper for niri instead of environment.systemPackages
    programs.dank-material-shell = {
      enable = true;
      package = self'.packages.dank-material-shell;
    };
  });
  perSystem = {
    inputs',
    pkgs,
    self',
    ...
  }: {
		# Override input pacakge (using inputs' for right version)
    packages.dank-material-shell = inputs'.dank-material-shell.packages.default.override {
			# Change runtimePkgs to add custom foot version
      runtimePkgs = with pkgs;
        [
          
        ]
				# ++ adds two sets together
        ++ (with self'.packages; [
          
        ]);
    };
  };
}
