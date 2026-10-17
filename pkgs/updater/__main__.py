#!/usr/bin/env python3
"""
Update third-party packages in ./pkgs directory.

This script auto-discovers updatable packages:
1. Packages with `nix-update-args` file -> run nix-update with those args
2. Packages with `update.py` file -> import and call main()

Usage:
    python3 -m updater [--dry-run] [--package NAME] [--list] [--pr]
"""

import argparse
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import traceback
import urllib.parse
from dataclasses import dataclass
from pathlib import Path

# Label added to the PRs opened by `--pr`; it must exist on the forge.
PR_LABEL = "auto-merge"


@dataclass
class Package:
    name: str
    method: str  # "nix-update" or "custom"
    path: Path
    extra_args: list[str] | None = None


@dataclass
class UpdateResult:
    package: Package
    success: bool
    changed: bool
    old_version: str | None = None
    new_version: str | None = None


def get_flake_root() -> Path:
    """Discover the flake root via git rev-parse.

    When installed via Nix, __file__ is in /nix/store, so we cannot
    derive the repo layout from the script location. Instead we find
    the git toplevel, which is the flake root.
    """
    result = run_cmd(["git", "rev-parse", "--show-toplevel"], check=False)
    if result.returncode != 0:
        sys.exit("Error: not inside a git repository")
    return Path(result.stdout.strip())


def run_cmd(
    cmd: list[str], cwd: Path | None = None, check: bool = True
) -> subprocess.CompletedProcess[str]:
    """Run a command and return the result."""
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, check=check)


def git_has_changes(flake_root: Path) -> bool:
    """Check if there are uncommitted changes."""
    result = run_cmd(["git", "status", "--porcelain"], cwd=flake_root, check=False)
    return bool(result.stdout.strip())


def git_get_changes(flake_root: Path) -> str:
    """Get list of changed files."""
    result = run_cmd(["git", "status", "--porcelain"], cwd=flake_root, check=False)
    return result.stdout.strip()


def get_current_version(pkg: Package) -> str | None:
    """Get the version a package currently declares.

    `srcs.json` for update.py-based packages, otherwise the literal
    `version = "...";` in `default.nix` (packages that `inherit (srcs) version`
    are covered by the first branch). Used for commit messages and PR titles.
    """
    srcs_file = pkg.path / "srcs.json"
    if srcs_file.exists():
        try:
            data: dict[str, str] = json.loads(srcs_file.read_text())
            if data.get("version"):
                return data["version"]
        except json.JSONDecodeError:
            pass
    return None


def discover_packages(pkgs_dir: Path) -> list[Package]:
    """Discover all updatable packages."""
    packages: list[Package] = []

    for pkg_dir in pkgs_dir.iterdir():
        if not pkg_dir.is_dir():
            continue

        # Skip the updater package itself
        if pkg_dir.name == "updater":
            continue

        # Check for nix-update-args file
        nix_update_args_file = pkg_dir / "nix-update-args"
        if nix_update_args_file.exists():
            args = nix_update_args_file.read_text().strip().split()
            packages.append(
                Package(
                    name=pkg_dir.name,
                    method="nix-update",
                    path=pkg_dir,
                    extra_args=args,
                )
            )
            continue

        # Check for update.py file
        update_script = pkg_dir / "update.py"
        if update_script.exists():
            packages.append(
                Package(
                    name=pkg_dir.name,
                    method="custom",
                    path=pkg_dir,
                )
            )

    return sorted(packages, key=lambda p: p.name)


def get_nix_system() -> str:
    """Get the current Nix system identifier."""
    result = run_cmd(
        ["nix", "eval", "--raw", "--impure", "--expr", "builtins.currentSystem"],
        check=False,
    )
    if result.returncode == 0:
        return result.stdout.strip()
    return "x86_64-linux"


_cached_system: str | None = None


def current_system() -> str:
    """Get and cache the current Nix system."""
    global _cached_system  # noqa: PLW0603
    if _cached_system is None:
        _cached_system = get_nix_system()
    return _cached_system


