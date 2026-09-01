# mardockOS → NixOS module
# Traduzione dichiarativa della configurazione bootc/Universal Blue di mardockOS.
{ config, pkgs, lib, ... }:

let
  dotConfig = ../config;
  dmsFlatpakId = "com.danklinux.DMS";
  dmsGreeterWrapper = pkgs.writeShellScriptBin "dms-greeter" ''
    set -e
    export XDG_RUNTIME_DIR="$${XDG_RUNTIME_DIR:-/run/user/$$(id -u)}"
    if ! flatpak list 2>/dev/null | grep -q "${dmsFlatpakId}"; then
      echo "[mardock] DMS flatpak non trovato, uso niri diretto" >&2
      exec niri
    fi
    if command -v dms-greeter >/dev/null 2>&1; then
      exec dms-greeter --command niri
    else
      exec flatpak run ${dmsFlatpakId} --greeter --command niri
    fi
  '';
in {

  networking.hostName = "mardock";

  environment.variables.CFLAGS = "-O2 -pipe -march=x86-64-v3 -mtune=generic";
  environment.variables.CXXFLAGS = "-O2 -pipe -march=x86-64-v3 -mtune=generic";
  environment.variables.LDFLAGS = "-Wl,-O1,--sort-common";

  nix.settings.substituters = [ "https://cache.nixos.org" ];
  nix.settings.trusted-public-keys = [ "cache.nixos.org-1:6NCH0d39wBVMzTYMngVAexHWTTlx2bxbtstwxT4PwU0=" ];

  environment.systemPackages = with pkgs; [
    niri xwayland-satellite quickshell greetd kitty mpv nautilus vscode
    power-profiles-daemon
    xdg-desktop-portal xdg-desktop-portal-gtk xdg-user-dirs-gtk
    wl-clipboard wtype wl-mirror
    pipewire wireplumber pavucontrol
    bluez blueman
    libva-utils clinfo vulkan-tools
    gnome-keyring
    libvirt virt-manager qemu_kvm
    iotop sysstat gnu-parallel pciutils ddcutil libnotify
    file-roller gvfs gvfs-mtp gvfs-nfs
    gnome-calculator gnome-disk-utility
    flatpak
  ];

  services.greetd = {
    enable = true;
    automaticLoginUser = "greeter";
    configFile = pkgs.writeText "greetd-config.toml" ''
      [terminal]
      vt = "next"

      [default_session]
      user = "greeter"
      command = "dms-greeter --command niri"
    '';
  };

  boot.sysusers = {
    extraGroups = [
      { group = "video";  gid = 44;  }
      { group = "render"; gid = 989; }
    ];
    extraUsers = [
      { user = "greeter"; home = "/var/empty"; shell = pkgs.utillinux + "/bin/true"; }
    ];
  };

  system.tmpfiles = [
    {
      path = "dms-cache.conf";
      contents = ''
        d /var/cache/dms 0770 greeter greeter - -
        Z /var/cache/dms 0770 greeter greeter - -
      '';
    }
  ];

  environment.PATH = [ "${dmsGreeterWrapper}/bin" ] ++ config.environment.PATH;

  environment.etc."niri".source = dotConfig + "/niri";
  environment.etc."kitty".source = dotConfig + "/kitty";

  systemd.services.flatpak-provisioning = {
    description = "Install system Flatpaks on first boot (mardockOS)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    conditionPathExists = "!/var/lib/flatpak-provisioning.done";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    script = ''
      set -e
      flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
      flatpak install --noninteractive --or-update flathub ${dmsFlatpakId} || true
      flatpak install --noninteractive --or-update flathub com.danklinux.DankCalendar || true
      flatpak install --noninteractive --or-update flathub com.danklinux.DankSearch || true
      flatpak install --noninteractive --or-update flathub com.bambulab.BambuStudio || true
      flatpak install --noninteractive --or-update flathub info.febvre.Komikku || true
      flatpak install --noninteractive --or-update flathub com.google.Chrome || true
      touch /var/lib/flatpak-provisioning.done
    '';
  };

  environment.etc."wireplumber/wireplumber.conf.d/50-hdmi-switch.conf".text = ''
    wireplumber.settings = {
        "linking.follow-routes": true
    }
  '';

  environment.etc."profile.d/unmute-audio.sh".text = ''
    if command -v amixer &> /dev/null; then
        (
            sleep 3
            amixer -c 0 set Master unmute 70% &>/dev/null || true
            amixer -c 0 set Speaker unmute 70% &>/dev/null || true
            amixer -c 0 set Front unmute 70% &>/dev/null || true
            amixer set Master unmute 70% &>/dev/null || true
            amixer set Speaker unmute 70% &>/dev/null || true
            amixer -c 0 set IEC958 unmute 100% &>/dev/null || true
            amixer -c 0 set "IEC958,0" unmute 100% &>/dev/null || true
            amixer -c 1 set IEC958 unmute 100% &>/dev/null || true
            amixer -c 1 set "IEC958,0" unmute 100% &>/dev/null || true
        ) &
    fi
  '';

  environment.etc."dconf/db/local.d/00_nautilus-terminal".text = ''
    [com.github.stunkymonkey.nautilus-open-any-terminal]
    terminal='kitty'
  '';

  boot.kernelModules = [ "bluetooth" ];
  boot.extraModprobeConfig = pkgs.writeText "modprobe-mardock.conf" ''
    options bluetooth disable_ertm=1
    options usbcore autosuspend=-1
  '';

  users.groups = {
    audio = { }; video = { }; render = { }; disk = { }; kvm = { };
    input = { }; tty = { }; clock = { }; utmp = { }; plugdev = { };
    lp = { }; bluetooth = { };
  };

  services.libvirtd.enable = true;
  services.pipewire.enable = true;
  services.power-profiles-daemon.enable = true;

  systemd.userServices."dotfiles-setup" = {
    description = "Initial User Dotfiles Setup (mardockOS)";
    after = [ "graphical-session-pre.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = { Type = "oneshot"; };
    script = ''
      FLAG="$HOME/.local/share/dotfiles-setup"
      if [ ! -f "$FLAG" ]; then
          mkdir -p "$HOME/.config" "$HOME/.local/share"
          cp -rn /etc/niri/ "$HOME/.config/niri/" 2>/dev/null || true
          cp -rn /etc/kitty/ "$HOME/.config/kitty/" 2>/dev/null || true
          touch "$FLAG"
      fi
    '';
  };

  hardware.graphics.enable = true;
  hardware.nvidia.modesetting.enable = false;

  console.font = "Lat2-Terminus16";

  networking.networkmanager.enable = true;
  services.openssh.enable = true;

  time.timeZone = "Europe/Rome";
  i18n.defaultLocale = "it_IT.UTF-8";

  security.selinux.enable = false;

  system.stateVersion = "24.11";
}
