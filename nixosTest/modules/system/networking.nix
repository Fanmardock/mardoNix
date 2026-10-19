{...}: {
  # Define flake part nixosModule "networking"
  flake.nixosModules.networking = {...}: {
    # Normal nix code
    networking = {
      # Enable networkManager
      networkmanager = {
        enable = true;
        # Disable router dns
        dns = "none";
      };
      # cloudflare nameservers
      nameservers = [
        "1.1.1.1"
        "8.8.8.8"
      ];
      # disable firewall
      firewall.enable = false;
    };

    # Disable "wait-online" target, makes connecting to network
    # async on boot
    systemd.services.NetworkManager-wait-online.enable = false;
  };
}