# flake root -> {system: attribute names exposed under `packages.<system>`}
_system_maps: dict[str, dict[str, set[str]]] = {}

# Packages skipped because they do not build on this system.
_skipped: set[str] = set()


def flake_systems(flake_root: Path) -> list[str]:
    """List the systems the flake declares (attr names of `legacyPackages`)."""
    result = run_cmd(
        ["nix", "eval", "--json", ".#legacyPackages", "--apply", "builtins.attrNames"],
        cwd=flake_root,
        check=False,
    )
    if result.returncode != 0:
        print(f"Warning: could not read flake systems: {result.stderr.strip()}")
        return [current_system()]
    try:
        return list(json.loads(result.stdout))
    except json.JSONDecodeError:
        return [current_system()]


def available_by_system(flake_root: Path) -> dict[str, set[str]]:
    """Map system -> names exposed by `packages.<system>`.

    `flake.nix` filters `packages` with `meta.availableOn`, so membership in a
    set is exactly "buildable on that system". Attribute names are enough, so
    this stays lazy (no derivations get forced).
    """
    key = str(flake_root)
    if key in _system_maps:
        return _system_maps[key]

    mapping: dict[str, set[str]] = {}
    for system in flake_systems(flake_root):
        result = run_cmd(
            [
                "nix",
                "eval",
                "--json",
                f".#packages.{system}",
                "--apply",
                "builtins.attrNames",
            ],
            cwd=flake_root,
            check=False,
        )
        names: set[str] = set()
        if result.returncode == 0:
            try:
                names = set(json.loads(result.stdout))
            except json.JSONDecodeError:
                pass
        mapping[system] = names

    _system_maps[key] = mapping
    return mapping


def publish_system(pkg_name: str, flake_root: Path) -> str | None:
    """System whose `packages.<system>` exposes pkg_name (current system first).

    Returns None when the name is not a plain derivation anywhere in the flake
    (e.g. `piExtensions` is an attribute set).
    """
    mapping = available_by_system(flake_root)
    current = current_system()
    if pkg_name in mapping.get(current, ()):
        return current
    for system, names in mapping.items():
        if pkg_name in names:
            return system
    return None


def check_available(pkg: Package, flake_root: Path) -> bool:
    """Return False (and explain why) if pkg cannot be built on this system."""
    target = publish_system(pkg.name, flake_root)
    current = current_system()
    if target is None or target == current:
        return True
    print(f"  Skipping: only available for {target}, not {current}")
    _skipped.add(pkg.name)
    return False


def run_nix_update(
    pkg: Package,
    flake_root: Path,
    dry_run: bool = False,
    check_system: bool = True,
) -> bool:
    """Run nix-update for a package."""
    current = current_system()

    if check_system and not check_available(pkg, flake_root):
        return True  # Not a failure, just not applicable

    # Update through the attribute that actually exists: darwin-only packages
    # are not in `packages.x86_64-linux`, so use `packages.aarch64-darwin`.
    target = publish_system(pkg.name, flake_root) or current

    if target != current:
        # nix-update derives the new hash by building the (fixed-output) src
        # derivation, and a fetchurl for another platform cannot be built here:
        #   error: Cannot build ...dmg.drv: platform mismatch
        # Packages with a custom update.py have no such problem because they
        # call nix-prefetch-url directly, so they *can* cross-update.
        print(
            f"  Skipping: nix-update needs a native {target} host "
            "(give this package an update.py to update it from here)"
        )
        _skipped.add(pkg.name)
        return True

    cmd = [
        "nix-update",
        "--flake",
        f"packages.{target}.{pkg.name}",
    ]

    if pkg.extra_args:
        cmd.extend(pkg.extra_args)

    print(f"  Running: {' '.join(cmd)}")

    if dry_run:
        print("  (dry-run, skipping)")
        return True

    result = subprocess.run(
        cmd, check=False, cwd=flake_root, capture_output=True, text=True
    )

    if result.returncode != 0:
        print(f"  Error: {result.stderr}")
        return False

    if result.stdout:
        print(f"  {result.stdout.strip()}")

    return True


