{self, ...}: {
  # This module acts as a collection of other modules, for ease
  # of use. Adding another module to this list will import it
  # for all other modules that import this one.

	# Keep in mind that you cannot import this module alongside
	# any of its children. For example, importing this module and
	# the user module in the same block is the same as importing
	# the user module twice, leading to an error due to trying
	# to define the same user twice.

	# Collections should be used for static lists of modules, like
	# those that would make up a basic system, as seen here.

  # Define flake part nixosModule "system"
  flake.nixosModules.system = {...}: let
    modules = with self.nixosModules; [
      user
      networking
      bootloader
      imports
      features
    ];
  in {
    imports = modules;
  };
}