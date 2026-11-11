{...}: {
  # Define flake part nixosModule "hostConfiguration" and pass in arch specific pkgs
  flake.nixosModules.hostConfiguration = {pkgs, ...}: {
    # Normal nix code within module, add git to systemPackages
    environment.systemPackages = with pkgs; [
      git
    ];
  };
}
