#!/usr/bin/env python3
"""Update feishu from the Feishu (China) download API.

    https://www.feishu.cn/api/downloads

返回的 JSON 里 `versions.MacOS_m1.download_link` 是 arm64 的 dmg 地址（Homebrew 的
cask livecheck 用的也是这个接口）：

    https://<host>/obj/ee-appcenter/<hash>/Feishu-darwin_arm64-<ver>-signed.dmg

版本号和那段内容 hash 都得有才能拼出地址，所以 version 用 `<ver>-<hash>`，
default.nix 里再拆开；host 由 default.nix 写死。拿到 version 后交给 nix-update
重新 eval 地址并算 hash。
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

API_URL = "https://www.feishu.cn/api/downloads"
LINK_RE = re.compile(
    r"/ee-appcenter/(?P<hash>[0-9a-fA-F]+)/Feishu-darwin_arm64-(?P<version>\d+(?:\.\d+)+)-signed\.dmg$"
)


def fetch_latest_version() -> str:
    # 上游把 Python-urllib 的默认 UA 拒掉（403），随便给个正常的 UA。
    request = urllib.request.Request(API_URL, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        data = json.load(response)

    link = data.get("versions", {}).get("MacOS_m1", {}).get("download_link", "")
    match = LINK_RE.search(link)
    if match is None:
        sys.exit(f"Error: cannot parse arm64 download link {link!r}")

    # <ver>-<hash>
    return f"{match.group('version')}-{match.group('hash')}"


def main() -> None:
    flake_root = Path(__file__).resolve().parent.parent.parent

    version = fetch_latest_version()
    print(f"Latest version: {version}")

    result = subprocess.run(
        ["nix-update", "--flake", "feishu", "--version", version],
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
