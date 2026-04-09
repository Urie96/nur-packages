alias u := update
alias b := build

update:
    #!/usr/bin/env bash

    selected="$(just select)";
    if [[ -z "$$selected" ]]; then
      echo "No package selected.";
      exit 0;
    fi;
    mapfile -t pkgs < <(printf '%s\n' "$selected");
    ./update.sh "${pkgs[@]}"

build pkg="":
    #!/usr/bin/env bash

    pkg="{{ pkg }}"

    if [[ -z "$pkg" ]]; then
      pkg="$(just select)"
    fi

    nix-build -A "$pkg"

select:
    @nix-instantiate --eval --json --strict -E 'builtins.attrNames (import ./default.nix {})' | jq -r '.[]' | fzf --multi --prompt='update> '
