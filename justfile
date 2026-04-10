alias u := update
alias b := build
alias r := repl

update:
    #!/usr/bin/env bash

    selected="$(just select)";
    if [[ -z "$$selected" ]]; then
      echo "No package selected.";
      exit 0;
    fi;
    mapfile -t pkgs < <(printf '%s\n' "$selected");
    ./scripts/update.sh "${pkgs[@]}"

build pkg="":
    #!/usr/bin/env bash

    pkg="{{ pkg }}"

    if [[ -z "$pkg" ]]; then
      pkg="$(just select)"
    fi

    nix-build -A "$pkg"

select:
    @nix-instantiate --eval --json --strict -E 'builtins.attrNames (import ./default.nix {})' | jq -r '.[]' | fzf --multi --prompt='update> '

update-nixpkgs:
    nix --extra-experimental-features nix-command --extra-experimental-features flakes flake update
    ./scripts/update-build-yml-from-flake-lock.py

repl:
    nix repl --file ./default.nix
