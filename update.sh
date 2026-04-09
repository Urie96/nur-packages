#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash nix jq coreutils
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if [[ ! -f default.nix ]]; then
  echo "error: default.nix not found in $ROOT" >&2
  exit 1
fi

requested_attrs=("$@")

mapfile -t package_scripts < <(
  nix-instantiate --eval --json --strict -E '
    let
      repo = import ./default.nix {};
      names = builtins.filter
        (name:
          let pkg = builtins.getAttr name repo; in
          builtins.isAttrs pkg && pkg ? passthru && pkg.passthru ? updateScript
        )
        (builtins.attrNames repo);
    in
      builtins.map
        (name:
          let pkg = builtins.getAttr name repo; in {
            attrPath = name;
            name = pkg.name or name;
            pname = pkg.pname or name;
            oldVersion = pkg.version or "";
            script = toString pkg.passthru.updateScript;
          })
        names
  ' | jq -r '.[] | @base64'
)

if [[ ${#package_scripts[@]} -eq 0 ]]; then
  echo "No packages with passthru.updateScript found."
  exit 0
fi

failed=0
matched=0

for item in "${package_scripts[@]}"; do
  decoded=$(printf '%s' "$item" | base64 --decode)
  attr_path=$(printf '%s' "$decoded" | jq -r '.attrPath')
  pkg_name=$(printf '%s' "$decoded" | jq -r '.name')
  pname=$(printf '%s' "$decoded" | jq -r '.pname')
  old_version=$(printf '%s' "$decoded" | jq -r '.oldVersion')
  script=$(printf '%s' "$decoded" | jq -r '.script')

  if [[ ${#requested_attrs[@]} -gt 0 ]]; then
    should_run=0
    for requested in "${requested_attrs[@]}"; do
      if [[ "$requested" == "$attr_path" ]]; then
        should_run=1
        break
      fi
    done
    if [[ $should_run -eq 0 ]]; then
      continue
    fi
  fi

  matched=$((matched + 1))

  echo "==> Updating $attr_path"
  if [[ ! -f "$script" ]]; then
    echo "!! Script not found: $script" >&2
    failed=1
    echo
    continue
  fi

  if ! env \
    UPDATE_NIX_NAME="$pkg_name" \
    UPDATE_NIX_PNAME="$pname" \
    UPDATE_NIX_OLD_VERSION="$old_version" \
    UPDATE_NIX_ATTR_PATH="$attr_path" \
    "$script"; then
    echo "!! Failed: $attr_path" >&2
    failed=1
  fi
  echo
 done

if [[ ${#requested_attrs[@]} -gt 0 && $matched -eq 0 ]]; then
  echo "No matching packages with passthru.updateScript found for: ${requested_attrs[*]}" >&2
  exit 1
fi

exit $failed
