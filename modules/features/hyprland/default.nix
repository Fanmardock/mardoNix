{moduleWithSystem, ...}: {
	# moduleWithSystem for Hyprland
  flake.nixosModules.hyprland = moduleWithSystem ({self', ...}: {
		# Native wrapper for hyprland instead of environment.systemPackages
    programs.hyprland = {
      enable = true;
      package = self'.packages.hyprland;
    };
  });
  perSystem = {
    inputs',
    pkgs,
    self',
    ...
  }: {
		# Override input pacakge (using inputs' for right version)
    packages.hyprland = inputs'.hyprland.packages.default.override {
			# Change runtimePkgs to add custom foot version
      runtimePkgs = with pkgs;
        [
          waybar
        ]
				# ++ adds two sets together
        ++ (with self'.packages; [
          foot
        ]);
    };
  };
}