def run_custom_update(
    pkg: Package,
    flake_root: Path,
    dry_run: bool = False,
    check_system: bool = True,
) -> bool:
    """Import and run main() from update.py."""
    if check_system and not check_available(pkg, flake_root):
        return True  # Not a failure, just not applicable

    update_script = pkg.path / "update.py"

    print(f"  Running: {update_script}")

    if dry_run:
        print("  (dry-run, skipping)")
        return True

    spec = importlib.util.spec_from_file_location(f"update_{pkg.name}", update_script)
    if spec is None or spec.loader is None:
        print(f"  Error: Could not load {update_script}")
        return False

    module = importlib.util.module_from_spec(spec)
    sys.modules[f"update_{pkg.name}"] = module
    spec.loader.exec_module(module)

    if not hasattr(module, "main"):
        print(f"  Error: {update_script} has no main() function")
        return False

    # A single broken update.py must not abort the whole run (the other
    # packages still deserve their PR). `sys.exit()` raises SystemExit, which is
    # a BaseException, so it needs its own handler — every update.py in this repo
    # ends with sys.exit(1) on failure.
    try:
        module.main()
    except SystemExit as exc:
        code = exc.code if isinstance(exc.code, int) else 1
        if code == 0:
            return True
        print(f"  Error: {pkg.name}/update.py exited with {code}")
        return False
    except Exception:  # noqa: BLE001 - third-party script boundary
        traceback.print_exc()
        print(f"  Error: {pkg.name}/update.py raised")
        return False

    return True


def update_package(
    pkg: Package,
    flake_root: Path,
    dry_run: bool = False,
    check_system: bool = True,
) -> UpdateResult:
    """Update a single package and return the result."""
    print(f"\nUpdating {pkg.name} (method: {pkg.method})...")

    old_version = get_current_version(pkg)

    # Check for existing changes before update
    had_changes_before = git_has_changes(flake_root)

    if pkg.method == "nix-update":
        success = run_nix_update(pkg, flake_root, dry_run, check_system)
    elif pkg.method == "custom":
        success = run_custom_update(pkg, flake_root, dry_run, check_system)
    else:
        print(f"  Error: Unknown method: {pkg.method}")
        success = False

    new_version = get_current_version(pkg)
    changed = not had_changes_before and git_has_changes(flake_root)

    return UpdateResult(
        package=pkg,
        success=success,
        changed=changed,
        old_version=old_version,
        new_version=new_version,
    )


def get_remote_url(remote: str, flake_root: Path) -> str | None:
    """Return the URL of a git remote, or None if it does not exist."""
    result = run_cmd(
        ["git", "remote", "get-url", remote], cwd=flake_root, check=False
    )
    url = result.stdout.strip()
    return url or None


def remote_host(url: str) -> str | None:
    """Extract the host from an https://, ssh://, git@host:path or file:// URL."""
    if "://" in url:
        return urllib.parse.urlparse(url).hostname
    if "@" in url:  # scp-like: git@github.com:owner/repo.git
        return url.split("@", 1)[1].split(":", 1)[0]
    if ":" in url:
        return url.split(":", 1)[0]
    return None


def remote_slug(url: str) -> str | None:
    """Extract `owner/repo` from a remote URL."""
    if "://" in url:
        path = urllib.parse.urlparse(url).path
    elif ":" in url:  # scp-like
        path = url.split(":", 1)[1]
    else:
        path = url
    slug = path.strip("/").removesuffix(".git")
    parts = slug.split("/")
    if len(parts) < 2:
        return None
    return "/".join(parts[-2:])


