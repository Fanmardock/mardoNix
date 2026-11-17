{
  inputs,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.kitty = moduleWithSystem (
    {self'}: {
      environment.systemPackages = with self'.packages; [
        kitty
      ];
    }
  );
  perSystem = {pkgs, ...}: {
    packages.kitty = let
      jetbrains-mono = pkgs.nerd-fonts.jetbrains-mono;
      fontsConf = pkgs.makeFontsConf {
        fontDirectories = [jetbrains-mono];
      };
    in
      inputs.wrappers.wrappers.kitty.wrap {
        inherit pkgs;
        environment = {
          "FONTCONFIG_FILE" = "${fontsConf}";
        };
        font = {
          name = "JetBrainsMono Nerd Font";
          size = 12;
        };
        settings = {
          font_size = 12;
          scrollbar = "never";
          pixel_scroll = false;
          window_padding_width = 9;
          background_opacity = 0.50;
          confirm_os_window_close = 0;
          enable_audio_bell = false;
          cursor_trail = 1;
          cursor_trail_start_threshold = 1;
          cursor_trail_color = "#cba6f7";
          cursor_shape = "beam";
          allow_remote_control = true;
        };
        keybindings = {
          "ctrl+backspace" = "send_text all \\x17";
        };
        extraConfig = ''
          ${builtins.readFile ./kitty.config}
          ${builtins.replaceStrings
            ["include current-theme.conf"]
            [(builtins.readFile ./current-theme.conf)]
            (builtins.readFile ./kitty.conf)}
          ${builtins.readFile ./dank-theme.conf}
          ${builtins.readFile ./dank-tabs.conf}
        '';
      };
  };
}
