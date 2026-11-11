{moduleWithSystem, inputs, ...}: {
	# moduleWithSystem for Niri
  flake.nixosModules.niri = moduleWithSystem ({self', ...}: {config, lib, ...}: let
    normalUsers = lib.filterAttrs (_: user: user.isNormalUser or false) config.users.users;
  in {
    imports = [
      inputs.niri.nixosModules.niri
    ];
		# Native wrapper for niri instead of environment.systemPackages
    programs.niri = {
      enable = true;
      package = self'.packages.niri;
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
