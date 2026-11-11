{
  description = "some config";

  inputs = {
    # Latest stable nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    # Unstable nixpkgs
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Flake parts utils
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";

    # My Nvim config
    nvim.url = "git+https://git.voidarc.co.uk/voidarc/nvim";

    # Hyprland Configuration
    hyprland = {
      url = "git+https://git.voidarc.co.uk/adumh00man/hyprland-dendritic";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        wrappers.follows = "wrappers";
      };
    };

    dank-material-shell = {
      url = "github:duxlabs-dev/dux-shell/stable";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nix Wrapper Modules
    wrappers.url = "github:nix-community/nix-wrapper-modules";
  };

  # Default import-tree output
  outputs = inputs:
  # Pass all inputs to outputs
    inputs.flake-parts.lib.mkFlake {
      # Call mkFlake from flake-parts module
      inherit inputs; # Inherit inputs (required to get correct arch for self')
    } (inputs.import-tree ./modules); # Pass in all modules using import-tree
}
