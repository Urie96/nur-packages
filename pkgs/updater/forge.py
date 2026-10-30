"""Open pull requests and schedule merges on the forge.

GitHub goes through `gh`, which already knows how to authenticate and which
repo it is in. Gitea/Forgejo is talked to over its HTTP API directly, so no
`tea` binary is needed: the updater reuses the `GITEA_TOKEN` /
`GITEA_INSTANCE_URL` / `TEA_HOST` variables CI already exports.
"""

import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from .gitops import (
    current_branch,
    get_remote_url,
    remote_host,
    remote_slug,
    run_cmd,
)

GITHUB = "github"
GITEA = "gitea"

# Merge style used when scheduling the auto-merge. A merge commit keeps the
# update branch's commit as an ancestor of the target branch, so a branch
# recreated from an older tip never reintroduces commits that the target branch
# already has. The updater has no flag for the style, so GitHub needs "Allow
# merge commits" enabled; Gitea accepts it as one of its merge styles.
MERGE_METHOD = "merge"


def resolve_forge(cwd: Path, remote: str) -> str:
    """Decide whether the remote is a GitHub or a Gitea/Forgejo repository."""
    url = get_remote_url(remote, cwd)
    host = remote_host(url) if url else None
    if host and "github" in host.lower():
        return GITHUB
    if host:
        return GITEA
    print(f"  Warning: unknown remote '{remote}', falling back to gh")
    return GITHUB


def open_pull_request(cwd: Path, remote: str, title: str, body: str) -> str | None:
    """Open a PR for the branch checked out in `cwd`; return its URL."""
    url = get_remote_url(remote, cwd)
    slug = remote_slug(url) if url else None
    if not slug:
        print(f"  Error: cannot derive owner/repo from the {remote} remote URL")
        return None

    if resolve_forge(cwd, remote) == GITHUB:
        return _open_github_pr(cwd, slug, title, body)
    return _open_gitea_pr(cwd, remote, slug, title, body)


def _open_github_pr(cwd: Path, slug: str, title: str, body: str) -> str | None:
    """Open the PR with `gh pr create` (GitHub only)."""
    cmd = ["gh", "pr", "create", "--title", title, "--body", body, "--repo", slug]
    print(f"  Running: {' '.join(cmd)}")
    result = run_cmd(cmd, cwd=cwd, check=False)
    if result.returncode != 0:
        print(f"  Error creating PR with gh: {result.stderr.strip()}")
        return None

    # `gh` prints the URL of the created PR on stdout.
    pr_url = result.stdout.strip().splitlines()[-1] if result.stdout.strip() else ""
    print(f"  Created PR: {pr_url}")
    return pr_url


def _open_gitea_pr(
    cwd: Path, remote: str, slug: str, title: str, body: str
) -> str | None:
    """Open the PR through the Gitea API (`POST /repos/{owner}/{repo}/pulls`)."""
    if not os.environ.get("GITEA_TOKEN"):
        print("  Error: GITEA_TOKEN is unset, cannot open the PR through the Gitea API")
        return None

    base = gitea_api_base(remote, cwd)
    if not base:
        print("  Error: cannot determine the Gitea API URL (set GITEA_INSTANCE_URL)")
        return None

    head = current_branch(cwd)
    if not head:
        print("  Error: the worktree is on a detached HEAD, cannot open the PR")
        return None

    payload: dict[str, object] = {
        "head": head,
        "base": default_branch(base, slug, remote, cwd),
        "title": title,
        "body": body,
    }
    code, response = gitea_call(base, "POST", f"/repos/{slug}/pulls", payload)

    if code == 201 and isinstance(response, dict):
        pr_url = str(response.get("html_url", ""))
        print(f"  Created PR: {pr_url}")
        return pr_url

    if code == 409:
        # A PR for this head branch is already open (e.g. an earlier run raced
        # with this one). That is the desired state, not a failure.
        existing = find_open_pr(base, slug, head)
        if existing:
            pr_url = str(existing.get("html_url", ""))
            print(f"  PR already open: {pr_url}")
            return pr_url

    print(f"  Error creating PR on Gitea: HTTP {code} {gitea_message(response)}")
    return None


