#!/usr/bin/env python3
"""Update NeteaseCloudMusicApi from npm registry."""

import json
import subprocess
import sys
from pathlib import Path


def main() -> None:
    pkg_dir = Path(__file__).parent
    flake_root = pkg_dir.parent.parent

    # Step 1: Update source (version + src hash) using nix-update
    print("Step 1: Updating source version and hash...")
    result = subprocess.run(
        [
            "nix-update",
            "--flake",
            "NeteaseCloudMusicApi",
            "--src-only",
        ],
        cwd=flake_root,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"Error: {result.stderr}")
        sys.exit(1)
    if result.stdout:
        print(result.stdout.strip())

    # Step 2: Get src path and copy package.json
    print("\nStep 2: Generating package-lock.json...")

    result = subprocess.run(
        [
            "nix",
            "build",
            "--no-link",
            "--print-out-paths",
            ".#NeteaseCloudMusicApi.src",
        ],
        cwd=flake_root,
        capture_output=True,
        text=True,
        check=True,
    )
    src_path = Path(result.stdout.strip())

    # Copy and clean package.json (remove scripts to skip postinstall)
    pkg_json = json.loads((src_path / "package.json").read_text())
    del pkg_json["scripts"]
    (pkg_dir / "package.json").write_text(json.dumps(pkg_json, indent=2) + "\n")

    # Generate package-lock.json
    subprocess.run(
        ["npm", "install", "--package-lock-only"],
        cwd=pkg_dir,
        check=True,
    )

    # Cleanup package.json
    (pkg_dir / "package.json").unlink()

    # Step 3: Update npmDepsHash using nix-update
    print("\nStep 3: Updating npmDepsHash...")
    result = subprocess.run(
        [
            "nix-update",
            "--flake",
            "packages.aarch64-darwin.NeteaseCloudMusicApi",
            "--no-src",
        ],
        cwd=flake_root,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"Error: {result.stderr}")
        sys.exit(1)
    if result.stdout:
        print(result.stdout.strip())

    print("\nDone!")


if __name__ == "__main__":
    main()
