# NixOS configuration per mardockOS (port da bootc/Universal Blue)
# Importa il modulo principale e aggiunge le basi di sistema.
{ config, pkgs, ... }:

{
  imports = [ ./modules/mardock.nix ];

  # Base system
  nixpkgs.config.allowUnfree = true;

  # Boot loader (adatta al tuo hardware)
  boot.loader.systemd-boot.enable = true;
  boot.initrd.kernelModules = [ "nvme" "xhci_pci" "veth" "8139too" ];

  # Filesystem (esempio per UEFI + LUKS, adatta ai tuoi partizioni)
  fileSystems."/" = {
    device = "/dev/nvme0n1p2";
    fsType = "btrfs";
  };

  boot.initrd.luks.devices."luks-ssd".device = "/dev/nvme0n1p1";
  boot.initrd.luks.devices."luks-ssd".preLVM = true;

  # Swap
  swapDevices = [ { device = "/dev/nvme0n1p3"; } ];

  # Kernel
  boot.kernelParams = [ "quiet" "splash" ];

  # Hardware (adatta al tuo caso)
  hardware.enableAllHardware = true;

  # Virtualization
  virtualisation = {
    docker.enable = false;
  };

  # GPU / display: usiamo niri via greetd, non X11
  services.xserver.enable = false;

  # Sound
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBootUp = 1;

  # Input
  services.udev.packages = [ pkgs.libinput ];

  # Locale
  i18n.extraLocaleSettings = {
    LC_ALL = "it_IT.UTF-8";
  };

  # Console
  console.keyMap = "it";

  # Users (adatta i nomi) — NB: 'code' → 'vscode' in nixpkgs
  users.users.mardock = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "render" "audio" "dialout" ];
    packages = with pkgs; [ kitty mpv nautilus vscode ];
  };

  # Power management
  services.power-profiles-daemon.enable = true;

  # Print
  services.printing.enable = false;

  # Firewall (adatta)
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];
  networking.firewall.allowedUDPPorts = [ ];

  # Hostname
  networking.hostName = "mardock";

  # Nix settings
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = [ "--delete-older-than" "30d" ];
  };

  # State version — NB: NON duplicare in modules/mardock.nix (override)
  system.stateVersion = "24.11";
}
