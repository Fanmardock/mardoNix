{moduleWithSystem, inputs, ...}: {
	# moduleWithSystem for Niri
  flake.nixosModules.niri = moduleWithSystem ({self', ...}: {config, lib, pkgs, ...}: let
    normalUsers = lib.filterAttrs (_: user: user.isNormalUser or false) config.users.users;
  in {
    imports = [
      inputs.niri.nixosModules.niri
      inputs.dank-greeter.nixosModules.default
    ];
		# Native wrapper for niri instead of environment.systemPackages
    programs.niri = {
      enable = true;
      package = self'.packages.niri;
    };

    programs.dms-greeter = {
      enable = true;
      package = inputs.dank-greeter.packages.${pkgs.system}.dms-greeter;
      compositor = {
        name = "niri";
        customConfig = ''
          hotkey-overlay {
            skip-at-startup
          }

          environment {
            DMS_RUN_GREETER "1"
          }

          gestures {
            hot-corners {
              off
            }
          }

          layout {
            background-color "#000000"
          }
        '';
      };
      configHome = config.users.users.user01.home;
      logs.save = true;
    };

    systemd.tmpfiles.rules = lib.concatLists (lib.mapAttrsToList (name: user: [
      "d ${user.home}/.config/niri 0755 ${name} ${user.group} - -"
      "C+ ${user.home}/.config/niri/config.kdl 0644 root root - ${./config.kdl}"
    ]) normalUsers);
  });
  perSystem = {inputs', ...}: {
		# Use the package provided by the input
    packages.niri = inputs'.niri.packages.niri-stable;
  };
}
