#!/usr/bin/env python3
"""Update bambu-studio from the GitHub release assets.

上游 asset 名是 Bambu_Studio_mac-v<version>-<build>.dmg，两个号都得有才能拼出下载地址
（Homebrew 的 cask 用 github_latest + regex 也是取这两个号）。这里直接查
`/releases/latest`，它跟 cask 的 `:github_latest` 一样会跳过 prerelease。

default.nix 用的是 `/releases/latest/download/` + 从 version 拼文件名，所以拿到 asset
里的两个号就够了，交给 nix-update 重新 eval 地址并算 hash。
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

LATEST_URL = "https://api.github.com/repos/bambulab/BambuStudio/releases/latest"
ASSET_RE = re.compile(r"Bambu_Studio_mac-v(\d+(?:\.\d+)+)-(\d+)\.dmg$")


def fetch_latest_version() -> str:
    request = urllib.request.Request(
        LATEST_URL,
        headers={
            "User-Agent": "Mozilla/5.0",
            "Accept": "application/vnd.github+json",
        },
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        release = json.load(response)

    for asset in release.get("assets", []):
        match = ASSET_RE.search(asset["name"])
        if match is not None:
            # <version>-<build>
            return f"{match.group(1)}-{match.group(2)}"

    sys.exit(f"Error: no mac dmg asset in {LATEST_URL}")


def main() -> None:
    flake_root = Path(__file__).resolve().parent.parent.parent

    version = fetch_latest_version()
    print(f"Latest version: {version}")

    result = subprocess.run(
        ["nix-update", "--flake", "bambu-studio", "--version", version],
        cwd=flake_root,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"Error: {result.stderr}")
        sys.exit(1)
    if result.stdout:
        print(result.stdout.strip())


if __name__ == "__main__":
    main()
