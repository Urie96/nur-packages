"""Subprocess plumbing and git helpers shared by the updater modules."""

import subprocess
import sys
import urllib.parse
from pathlib import Path


def run_cmd(
    cmd: list[str], cwd: Path | None = None, check: bool = True
) -> subprocess.CompletedProcess[str]:
    """Run a command and return the result."""
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, check=check)


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


def git_has_changes(root: Path) -> bool:
    """Check if there are uncommitted changes."""
    result = run_cmd(["git", "status", "--porcelain"], cwd=root, check=False)
    return bool(result.stdout.strip())


def current_branch(cwd: Path) -> str | None:
    """Return the checked-out branch, or None for a detached HEAD."""
    result = run_cmd(["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=cwd, check=False)
    branch = result.stdout.strip()
    if result.returncode != 0 or not branch or branch == "HEAD":
        return None
    return branch


def remote_branch_exists(remote: str, branch: str, cwd: Path) -> bool:
    """Check whether `branch` already exists on `remote`."""
    result = run_cmd(
        ["git", "ls-remote", "--heads", remote, branch], cwd=cwd, check=False
    )
    return bool(result.stdout.strip())


def get_remote_url(remote: str, cwd: Path) -> str | None:
    """Return the URL of a git remote, or None if it does not exist."""
    result = run_cmd(["git", "remote", "get-url", remote], cwd=cwd, check=False)
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


def delete_remote_branch(remote: str, branch: str, cwd: Path) -> None:
    """Remove a pushed branch so a retry is not blocked by a stale ref."""
    result = run_cmd(["git", "push", remote, "--delete", branch], cwd=cwd, check=False)
    if result.returncode == 0:
        print(f"  Deleted remote branch {branch}")
    else:
        print(
            f"  Warning: could not delete remote branch {branch}: "
            f"{result.stderr.strip()}"
        )
