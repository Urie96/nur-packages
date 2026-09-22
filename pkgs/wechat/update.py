#!/usr/bin/env python3
"""Update wechat from the Sparkle appcast.

微信 Mac 版没有 GitHub release，只有 Sparkle 的 appcast（Homebrew 的 cask livecheck
用的也是这个）：

    https://dldir1.qq.com/weixin/mac/mac-release.xml

feed 里既有新的 universal 4.x，也留着老的 Intel-only 包（WeChatMac_10_15.dmg 之类），
这里只认 `xWeChatMac_universal_<shortVersion>_<build>.dmg` 这种，取 build 最大的一个。
version 用 `<shortVersion>-<build>`（跟 arc 一样把两个号拼起来），default.nix 里再把
`-` 换回 `_` 拼出文件名，然后交给 nix-update 重新 eval 地址并算 hash。
"""

from __future__ import annotations

import re
import subprocess
import sys
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

FEED_URL = "https://dldir1.qq.com/weixin/mac/mac-release.xml"
# 只匹配新版的 universal 包，跳过 feed 里遗留的 WeChatMac_10_15.dmg / WeChatMac_382.dmg 等。
ENCLOSURE_RE = re.compile(
    r"/xWeChatMac_universal_(\d+(?:\.\d+)+)_(\d+)\.dmg(?:\?|$)"
)


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

        match = ENCLOSURE_RE.search(enclosure.get("url", ""))
        if match is None:
            continue

        short, build = match.group(1), match.group(2)
        candidates.append((int(build), f"{short}-{build}"))

    if not candidates:
        sys.exit(f"Error: no usable <item> in {FEED_URL}")

    return max(candidates)[1]


def main() -> None:
    flake_root = Path(__file__).resolve().parent.parent.parent

    version = fetch_latest_version()
    print(f"Latest version: {version}")

    result = subprocess.run(
        ["nix-update", "--flake", "wechat", "--version", version],
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
