#!/usr/bin/env python3
"""Update arc from Arc's Sparkle appcast.

Arc 没有 GitHub release，只有 Sparkle 的 appcast（Homebrew 的 livecheck 用的也是这个）：

    https://releases.arc.net/updates.xml

第一条 item 里 `sparkle:version` 是 build 号（87405），`sparkle:shortVersionString`
是 "1.165.1 (87405)"。文件名 Arc-1.165.1-87405.zip 需要这两个号，所以 default.nix 里
version 写成 "1.165.1-87405"，地址直接由它拼出来，交给 nix-update 重新 eval 并算 hash。
"""

from __future__ import annotations

import re
import subprocess
import sys
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

FEED_URL = "https://releases.arc.net/updates.xml"
SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"


def fetch_latest_version() -> str:
    # 上游把 Python-urllib 的默认 UA 拒掉（403），随便给个正常的 UA。
    request = urllib.request.Request(FEED_URL, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        feed = ET.parse(response)

    item = feed.find("./channel/item")
    if item is None:
        sys.exit(f"Error: no <item> in {FEED_URL}")

    build = item.findtext(f"{{{SPARKLE_NS}}}version")
    short = item.findtext(f"{{{SPARKLE_NS}}}shortVersionString")
    if not build or not short:
        sys.exit(f"Error: <item> in {FEED_URL} has no sparkle:version/shortVersionString")

    # "1.165.1 (87405)" -> "1.165.1"
    match = re.match(r"([\d.]+)", short.strip())
    if match is None:
        sys.exit(f"Error: cannot parse shortVersionString {short!r}")
    version = f"{match.group(1)}-{build}"

    # 版本号拼出来的必须是 appcast 里真正给的那个包，不然就是上游改了命名规则。
    enclosure = item.find("enclosure")
    url = enclosure.get("url", "") if enclosure is not None else ""
    if not url.endswith(f"/Arc-{version}.zip"):
        sys.exit(f"Error: appcast enclosure {url!r} does not match version {version}")

    return version


def main() -> None:
    flake_root = Path(__file__).resolve().parent.parent.parent

    version = fetch_latest_version()
    print(f"Latest version: {version}")

    result = subprocess.run(
        ["nix-update", "--flake", "arc", "--version", version],
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
