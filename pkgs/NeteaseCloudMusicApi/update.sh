#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash nix-update nodejs jq
set -eu -o pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

gen-package-lock() {
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
}

nix-update --src-only "$UPDATE_NIX_ATTR_PATH"

(cd "$DIR" && gen-package-lock)

nix-update --no-src "$UPDATE_NIX_ATTR_PATH"
