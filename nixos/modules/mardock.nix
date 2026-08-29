# mardockOS → NixOS module
# Traduzione dichiarativa della configurazione bootc/Universal Blue di mardockOS.
#
# Fonti originali (build_files/scripts/*.sh):
#   00-opts.sh            → mkFlags, gruppi core (già in NixOS)
#   10-repos.sh           → pacchetti nixpkgs equivalenti + note su RPM Fusion
#   20-packages.sh        → environment.systemPackages, servizi
#   30-systemd.sh         → services.greetd + sysusers greeter + tmpfiles dms
#   40-desktop.sh         → niri config, flatpak provisioning, wireplumber,
#                           audio unmute, modprobe bluetooth, gsettings override
#   90-post-build-overlay → NON applicabile (infrastruttura specifica rakuos)
#
# Uso:
#   In configuration.nix: imports = [ ./modules/mardock.nix ];

{ config, pkgs, lib, ... }:

let
  # Directory dotfiles copiati da build_files/dot_config
  dotConfig = ../config;
in {

  networking.hostName = "mardock";

  # ==========================================================
  # 00-opts.sh → CFLAGS x86-64-v3
  # ==========================================================
  environment.systemPackages = with pkgs; [
    # Pacchetti di build (CFLAGS vengono da config.nix / nix.settings, non qui)
  ];

  nix.settings.substituters = [ "https://cache.nixos.org" ];
  nix.settings.trusted-public-keys = [ "cache.nixos.org-1:6NCH0d39wBVMzTYMngVAexHWTTlx2bxbtstwxT4PwU0=" ];

  # ==========================================================
  # 20-packages.sh → Pacchetti di sistema
  # ==========================================================
  environment.systemPackages = with pkgs; [
    # --- Stack desktop niri/DMS (corrispondenza rum install) ---
    niri                       # niri
    xwayland-satellite        # xwayland-satellite
    quickshell                # quickshell (DMS lo usa)
    greetd                    # greetd
    kitty                     # kitty
    mpv                       # mpv
    nautilus                  # nautilus
    code                      # code (VS Code, in nixpkgs come 'code')
    wlr-randr                 # wlr-randr
    power-profiles-daemon     # power-profiles-daemon

    # --- Portali XDG ---
    xdg-desktop-portal
    xdg-desktop-portal-gtk   # xdg-desktop-portal-gtk (in nixpkgs)
    xdg-user-dirs-gtk         # xdg-user-dirs-gtk

    # --- Clipboard / input Wayland ---
    wl-clipboard              # wl-clipboard
    wtype                     # wtype
    wl-mirror                 # wl-mirror

    # --- Audio ---
    pipewire
    wireplumber               # wireplumber (in nixpkgs)
    pavucontrol               # pavucontrol

    # --- Bluetooth ---
    bluez                     # bluez
    blueman                   # blueman
    bluez-alsa                # bluez-tools equivalent (bluez-alsa per A2DP/LE)

    # --- Video / DRM ---
    libva-utils               # libva-utils
    clinfo                    # clinfo
    vulkan-tools              # vulkan-tools

    # --- Keyring / auth ---
    gnome-keyring              # gnome-keyring

    # --- Virtualizzazione ---
    libvirt                   # libvirt
    virt-manager               # virt-manager (in nixpkgs)
    qemu                       # qemu-kvm equivalent

    # --- Utility di sistema ---
    iotop                     # iotop
    sysstat                   # sysstat
    parallel                  # parallel
    rfkill                    # rfkill
    ddcutil                   # ddcutil (in nixpkgs)
    libnotify                 # libnotify

    # --- File manager / archivio ---
    file-roller                # file-roller
    gvfs                       # gvfs
    gvfs-mtp                  # gvfs-mtp
    gvfs-nfs                  # gvfs-nfs

    # --- Applicazioni GNOME ---
    gnome-calculator           # gnome-calculator
    gnome-disk-utility         # gnome-disk-utility

    # --- Flatpak ---
    flatpak                   # flatpak (flatpak-builder in nixpkgs)
  ];

  # ==========================================================
  # 30-systemd.sh → Greetd + DMS greeter
  # ==========================================================
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

  # Sysusers: utente greeter + gruppi video/render (come in 30-systemd.sh)
  services.greetd.extraSysusers = ''
    g video 44 -
    g render 989 -
    u greeter - "Greetd Greeter" - /usr/sbin/nologin
    m greeter video
    m greeter render
  '';

  # tmpfiles: cache directory per DMS (come in 30-systemd.sh)
  system.tmpfiles = [
    {
      path = "dms-cache.conf";
      contents = ''
        d /var/cache/dms 0770 greeter greeter - -
        Z /var/cache/dms 0770 greeter greeter - -
      '';
    }
  ];

  # ==========================================================
  # 40-desktop.sh → Niri configuration
  # ==========================================================
  # Le dot config sono in nixos/config/niri/ (copiate da build_files/dot_config)
  # Le installiamo in /etc/skel/.config/niri/ per il first-boot, e le rendiamo
  # disponibili anche come path Nix per chi vuole usarle direttamente.
  environment.etc."niri".source = dotConfig + "/niri";

  # Kitty config (come in build_files/dot_config/kitty)
  environment.etc."kitty".source = dotConfig + "/kitty";

  # ==========================================================
  # 40-desktop.sh → Flatpak provisioning first-boot
  # ==========================================================
  services.flatpak.enable = true;

  systemd.services.flatpak-provisioning = {
    description = "Install system Flatpaks on first boot (mardockOS)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    conditionPathExists = !/var/lib/flatpak-provisioning.done);
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -e
      flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
      flatpak install --noninteractive --or-update flathub com.bambulab.BambuStudio || true
      flatpak install --noninteractive --or-update flathub info.febvre.Komikku || true
      flatpak install --noninteractive --or-update flathub com.google.Chrome || true
      touch /var/lib/flatpak-provisioning.done
    '';
  };

  # ==========================================================
  # 40-desktop.sh → WirePlumber HDMI auto-switch
  # ==========================================================
  environment.etc."wireplumber/wireplumber.conf.d/50-hdmi-switch.conf".text = ''
    wireplumber.settings = {
        "linking.follow-routes": true
    }
  '';

  # ==========================================================
  # 40-desktop.sh → Audio unmute at login
  # ==========================================================
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

  # ==========================================================
  # 40-desktop.sh → Gsettings: nautilus-open-any-terminal → kitty
  # ==========================================================
  # In NixOS il gschema override si fa via environment.gnome.xsettings-dpi o
  # tramite dconf. Qui lo mettiamo in /etc/dconf/db/local.d/ per l'utente.
  environment.etc."dconf/db/local.d/00_nautilus-terminal".text = ''
    [com.github.stunkymonkey.nautilus-open-any-terminal]
    terminal='kitty'
  '';

  # ==========================================================
  # 20-packages.sh → modprobe: bluetooth ERTM disable + autosuspend off
  # ==========================================================
  boot.kernelModules = [ "bluetooth" ];
  boot.extraModprobeConfig = pkgs.writeText "modprobe-mardock.conf" ''
    options bluetooth disable_ertm=1
    options usbcore autosuspend=-1
  '';

  # ==========================================================
  # 20-packages.sh → xpadneo (driver Xbox controller)
  # ==========================================================
  # In NixOS il modulo kernel si carica con boot.extraModuleDirectories o
  # boot.kernelModules. Se hai il modulo .ko compilato, mettilo in:
  #   /lib/modules/$(uname -r)/hid-xpadneo.ko
  # e aggiungi qui:
  # boot.kernelModules = [ "hid-xpadneo" ];
  # Per ora lo lasciamo commentato: su NixOS non c'è akmod, serve il .ko
  # precompilato o una derivation custom.
  #boot.kernelModules = [ "hid-xpadneo" ];

  # ==========================================================
  # 00-opts.sh → gruppi core (già creati da NixOS, qui solo per chiarezza)
  # ==========================================================
  users.groups = {
    audio   = { };
    video   = { };
    render  = { };
    disk    = { };
    kvm     = { };
    input   = { };
    tty     = { };
    clock   = { };
    utmp    = { };
    plugdev = { };
    lp      = { };
    bluetooth = { };
  };

  # ==========================================================
  # 00-opts.sh → CFLAGS x86-64-v3 (per chi compila da source)
  # ==========================================================
  environment.variables.CFLAGS = "-O2 -pipe -march=x86-64-v3 -mtune=generic";
  environment.variables.CXXFLAGS = "-O2 -pipe -march=x86-64-v3 -mtune=generic";
  environment.variables.LDFLAGS = "-Wl,-O1,--sort-common";

  # ==========================================================
  # Servizi di sistema vari
  # ==========================================================
  services.libvirtd.enable = true;   # libvirt (da 20-packages.sh)
  services.pipewire.enable = true;    # pipewire + wireplumber (da 20-packages.sh)

  # power-profiles-daemon (da 20-packages.sh)
  services.power-profiles-daemon.enable = true;

  # ==========================================================
  # Desktop session: niri come display manager via greetd
  # ==========================================================
  # Il greeter DMS lancia niri. L'utente finale deve avere niri nella
  # PATH e le dot config in ~/.config/niri/ (copiate da /etc/niri/ al first-boot).
  # Per il provisioning del first-boot utente, usa un systemd user unit:
  systemd.userUnits."dotfiles-setup" = {
    description = "Initial User Dotfiles Setup (mardockOS)";
    after = [ "graphical-session-pre.target" ];
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      FLAG="$HOME/.local/share/dotfiles-setup"
      if [ ! -f "$FLAG" ]; then
          mkdir -p "$HOME/.config" "$HOME/.local/share"
          cp -rn /etc/niri/ "$HOME/.config/niri/" 2>/dev/null || true
          cp -rn /etc/kitty/ "$HOME/.config/kitty/" 2>/dev/null || true
          touch "$FLAG"
      fi
    '';
    wantedBy = [ "graphical-session.target" ];
  };

  # ==========================================================
  # Note sui pacchetti NON disponibili in nixpkgs (da 10-repos.sh)
  # ==========================================================
  # RPM Fusion / CoPR packages che non hanno equivalente diretto in nixpkgs:
  #   - dms, dms-greeter       → DMS (DankMaterialShell): flatpak o build from source
  #   - dankcalendar-git        → flatpak: com.danklinux.DankCalendar
  #   - danksearch              → flatpak: com.danklinux.DankSearch
  #   - nautilus-open-any-terminal → CoPR, in nixOS si usa un extension Nautilus
  #                                  oppure un launcher custom
  #   - akmod-xpadneo           → modulo kernel .ko (vedi sopra)
  #
  # Per DMS e i pacchetti DankLinux, il modo più semplice è flatpak:
  #   flatpak install flathub com.danklinux.DMS
  #   flatpak install flathub com.danklinux.DankCalendar
  #   flatpak install flathub com.danklinux.DankSearch
  #
  # Oppure aggiungi un nixpkgs overlay custom con le derivazioni.

  # ==========================================================
  # Hardware / GPU (da 20-packages.sh: libva, vulkan, clinfo)
  # ==========================================================
  hardware.graphics.enable = true;
  hardware.nvidia.modesetting.enable = false; # se hai NVIDIA, metti true

  # ==========================================================
  # Console / terminale di default
  # ==========================================================
  console.font = "Lat2-Terminus16";
  environment.shell = pkgs.kitty; # shell di default per il login (opzionale)

  # ==========================================================
  # Networking base
  # ==========================================================
  networking.networkmanager.enable = true;
  services.openssh.enable = true;

  # ==========================================================
  # Timezone / locale (adatta al tuo caso)
  # ==========================================================
  time.timeZone = "Europe/Rome";
  i18n.defaultLocale = "it_IT.UTF-8";

  # ==========================================================
  # Security: SELinux disabilitato (come in 90-post-build-overlay.sh)
  # ==========================================================
  security.selinux.enable = false;

  # ==========================================================
  # Finalize
  # ==========================================================
  system.stateVersion = "24.11"; # adatta alla tua versione di NixOS
}
