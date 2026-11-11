{moduleWithSystem, inputs ,...}: {
	# moduleWithSystem for Niri
  flake.nixosModules.niri = moduleWithSystem ({self', ...}: {
		# Native wrapper for niri instead of environment.systemPackages
    programs.niri = {
      enable = true;
      package = self'.packages.niri;
    };
  });
  perSystem = {
    inputs',
    pkgs,
    self',
    ...
  }: {
		# Override input pacakge (using inputs' for right version)
    packages.niri = inputs'.niri.packages.default.override {
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
