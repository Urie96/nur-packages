#!/usr/bin/env python3
"""Update calibre from the vendor's download redirect.

calibre 没有可用的 GitHub release（上游发新版后会把旧 tag 的产物删掉），
官网的下载入口会 302 到当前版本的 dmg：

    https://calibre-ebook.com/dist/osx  ->  https://download.calibre-ebook.com/<ver>/calibre-<ver>.dmg

Homebrew 的 cask livecheck 用的也是这个重定向。default.nix 里的地址是从 version
拼出来的，所以交给 nix-update 重新 eval 出新地址并算好 hash。
"""

from __future__ import annotations

import re
import subprocess
import sys
import urllib.request
from pathlib import Path

# 官网下载入口；会 302 到当前版本的 dmg。
DIST_URL = "https://calibre-ebook.com/dist/osx"


def fetch_latest_version() -> str:
    # 上游把 Python-urllib 的默认 UA 拒掉（403），随便给个正常的 UA。
    request = urllib.request.Request(DIST_URL, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        # urllib 会自动跟随重定向，response.url 就是最终的 dmg 地址。
        final_url = response.url

    match = re.search(r"/calibre-([\d.]+)\.dmg$", final_url)
    if match is None:
        sys.exit(f"Error: cannot parse version from redirect target {final_url!r}")

    return match.group(1)


def main() -> None:
    flake_root = Path(__file__).resolve().parent.parent.parent

    version = fetch_latest_version()
    print(f"Latest version: {version}")

    result = subprocess.run(
        ["nix-update", "--flake", "calibre", "--version", version],
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
