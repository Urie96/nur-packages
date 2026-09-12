#!/usr/bin/env python3
"""Update piExtensions from npm.

Discovered by pkgs/updater, so `just update piExtensions` (and a plain
`just update` / `nix run .#updater`) picks this up automatically.

generate.mjs re-resolves every entry in registry.names against npm:
  * unpinned `name`      -> follows npm's `latest` tag
  * pinned `name@1.2.3`  -> left alone
version changes regenerate the Tier B lockfile, and `--prune` removes entries
(plus their generated lockfiles) that are no longer listed in registry.names.
"""

import subprocess
import sys
from pathlib import Path


def main() -> None:
    pkg_dir = Path(__file__).resolve().parent

    cmd = ["node", str(pkg_dir / "generate.mjs"), "--prune"]
    print(f"Running: {' '.join(cmd)}")

    result = subprocess.run(cmd, cwd=pkg_dir, check=False)
    if result.returncode != 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
