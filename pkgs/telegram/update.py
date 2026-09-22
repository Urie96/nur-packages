#!/usr/bin/env python3
"""Update telegram from the Sparkle appcast.

Telegram for macOS 没有 GitHub release，只有 Sparkle 的 appcast（Homebrew 的 livecheck
用的也是这个）：

    https://osx.telegram.org/updates/versions.xml

appcast 里的 pubDate 是错的（上游一直没修，Homebrew 的 cask 里也有注释说明），所以不能
按时间排序。这里把所有 item 都读出来，取 sparkle:version（build 号）最大的那个，拼成
`<shortVersionString>.<build>`（跟文件名 Telegram-12.10.282985.app.zip 一致），再交给
nix-update 重新 eval 地址并算 hash。
"""

from __future__ import annotations

import subprocess
import sys
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

FEED_URL = "https://osx.telegram.org/updates/versions.xml"
SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"


def fetch_latest_version() -> str:
    # 上游把 Python-urllib 的默认 UA 拒掉（403），随便给个正常的 UA。
    request = urllib.request.Request(FEED_URL, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        feed = ET.parse(response)

    candidates: list[tuple[int, str]] = []
    for item in feed.getroot().iter("item"):
        enclosure = item.find("enclosure")
        if enclosure is None:
            continue

        build = enclosure.get(f"{{{SPARKLE_NS}}}version")
        short = enclosure.get(f"{{{SPARKLE_NS}}}shortVersionString")
        if not build or not short:
            continue

        version = f"{short}.{build}"
        url = enclosure.get("url", "")
        # 拼出来的版本必须对应 appcast 里真正给的那个包，不然就是上游改了命名规则。
        if not url.endswith(f"/Telegram-{version}.app.zip"):
            continue

        candidates.append((int(build), version))

    if not candidates:
        sys.exit(f"Error: no usable <item> in {FEED_URL}")

    return max(candidates)[1]


def main() -> None:
    flake_root = Path(__file__).resolve().parent.parent.parent

    version = fetch_latest_version()
    print(f"Latest version: {version}")

    result = subprocess.run(
        ["nix-update", "--flake", "telegram", "--version", version],
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
