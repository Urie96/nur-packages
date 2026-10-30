#!/usr/bin/env python3
"""
Update third-party packages in ./pkgs directory.

This script auto-discovers updatable packages:
1. Packages with `nix-update-args` file -> run nix-update with those args
2. Packages with `update.py` file -> import and call main()

Usage:
    python3 -m updater [--dry-run] [--package NAME] [--list] [--pr [--auto-merge]]
"""

import argparse
import sys

from .gitops import get_flake_root
from .package import discover_packages, list_packages
from .pr import create_pr_for_package
from .updating import current_system, skipped, update_package


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Update third-party packages in ./pkgs"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be done without making changes",
    )
    parser.add_argument(
        "--package",
        "-p",
        help="Update only the specified package (ignores the system check)",
    )
    parser.add_argument(
        "--all-systems",
        action="store_true",
        help="Do not skip packages that are not available on the current system "
        "(e.g. update darwin-only packages from Linux)",
    )
    parser.add_argument(
        "--list",
        "-l",
        action="store_true",
        help="List all discovered packages",
    )
    parser.add_argument(
        "--pr",
        action="store_true",
        help="Create a PR for each updated package (uses git worktrees)",
    )
    parser.add_argument(
        "--auto-merge",
        action="store_true",
        help="With --pr: schedule the forge's auto-merge (GitHub: `gh pr merge "
        "--auto`; Gitea: the merge API), so the PR lands by itself once the "
        "required checks pass",
    )
    parser.add_argument(
        "--remote",
        default="origin",
        help="Remote to push update branches to (default: origin)",
    )

    args = parser.parse_args()

    if args.auto_merge and not args.pr:
        parser.error("--auto-merge only makes sense together with --pr")

    flake_root = get_flake_root()
    pkgs_dir = flake_root / "pkgs"

    packages = discover_packages(pkgs_dir)

    if args.list:
        list_packages(packages)
        return 0

    if args.package:
        packages = [p for p in packages if p.name == args.package]
        if not packages:
            print(f"Error: Package '{args.package}' not found")
            return 1

    success_count = 0
    failure_count = 0
    failed: list[str] = []

    # Naming a package explicitly means "do it, I know what I'm doing"; otherwise
    # skip packages whose meta.platforms does not cover this system.
    check_system = not args.all_systems and not args.package

    for pkg in packages:
        if args.pr:
            # PR mode: use worktree to create PR without touching current checkout
            ok = create_pr_for_package(
                pkg,
                flake_root,
                args.dry_run,
                check_system,
                args.remote,
                auto_merge=args.auto_merge,
            )
        else:
            # Normal mode: update in place
            ok = update_package(pkg, flake_root, args.dry_run, check_system).success

        if ok:
            success_count += 1
        else:
            failure_count += 1
            failed.append(pkg.name)

    print(f"\n{'=' * 40}")
    print(f"Results: {success_count} succeeded, {failure_count} failed")
    if skipped:
        print(
            f"Skipped (not available for {current_system()}): "
            f"{', '.join(sorted(skipped))}"
        )
    if failed:
        print(f"Failed packages: {', '.join(failed)}")
        # Gitea/GitHub render this as an annotation at the top of the job.
        print(f"::error::{len(failed)} package(s) failed: {', '.join(failed)}")

    return 0 if failure_count == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
