# Package Updater

Automatically update third-party packages in `pkgs/`.

## Usage

```bash
# Using the nix package (recommended, includes all dependencies)
nix run .#updater -- --list
nix run .#updater -- --dry-run
nix run .#updater -- --pr
nix run .#updater -- --pr -p <name>
nix run .#updater -- --pr --all-systems   # include other platforms' packages

# Or directly with Python (requires nix-update, gh/tea in PATH)
cd pkgs
python3 -m updater --list       # List all updatable packages
python3 -m updater --dry-run    # Preview what would be updated
python3 -m updater              # Update all packages in place
python3 -m updater -p <name>    # Update a single package
python3 -m updater --pr         # Create a PR for each updated package
```

The `--pr` flag uses git worktrees to create PRs without affecting your current
checkout.

## System Filtering

The updater asks the flake which systems expose each package (`nix eval
.#packages.<system> --apply builtins.attrNames`, which `flake.nix` filters with
`meta.availableOn`) and compares that with `builtins.currentSystem`.

By default, packages that only build on another system are skipped:

```
Skipping: only available for aarch64-darwin, not x86_64-linux
```

Two escape hatches:

- `--all-systems` — do not filter. Packages whose `update.py` is platform
  agnostic (`nix-prefetch-url` + hashing) are then updated from any host, e.g.
  `wechat`/`raycast` from Linux. Packages driven by `nix-update` are still
  skipped cross-system, because nix-update derives the new hash by *building*
  the fixed-output `src` derivation and a darwin `fetchurl` cannot be built on
  Linux (`error: platform mismatch`). Give such a package an `update.py` if you
  want it updated from a foreign host.
- `-p <name>` — explicitly naming a package disables the check for it.

Neither flag changes what `nix-update` uses as flake attribute: packages are
updated through the attribute that actually exists (`packages.aarch64-darwin.x`
for darwin-only packages).

Note that all of this only filters *which packages are updated*; the updater
never touches your installed system packages and never runs `nix flake update`.

## Pull Requests (`--pr`)

For each package with an update, the updater creates a branch `update/<name>` in
a temporary worktree, commits, pushes and opens a PR:

- the forge is detected from the remote host: `github.com` → `gh pr create`,
  anything else (Gitea/Forgejo) → `tea pulls create`;
- `--remote` picks the remote to push to (default `origin`);
- every PR gets the `auto-merge` label (`PR_LABEL` in `__main__.py`); it must
  exist on the forge, otherwise PR creation fails and the branch is removed;
- if the PR cannot be opened, the pushed branch is deleted so the package is not
  blocked on the next run;
- a branch that already exists on the remote is treated as "PR already open" and
  skipped without failing.

Commit identity comes from your git config — the CI workflow sets
`git config user.name/user.email` before running the updater (git worktrees
share the repository config, so it applies inside the worktree too).

`tea` picks up credentials from the environment, so no `tea login` is needed
(and nothing is persisted):

```bash
export GITEA_TOKEN=...                    # API token
# one of the two, depending on the tea version
export GITEA_INSTANCE_URL=https://gitea.example.com  # tea 0.15+
export TEA_HOST=https://gitea.example.com            # tea 1.x
```

Set both instance variables to be version independent. With tea < 1.0 you can
also run `tea login add --url ... --token ...` instead.

`git push` never sees these variables. In CI the credential usually comes from
`actions/checkout`, which persists the job token in a git config file included
for the repository *and* its worktrees (`persist-credentials` defaults to true),
so the updater's plain `git push` authenticates by itself. If your runner does
not persist credentials, embed a token in the remote URL instead.

## Automated Runs

`.gitea/workflows/update.yml` runs `nix run .#updater -- --pr --all-systems`
every 5 hours (and on demand via `workflow_dispatch`), opening one PR per
updated package. Gitea Actions does not export credentials on its own: the job
token is only available as `${{ secrets.GITEA_TOKEN }}`, and the server URL as
`${{ github.server_url }}`, so the workflow maps them to `GITEA_TOKEN` / `TEA_HOST`
/ `GITEA_INSTANCE_URL`. Pushing needs no extra step: `actions/checkout` persists
the job token for the repo and its worktrees, and `permissions: contents: write`
/ `pull-requests: write` is what actually grants the rights (Gitea clamps the
request against the repo/user Actions settings).

## Adding a New Package

### Option 1: nix-update (for standard GitHub/GitLab releases)

Create a `nix-update-args` file in your package directory:

```
pkgs/mypackage/
├── default.nix
└── nix-update-args    # Contains nix-update arguments
```

Example `nix-update-args`:

```
--version-regex v(.*)
```

### Option 2: Custom update.py (for non-standard sources)

Create an `update.py` script and `srcs.json` file:

```
pkgs/mypackage/
├── default.nix
├── srcs.json          # {"version": "...", "url": "...", "hash": "..."}
└── update.py          # Must define main() function
```

The `default.nix` should import `srcs.json`:

```nix
let
  srcs = lib.importJSON ./srcs.json;
in
stdenv.mkDerivation {
  pname = "mypackage";
  inherit (srcs) version;

  src = fetchurl {
    inherit (srcs) url hash;
  };
  # ...
}
```

Example `update.py`:

```python
#!/usr/bin/env python3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
from updater import update_srcs

def get_latest_version() -> dict:
    # Fetch latest version info from upstream
    return {"version": "1.0.0", "url": "https://..."}

def main() -> None:
    pkg_dir = Path(__file__).parent
    latest = get_latest_version()
    print(f"Latest version: {latest['version']}")
    update_srcs(pkg_dir, latest["version"], latest["url"])

if __name__ == "__main__":
    main()
```

## Shared Utilities

The `updater` module provides:

- `get_nix_hash(url)` - Fetch SRI hash using nix-prefetch-url
- `read_srcs(pkg_dir)` - Read srcs.json
- `write_srcs(pkg_dir, data)` - Write srcs.json
- `update_srcs(pkg_dir, version, url, hash=None)` - Update if version changed
  (fetches hash if not provided)
