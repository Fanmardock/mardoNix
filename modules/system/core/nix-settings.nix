{inputs, ...}: {
  # PerSystem, allows for universal module access
  perSystem = {system, ...}: {
    # Pre-defined object
    _module.args = {
      # Custom object, creating a new nixpkgs from a different input
      unstablePkgs = import inputs.nixpkgs-unstable {
        inherit system;
      };

      # Another example not in the video, creating an unfree instance of nixpkgs
      # Setting nixpkgs.config.free = true isn't possible through a normal nixosModule,
      # because of how inheritance works with nixos exclusive objects
      unfreePkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # You can also set universal variables here, if you need to access the same info across files
      someVariable = "import this as you would import pkgs, in a perSystem block";
    };
  };
}
