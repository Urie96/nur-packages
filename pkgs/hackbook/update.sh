#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash nix-update
set -eu -o pipefail

nix-update --subpackage web "$UPDATE_NIX_ATTR_PATH"
