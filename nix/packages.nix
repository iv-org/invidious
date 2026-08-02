{ pkgs }:

# Development packages, this makes Crystal 1.19 (latest available in nixpkgs)
# and sqlite available in a `nix-shell` or `nix develop` build environment.
#
# We dont need to add other dependencies like `libxml2` or `libyaml` here
# since they are already available by default in the Crystal Nix package
# (see the output value of CRYSTAL_LIBRARY_PATH when running `crystal env`
# Ref: https://github.com/NixOS/nixpkgs/blob/nixos-26.05/pkgs/development/compilers/crystal/default.nix#L231)
#
with pkgs;
[
  # Invidious dependencies
  crystal_1_19
  sqlite
  shards
  # Utilities
  nixd # Nixd LSP to format .nix files
]
