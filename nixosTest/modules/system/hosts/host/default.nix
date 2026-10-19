{
	# Import self and universal inputs (different to inputs')
  self,
  inputs,
  ...
}: {
	# Define nixosConfiguration with hostname "host"
  flake.nixosConfigurations.host = inputs.nixpkgs.lib.nixosSystem {
		# Define modules to import
    modules = with self.nixosModules; [
      hostConfiguration
      system
    ];
  };
}
