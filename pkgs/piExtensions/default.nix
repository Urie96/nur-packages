# piExtensions — pi.dev extensions/packages sourced from npm, driven by
# registry.json instead of a hand-written default.nix per plugin.
#
#   registry.names  curated list of npm package names to track
#   generate.mjs    regenerates registry.json (+ lockfiles for Tier B)
#   registry.json   generated manifest: tarball URL, SRI hash, deps, pi manifest
#   lib/mkPiPackage.nix  builder (Tier A unpack / Tier B buildNpmPackage)
#
# Add a plugin by appending its npm name to registry.names and running:
#   nix shell nixpkgs#nodejs -c node pkgs/piExtensions/generate.mjs

{ pkgs }:

let
  lib = pkgs.lib;

  registry = builtins.fromJSON (builtins.readFile ./registry.json);

  mkPiPackage = pkgs.callPackage ./lib/mkPiPackage.nix { };

  packages = lib.mapAttrs (
    key: entry:
    mkPiPackage (
      entry
      // {
        inherit key;
        packagesDir = ./.;
      }
    )
  ) registry.packages;

in
packages
// {
  # Aggregate so `nix build .#piExtensions.all` and CI can grab everything.
  all = pkgs.linkFarm "pi-extensions-all" (
    lib.mapAttrsToList (name: path: { inherit name path; }) packages
  );

  recurseForDerivations = true;
}
