{...}: {
  flake.nixosModules.upower = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      upower
    ];
    services = {
      upower.enable = true;
      power-profiles-daemon.enable = true;
    };
  };
}
