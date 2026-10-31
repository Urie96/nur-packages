#!/usr/bin/env python3
"""Update raycast from Raycast's own release endpoint.

Raycast 没有 GitHub release，它自己的更新接口（Homebrew 的 livecheck 用的
也是这个）会返回最新版本号：

    https://x.raycast-releases.com/releases/latest?platform=macos&architecture=arm64

拿到版本后交给 nix-update：default.nix 里的 dmg 地址是从 finalAttrs.version
拼出来的，所以它会重新 eval 出新地址并算好 hash。
"""

from __future__ import annotations

import json
import subprocess
import sys
import urllib.request
from pathlib import Path

# 上游更新接口；每个平台/架构有各自的响应。
LATEST_URL = (
    "https://x.raycast-releases.com/releases/latest?platform=macos&architecture=arm64"
)


def fetch_latest_version() -> str:
    # 上游会把 Python-urllib 的默认 UA 拒掉（403），随便给个正常的 UA。
    request = urllib.request.Request(LATEST_URL, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)["version"]


def main() -> None:
    flake_root = Path(__file__).resolve().parent.parent.parent

    version = fetch_latest_version()
    print(f"Latest version: {version}")

    result = subprocess.run(
        ["nix-update", "--flake", "raycast", "--version", version],
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
