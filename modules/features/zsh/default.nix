{
  inputs,
  # moduleWithSystem allows for using self' in modules
  moduleWithSystem,
  ...
}: {
  # enclose moduleWithSystem expression in (), so the final expression is one object
  flake.nixosModules.zsh = moduleWithSystem ({
      pkgs,
      # Self' allows accessing packages without having to point to the os string
      self',
      ...
    }:
    # This is a "double expression", being written like {...}: {...}: {};
    # having an extra {...}. This is because the first attribute set only contains
    # flake parts attributes (self', flake.nixosModules, etc), and not nixos attributes.
    # The usual nixos attributes, like config, are passed into a potential second attribute
    # set, allowing you to access them there. This set is not implicit, and must be defined.
    # This means that the code can be read as:
    # {flake-parts attrs}: {nix attrs}: {actual expression};
    {config, ...}:
    # A let in statement allows setting of variables, in this case pointing any reference
    # of "lib" to "pkgs.lib". These can be stacked, and can be thought of as a way of
    # scoping variables.
    let
      lib = pkgs.lib;
    in {
      # When the config or options objects are defined, nothing else can be in the expression.
      # Options contains a list of defined options, and config becomes the wrapper for everything
      # else in the expression. Imports works as expected.
      imports = [];
      options = {
        # Make a new option with lib.mkOption
        enableHighlighting = lib.mkOption {
          # Set type, eg bool, str, int. Custom types can be created
          type = lib.types.bool;
          # Default value is required
          default = false;
          # Description is optional but useful
          description = "Enable syntax highlighting";
        };
      };
      config = {
        # Nixpkgs overlay, replacing the universal "pkgs.zsh" with "self'.packages.zsh".
        # As stated, self' allows you to shorten the package definition from
        # self.${pkgs.stdenv.hostPlatform.system}.packages.zsh;
        # into just self'.packages.zsh, meaning package platform errors are almost impossible.
        nixpkgs.overlays = [
          (final: prev: {
            zsh = self'.packages.zsh;
          })
        ];
        programs.zsh = {
          enable = true;
          # You can use config options through the config attribute, in place of a normal value,
          # the same way you can in other programming languages.
          enableSyntaxHighlighting = config.enableHighlighting;
        };
      };
    });
  # PerSystem should be defined in the same scope as flake.nixosModules
  perSystem = {
    # Inherited from inputs.nixpkgs
    pkgs,
    # Custom arg, see modules/system/nix-settings.nix
    unstablePkgs,
    # Same principle of self', removes need for direct reference to os-string
    inputs',
    # Helper, points to pkgs.lib
    lib,
    ...
  }: {
    # Defined wrapper for zsh, docs are on nix-wrapper modules site
    packages.zsh = inputs.wrappers.wrappers.zsh.wrap {
      # Pkgs MUST be defined, always inherit pkgs in a wrapper
      inherit pkgs;
      zshAliases = {
        # By making an alias reference a package, zsh becomes dependant on that package.
        # This idea allows for fully portable modules with implicit dependancy trees
        some = lib.getExe unstablePkgs.vim;
        v = lib.getExe inputs'.nvim.packages.default;
        ff = lib.getExe pkgs.fastfetch;
        cat = lib.getExe pkgs.bat;
      };
      # Can also be zshrc.path, and path will take precedence over content.
      zshrc.content = ''
        export SOME=some
      '';
    };
  };
}
