{ pkgs, inputs, ... }:
{
  programs.dank-material-shell = {
  enable = true;
  niri = {
    enableKeybinds = true;   # Sets static preset keybinds
    enableSpawn = true;      # Auto-start DMS with niri, if enabled
  };
};

}