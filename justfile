alias u := update
alias b := build

all:
    nix run .#updater -- --list

update pkg:
    nix run .#updater -- -p {{ pkg }}

build pkg="":
    #!/usr/bin/env bash

    pkg="{{ pkg }}"

    if [[ -z "$pkg" ]]; then
      pkg="$(just select)"
    fi

    # nix-build -A "$pkg"
    nix build .#"$pkg"

select:
    @nix-instantiate --eval --json --strict -E 'builtins.attrNames (import ./default.nix {})' | jq -r '.[]' | fzf --multi --prompt='update> '

update-nixpkgs:
    nix --extra-experimental-features 'nix-command flakes' flake update
    ./scripts/update-build-yml-from-flake-lock.py
