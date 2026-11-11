{...}: {
  # Define flake part nixosModule "newHostConfiguration" and pass in arch specific pkgs
  flake.nixosModules.newHostConfiguration = {pkgs, ...}: {
    # Normal nix code within module, add git to systemPackages
    environment.systemPackages = with pkgs; [
      fastfetch
    ];
  };
}
