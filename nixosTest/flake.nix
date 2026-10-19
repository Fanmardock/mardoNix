{
  description = "some config";

  inputs = {
    # Latest stable nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    # Flake parts utils
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
  };

  # Default import-tree output
  outputs = inputs:
  # Pass all inputs to outputs
    inputs.flake-parts.lib.mkFlake {
      # Call mkFlake from flake-parts module
      inherit inputs; # Inherit inputs (required to get correct arch for self')
    } (inputs.import-tree ./modules); # Pass in all modules using import-tree
}