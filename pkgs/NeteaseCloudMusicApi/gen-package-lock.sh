#!/usr/bin/env bash
set -euo pipefail

src="$(nix-build --no-out-link -E '
let
  pkgs = import <nixpkgs> {};
  pkg = pkgs.callPackage ./default.nix { };
in
  pkg.src
')"

jq 'del(.scripts)' >package.json <"$src/package.json"

npm install --package-lock-only

rm package.json
