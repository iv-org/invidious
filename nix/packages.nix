{ pkgs }:

# Development packages, this makes Crystal 1.19 (latest available in nixpkgs)
# and sqlite available in a `nix-shell` or `nix develop` build environment.
#
# We dont need to add other dependencies like `libxml2` or `libyaml` here
# since they are already available by default in the Crystal Nix package
# (see the output value of CRYSTAL_LIBRARY_PATH when running `crystal env`
# Ref: https://github.com/NixOS/nixpkgs/blob/nixos-26.05/pkgs/development/compilers/crystal/default.nix#L231)
#
# This dependencies have been tested and used for development with the Zed
# editor, and the Crystal extension https://github.com/crystal-lang-tools/zed-crystal.
# They should work just fine on any other editor that supports `direnv`
#
# (VSCode supports `direnv` with Nix Flakes with this extension:
# https://github.com/direnv/direnv-vscode)
with pkgs;
[
  # Invidious dependencies
  crystal_1_19
  sqlite
  shards
  crystalline # LSP, is not that good, but still useful.
  pkg-config # Required by crystalline
  ameba # For linting
  ameba-ls # LSP for the ameba linter, to get inline messages from ameba
  # Utilities
  nixd # Nixd LSP to format .nix files
]
