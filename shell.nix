{
  pkgs ? import <nixpkgs> { },
}:

let
  devPackages = import ./packages.nix { inherit pkgs; };
in

pkgs.mkShell {
  buildInputs = devPackages;
}
