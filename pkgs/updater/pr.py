"""Turn a package update into a pull request, using a temporary git worktree."""

import tempfile
from pathlib import Path

from .forge import has_open_pr, open_pull_request, schedule_auto_merge
from .gitops import delete_remote_branch, git_has_changes, remote_branch_exists, run_cmd
from .package import Package, get_current_version
from .updating import (
    check_available,
    run_custom_update,
    run_nix_update,
    update_package,
)


def create_pr_for_package(
    pkg: Package,
    flake_root: Path,
    dry_run: bool = False,
    check_system: bool = True,
    remote: str = "origin",
    auto_merge: bool = False,
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

    # An existing branch usually means an earlier run already opened a PR, and
    # skipping it keeps the 5-hourly job from going red forever. But a branch
    # can also be left behind by a merged or closed PR (auto-merge + retained
    # head branches): treating that as "PR still open" would silently stop
    # updating the package for good. Only skip when a PR is actually open.
    if remote_branch_exists(remote, branch_name, flake_root):
        if has_open_pr(flake_root, remote, branch_name):
            print(f"  Branch {branch_name} already exists on {remote}, skipping")
            return True
        print(f"  Branch {branch_name} has no open PR, deleting the stale branch")
        delete_remote_branch(remote, branch_name, flake_root)

    return _create_pr_in_worktree(pkg, flake_root, branch_name, remote, auto_merge)


def _create_pr_in_worktree(
    pkg: Package,
    flake_root: Path,
    branch_name: str,
    remote: str = "origin",
    auto_merge: bool = False,
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
                pkg, worktree_path, branch_name, remote, auto_merge
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
    worktree_path: Path,
    branch_name: str,
    remote: str = "origin",
    auto_merge: bool = False,
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
    if not open_pull_request(worktree_path, remote, commit_msg, pr_body):
        # Leaving the branch behind would make every later run skip this package.
        delete_remote_branch(remote, branch_name, worktree_path)
        return False

    if auto_merge:
        schedule_auto_merge(worktree_path, remote, branch_name)

    return True
