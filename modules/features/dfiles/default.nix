{moduleWithSystem, inputs,...}: {
	# moduleWithSystem for Niri
  flake.nixosModules.dfiles = moduleWithSystem ({self', ...}: {
    imports = [
      inputs.dfiles.nixosModules.dux-files
    ];
		# Native wrapper for niri instead of environment.systemPackages
    programs.dux-files = {
      enable = true;
      systemd = {
          enable = true;
          target = "graphical-session.target";
          restartIfChanged = true;
        };     
      package = self'.packages.dux-files;
      quickshell.package = nixospkgs.quickshell;
      portal = {
        enable = true;      # register the dfiles backend with xdg-desktop-portal
        preferred = true;   # prefer it for org.freedesktop.impl.portal.FileChooser
        desktop = "niri";   # which xdg.portal.config entry gets the preference, "common" by default
      };
    };
  });
  perSystem = {inputs', ...}: {
		# Use the package provided by the input
    packages.dux-files = inputs'.dfiles.packages.dux-files;
  };
}
