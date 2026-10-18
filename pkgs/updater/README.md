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
nix run .#updater -- --pr --auto-merge    # also schedule Gitea's auto-merge

# Or directly with Python (requires nix-update, gh in PATH, and GITEA_TOKEN
# when opening PRs on Gitea)
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
  anything else (Gitea/Forgejo) → `POST /repos/{owner}/{repo}/pulls` on the
  Gitea HTTP API (no `tea` binary involved);
- the PR targets the repository's `default_branch` as reported by the API;
- `--remote` picks the remote to push to (default `origin`);
- `--auto-merge` schedules Gitea's native auto-merge on the PR it just opened
  (`POST /pulls/{n}/merge` with `merge_when_checks_succeed`), so the PR lands
  by itself once the required status checks are green. No label and no second
  workflow is involved; the merge style is always `merge` (a merge commit keeps
  the update commit as an ancestor of the target branch). It is a no-op on
  GitHub, which would need a Git App / `gh pr merge --auto` instead;
- if the PR cannot be opened, the pushed branch is deleted so the package is not
  blocked on the next run;
- a branch that already exists on the remote is treated as "PR already open" and
  skipped without failing (the auto-merge was already scheduled then).

Commit identity comes from your git config — the CI workflow sets
`git config user.name/user.email` before running the updater (git worktrees
share the repository config, so it applies inside the worktree too).

Gitea PRs are opened and merged over the API, so only a token is needed (no
`tea login`, nothing is persisted):

```bash
export GITEA_TOKEN=...                               # API token
export GITEA_INSTANCE_URL=https://gitea.example.com  # optional, see below
```

The instance URL is taken from `GITEA_INSTANCE_URL` (or its legacy alias
`TEA_HOST`, which the workflow still exports); when both are unset, the
updater falls back to the URL of the `--remote` git remote. `GITEA_TOKEN` is
used both for `POST /repos/{owner}/{repo}/pulls` and for scheduling the
auto-merge, so `--auto-merge` needs no extra configuration.

`git push` never sees these variables. In CI the credential usually comes from
`actions/checkout`, which persists the job token in a git config file included
for the repository *and* its worktrees (`persist-credentials` defaults to true),
so the updater's plain `git push` authenticates by itself. If your runner does
not persist credentials, embed a token in the remote URL instead.

## Automated Runs

`.gitea/workflows/update.yml` runs `nix run .#updater -- --pr --auto-merge`
every 5 hours (and on demand via `workflow_dispatch`), opening one PR per
updated package and scheduling its merge. Gitea Actions does not export
credentials on its own: the job token is only available as
`${{ secrets.GITEA_TOKEN }}`, and the server URL as `${{ github.server_url }}`,
so the workflow maps them to `GITEA_TOKEN` / `TEA_HOST` / `GITEA_INSTANCE_URL`.
Pushing needs no extra step: `actions/checkout` persists the job token for the
repo and its worktrees, and `permissions: contents: write` /
`pull-requests: write` is what actually grants the rights (Gitea clamps the
request against the repo/user Actions settings).

The workflow passes `secrets.BOT_TOKEN` (a real user's PAT) as `GITEA_TOKEN`,
not the job token: a PR opened with the job token never triggers a
`pull_request` workflow, so the required check would never run and the
scheduled auto-merge would wait forever.

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

## Module Layout

`pkgs/updater/` is a plain Python package (run with `python3 -m updater` from
`pkgs/`), split by responsibility:

| Module | Contents |
| --- | --- |
| `__main__.py` | argparse, discovery, run loop and the summary |
| `package.py` | `Package`/`UpdateResult`, discovery, version lookup |
| `updating.py` | system filtering, `nix-update` / `update.py` execution |
| `pr.py` | worktree, commit, push and PR orchestration |
| `forge.py` | forge detection; GitHub via `gh`, Gitea via the HTTP API |
| `gitops.py` | `run_cmd` and git plumbing (remotes, branches, changes) |
| `__init__.py` | helpers used by `update.py` scripts (`update_srcs`, ...) |