def resolve_forge(flake_root: Path, remote: str) -> str:
    """Decide whether to open the PR with `gh` (GitHub) or `tea` (Gitea)."""
    url = get_remote_url(remote, flake_root)
    host = remote_host(url) if url else None
    if host and "github" in host.lower():
        return "gh"
    if host:
        return "tea"
    print(f"  Warning: unknown remote '{remote}', falling back to gh")
    return "gh"


def create_pr_command(
    forge: str,
    remote: str,
    slug: str | None,
    title: str,
    body: str,
) -> list[str]:
    """Build the CLI invocation that opens the pull request."""
    if forge == "gh":
        cmd = ["gh", "pr", "create", "--title", title, "--body", body]
        if slug:
            cmd.extend(["--repo", slug])
        cmd.extend(["--label", PR_LABEL])
        return cmd

    # tea (Gitea/Forgejo). `--remote` lets it pick the matching login.
    cmd = [
        "tea",
        "pulls",
        "create",
        "--remote",
        remote,
        "--title",
        title,
        "--description",
        body,
    ]
    if slug:
        cmd.extend(["--repo", slug])
    cmd.extend(["--labels", PR_LABEL])
    return cmd


def open_pull_request(
    worktree_path: Path,
    commit_msg: str,
    pr_body: str,
    remote: str,
) -> bool:
    """Run gh/tea to open the PR."""
    url = get_remote_url(remote, worktree_path)
    slug = remote_slug(url) if url else None
    forge = resolve_forge(worktree_path, remote)

    if forge == "tea" and not os.environ.get("GITEA_TOKEN"):
        print(
            "  Hint: tea has no credentials — export GITEA_TOKEN together with "
            "GITEA_INSTANCE_URL/TEA_HOST, or run `tea login add` (tea < 1.0)"
        )

    cmd = create_pr_command(forge, remote, slug, commit_msg, pr_body)
    print(f"  Running: {' '.join(cmd)}")
    result = run_cmd(cmd, cwd=worktree_path, check=False)
    if result.returncode != 0:
        print(f"  Error creating PR with {forge}: {result.stderr.strip()}")
        return False

    print(f"  Created PR: {result.stdout.strip()}")
    return True


def delete_remote_branch(remote: str, branch: str, cwd: Path) -> None:
    """Remove a pushed branch so a retry is not blocked by a stale ref."""
    result = run_cmd(
        ["git", "push", remote, "--delete", branch], cwd=cwd, check=False
    )
    if result.returncode == 0:
        print(f"  Deleted remote branch {branch}")
    else:
        print(
            f"  Warning: could not delete remote branch {branch}: "
            f"{result.stderr.strip()}"
        )


def create_pr_for_package(
    pkg: Package,
    flake_root: Path,
    dry_run: bool = False,
    check_system: bool = True,
    remote: str = "origin",
) -> bool:
    """Create a PR for a package update using a git worktree."""
    branch_name = f"update/{pkg.name}"

    print(f"\nCreating PR for {pkg.name}...")

    # Bail out before creating a worktree for packages we cannot build here.
    if check_system and not check_available(pkg, flake_root):
        return True  # Not a failure, just not applicable

    if dry_run:
        # Preview exactly what the real run would do, without touching git.
        update_package(pkg, flake_root, dry_run=True, check_system=check_system)
        return True

    # An existing branch means an earlier run already opened a PR for it;
    # treat that as "nothing to do", otherwise a 5-hourly job goes red forever.
    check_branch = run_cmd(
        ["git", "ls-remote", "--heads", remote, branch_name],
        cwd=flake_root,
        check=False,
    )
    if check_branch.stdout.strip():
        print(f"  Branch {branch_name} already exists on {remote}, skipping")
        return True

    return _create_pr_in_worktree(pkg, flake_root, branch_name, remote)


