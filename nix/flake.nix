{
  description = "Invidious Nix Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        devPackages = import ./packages.nix { inherit pkgs; };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = devPackages;
        };
      }
    );
}
