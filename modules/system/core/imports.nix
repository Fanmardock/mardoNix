{...}: {
  # Define flake part nixosModule "imports"
  flake.nixosModules.imports = {...}: {
		# Import sibling file 
    imports = [
		# Prefacing file names with underscores means that
		# import-tree will ignore them. You do not need to
		# preface files that don't have a ".nix" ending
      ./_hardware-configuration.nix
    ];
  };
}