def _create_pr_in_worktree(
    pkg: Package,
    flake_root: Path,
    branch_name: str,
    remote: str = "origin",
) -> bool:
    """Create PR using a temporary worktree."""
    with tempfile.TemporaryDirectory() as tmpdir:
        worktree_path = Path(tmpdir) / "worktree"

        # Create worktree with new branch
        result = run_cmd(
            ["git", "worktree", "add", "-b", branch_name, str(worktree_path)],
            cwd=flake_root,
            check=False,
        )
        if result.returncode != 0:
            print(f"  Error creating worktree: {result.stderr}")
            return False

        try:
            return _run_update_and_create_pr(
                pkg, flake_root, worktree_path, branch_name, remote
            )
        finally:
            # Clean up worktree and branch
            run_cmd(
                ["git", "worktree", "remove", "--force", str(worktree_path)],
                cwd=flake_root,
                check=False,
            )
            run_cmd(["git", "branch", "-D", branch_name], cwd=flake_root, check=False)


def _run_update_and_create_pr(
    pkg: Package,
    flake_root: Path,
    worktree_path: Path,
    branch_name: str,
    remote: str = "origin",
) -> bool:
    """Run update in worktree and create PR."""
    old_version = get_current_version(pkg)

    # Run the update in the worktree
    worktree_pkg = Package(
        name=pkg.name,
        method=pkg.method,
        path=worktree_path / "pkgs" / pkg.name,
        extra_args=pkg.extra_args,
    )

    if pkg.method == "nix-update":
        success = run_nix_update(
            worktree_pkg, worktree_path, dry_run=False, check_system=False
        )
    elif pkg.method == "custom":
        # Availability was already checked against the main checkout in
        # create_pr_for_package; re-checking here would evaluate the flake from
        # inside the worktree, which is both slow and fragile.
        success = run_custom_update(
            worktree_pkg, worktree_path, dry_run=False, check_system=False
        )
    else:
        success = False

    if not success:
        print("  Update failed")
        return False

    if not git_has_changes(worktree_path):
        print("  No changes, already up to date")
        return True  # Not a failure, just nothing to do

    new_version = get_current_version(worktree_pkg)
    old_ver = old_version or "unknown"
    new_ver = new_version or "unknown"

    # Commit and push
    run_cmd(["git", "add", "-A"], cwd=worktree_path)
    commit_msg = f"{pkg.name}: {old_ver} -> {new_ver}"
    commit_result = run_cmd(
        ["git", "commit", "-m", commit_msg], cwd=worktree_path, check=False
    )
    if commit_result.returncode != 0:
        print(f"  Error committing: {commit_result.stderr}")
        return False

    push_result = run_cmd(
        ["git", "push", "-u", remote, branch_name],
        cwd=worktree_path,
        check=False,
    )
    if push_result.returncode != 0:
        print(f"  Error pushing to {remote}: {push_result.stderr}")
        return False

    # Create PR
    pr_body = f"Automated update of {pkg.name} from {old_ver} to {new_ver}."
    if not open_pull_request(worktree_path, commit_msg, pr_body, remote):
        # Leaving the branch behind would make every later run skip this package.
        delete_remote_branch(remote, branch_name, worktree_path)
        return False

    return True


def list_packages(packages: list[Package]) -> None:
    """List all discovered packages."""
    print("Packages with nix-update:")
    for pkg in packages:
        if pkg.method == "nix-update":
            args = " ".join(pkg.extra_args or [])
            print(f"  - {pkg.name}" + (f" ({args})" if args else ""))

    print("\nPackages with custom update.py:")
    for pkg in packages:
        if pkg.method == "custom":
            print(f"  - {pkg.name}")


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
        "--remote",
        default="origin",
        help="Remote to push update branches to (default: origin)",
    )

    args = parser.parse_args()

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
                pkg, flake_root, args.dry_run, check_system, args.remote
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
    if _skipped:
        print(
            f"Skipped (not available for {current_system()}): "
            f"{', '.join(sorted(_skipped))}"
        )
    if failed:
        print(f"Failed packages: {', '.join(failed)}")
        # Gitea/GitHub render this as an annotation at the top of the job.
        print(f"::error::{len(failed)} package(s) failed: {', '.join(failed)}")

    return 0 if failure_count == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