def gitea_api_base(remote: str, cwd: Path) -> str | None:
    """Return `<server>/api/v1` for the Gitea instance, or None.

    `GITEA_INSTANCE_URL` / `TEA_HOST` are what CI exports (the second name is
    what `tea` 1.x uses); when they are missing (local run), the remote URL is
    a good enough fallback.
    """
    server = os.environ.get("GITEA_INSTANCE_URL") or os.environ.get("TEA_HOST")
    if not server:
        url = get_remote_url(remote, cwd) or ""
        if url.startswith(("http://", "https://")):
            parsed = urllib.parse.urlparse(url)
            server = f"{parsed.scheme}://{parsed.netloc}"
        else:
            host = remote_host(url)
            if host:
                server = f"https://{host}"
    return f"{server.rstrip('/')}/api/v1" if server else None


def gitea_message(body: object) -> str:
    """Best-effort extraction of the human-readable API error message."""
    if isinstance(body, dict):
        return str(body.get("message") or body)
    return str(body)


def gitea_call(
    base: str,
    method: str,
    path: str,
    payload: dict[str, object] | None = None,
) -> tuple[int, object]:
    """Call the Gitea API with the token from `GITEA_TOKEN`."""
    request = urllib.request.Request(
        f"{base}{path}",
        method=method,
        headers={
            "Authorization": f"token {os.environ.get('GITEA_TOKEN', '')}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        },
    )
    if payload is not None:
        request.data = json.dumps(payload).encode()

    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = response.read().decode()
            return response.status, json.loads(body) if body.strip() else {}
    except urllib.error.HTTPError as exc:
        body = exc.read().decode()
        try:
            return exc.code, json.loads(body) if body.strip() else {}
        except json.JSONDecodeError:
            return exc.code, {"message": body}
    except OSError as exc:
        return 0, {"message": str(exc)}


def default_branch(base: str, slug: str, remote: str, cwd: Path) -> str:
    """The branch the PR should target.

    Asked from the API so it also works in CI, where the local clone may not
    have `<remote>/HEAD` set up.
    """
    code, info = gitea_call(base, "GET", f"/repos/{slug}")
    if code == 200 and isinstance(info, dict) and info.get("default_branch"):
        return str(info["default_branch"])

    result = run_cmd(
        ["git", "symbolic-ref", "--short", f"refs/remotes/{remote}/HEAD"],
        cwd=cwd,
        check=False,
    )
    ref = result.stdout.strip()
    if result.returncode == 0 and ref:
        print(f"  Warning: using {ref} as the PR base branch")
        return ref.split("/", 1)[-1]

    print("  Warning: using 'main' as the PR base branch")
    return "main"


def find_open_pr(base: str, slug: str, head: str) -> dict[str, object] | None:
    """Return the open PR whose head branch is `head`, or None.

    The `head` query parameter is not honoured by every Gitea version, so the
    list is filtered here instead.
    """
    code, pulls = gitea_call(base, "GET", f"/repos/{slug}/pulls?state=open&limit=50")
    if code != 200 or not isinstance(pulls, list):
        return None
    for pull in pulls:
        if pull.get("head", {}).get("ref") == head:
            return pull
    return None


def schedule_auto_merge(cwd: Path, remote: str, branch: str) -> bool:
    """Let the forge merge the PR once the required checks pass.

    GitHub gets `gh pr merge --auto`, so it merges when the branch protection's
    required checks are green. Gitea gets its native `merge_when_checks_succeed`
    through the API, with the same token that opened the PR. Scheduling before
    any check has run is fine on both.
    """
    if resolve_forge(cwd, remote) == GITHUB:
        return _schedule_github_auto_merge(cwd, remote, branch)
    return _schedule_gitea_auto_merge(cwd, remote, branch)


def _schedule_github_auto_merge(cwd: Path, remote: str, branch: str) -> bool:
    """Arm GitHub's auto-merge with `gh` (GitHub only).

    Requires the repository setting "Allow auto-merge" and a branch protection
    rule with required checks; without them `gh` fails and the PR simply stays
    open for a manual merge.
    """
    slug = remote_slug(get_remote_url(remote, cwd) or "")
    if not slug:
        print(f"  Warning: cannot derive owner/repo from the {remote} remote URL")
        return False

    cmd = [
        "gh",
        "pr",
        "merge",
        branch,
        "--repo",
        slug,
        "--auto",
        f"--{MERGE_METHOD}",
    ]
    print(f"  Running: {' '.join(cmd)}")
    result = run_cmd(cmd, cwd=cwd, check=False)
    if result.returncode != 0:
        print(f"  Warning: auto-merge for {branch} failed: {result.stderr.strip()}")
        return False

    print(f"  Auto-merge scheduled for {branch}")
    return True


def has_open_pr(cwd: Path, remote: str, branch: str) -> bool:
    """Whether an open PR exists for `branch`.

    Used to tell "an earlier run opened a PR" (skip) from "a merged PR left its
    branch behind" (delete it and update again). Unknown answers say True, so a
    flaky forge API never deletes a branch that may still belong to a PR.
    """
    url = get_remote_url(remote, cwd)
    slug = remote_slug(url) if url else None
    if not slug:
        print(f"  Warning: cannot derive owner/repo from the {remote} remote URL")
        return True

    if resolve_forge(cwd, remote) == GITHUB:
        result = run_cmd(
            [
                "gh",
                "pr",
                "list",
                "--repo",
                slug,
                "--head",
                branch,
                "--state",
                "open",
                "--json",
                "number",
            ],
            cwd=cwd,
            check=False,
        )
        if result.returncode != 0:
            print(f"  Warning: cannot list PRs for {branch}: {result.stderr.strip()}")
            return True
        try:
            pulls = json.loads(result.stdout)
        except json.JSONDecodeError:
            return True
        return bool(pulls)

    base = gitea_api_base(remote, cwd)
    if not base:
        return True
    return find_open_pr(base, slug, branch) is not None


def _schedule_gitea_auto_merge(cwd: Path, remote: str, branch: str) -> bool:
    """Let Gitea merge the PR once the required checks pass.

    This replaces a label plus a second workflow: the merge is scheduled here,
    with the same token that opened the PR, and Gitea completes it as soon as
    the commit statuses of the PR head turn green (`pull_auto_merge` and the
    automerge queue server side). Scheduling before any check has run is fine.
    """
    if not os.environ.get("GITEA_TOKEN"):
        print("  Warning: GITEA_TOKEN is unset, cannot schedule the auto-merge")
        return False

    base = gitea_api_base(remote, cwd)
    slug = remote_slug(get_remote_url(remote, cwd) or "")
    if not base or not slug:
        print("  Warning: cannot determine the Gitea API URL, skipping auto-merge")
        return False

    pull = find_open_pr(base, slug, branch)
    if pull is None:
        print(f"  Warning: no open pull request for {branch}, skipping auto-merge")
        return False
    number = int(pull["number"])

    payload: dict[str, object] = {
        "Do": MERGE_METHOD,
        "merge_when_checks_succeed": True,
        "delete_branch_after_merge": True,
    }

    max_attempts = 5
    for attempt in range(1, max_attempts + 1):
        code, body = gitea_call(
            base, "POST", f"/repos/{slug}/pulls/{number}/merge", payload
        )
        message = gitea_message(body)

        if code in (200, 201):
            print(f"  Auto-merge scheduled for PR #{number}")
            return True
        if code == 409:
            print(f"  PR #{number} is already merged or scheduled for auto-merge")
            return True
        # "Please try again later": the PR is still in its mergeability check.
        if code == 405 and "try again" in message.lower() and attempt < max_attempts:
            time.sleep(2)
            continue

        print(f"  Warning: auto-merge for PR #{number} failed: HTTP {code} {message}")
        return False

    return False
