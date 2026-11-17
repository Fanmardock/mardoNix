{moduleWithSystem, inputs,...}: {
  flake.nixosModules.dfiles = moduleWithSystem ({self',pkgs, ...}: {
    imports = [
      inputs.dfiles.nixosModules.dux-files
    ];
    programs.dux-files = {
      enable = true;
      systemd = {
          enable = true;
          target = "graphical-session.target";
          restartIfChanged = true;
        };     
      package = self'.packages.dux-files;
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
