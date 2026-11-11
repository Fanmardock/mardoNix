{inputs, ...}: {
  # PerSystem, gives access to self' and inputs', as well as some helper functions
  perSystem = {pkgs, ...}: {
    # Define packages as you would in a normal flake
    packages = {
      # Most basic package definition, gives #example output that runs pkgs.hello
      # All packages are outputs, and all outputs can be built, run and cached, etc.
      example = pkgs.hello;
      # Universal wrapper, use this to quickly add flags to a program
      bash = inputs.wrappers.lib.wrapPackage {
        # Always inherit pkgs
        inherit pkgs;
        # Set package, could be anything
        package = pkgs.bash;
        # Flag set, once again can be anything
        # Nix doesn't know what flags are valid, it will accept any two valid nix objects
        # Data types are irrelevant, can be paths, ints, bools, etc.
        flags = {
          "--rcfile" = ./bashrc;
          # to add the same flag twice, make the right hand side a set
          # "--someflag" = {"firstTime", "secondTime"}
          # You cannot repeat the left hand side
        };
      };
    };
  };
}
