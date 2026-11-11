{
  # Import self and universal inputs (different to inputs')
  self,
  inputs,
  ...
}: {
  # Define nixosConfiguration with hostname "newHost"
  flake.nixosConfigurations.newHost = inputs.nixpkgs.lib.nixosSystem {
    # Define modules to import
    modules = with self.nixosModules; [
      newHostConfiguration
      desktop
      zsh

      # Change config options in this object
      # This can be done per-host with different options,
      # allowing for smaller changes to modules' functionality
      # Without having to create a whole new module
      ({...}: {
        enableHighlighting = true;
      })
    ];
  };
}
