#!/usr/bin/env python3
"""Update neteasemusic from the NetEase Cloud Music package API.

    https://music.163.com/api/mac/package/download/latest?arch=arm64&productName=music

返回的 JSON（Homebrew 的 cask livecheck 用的也是这个接口）：

    {"code":200,"data":{"appVer":"3.1.12","buildVer":"3443",
     "downloadUrl":"https://d1.music.126.net/dmusic/NeteaseCloudMusic_Music_official_3.1.12.3443_arm64.dmg"}}

文件名是两个号用 `.` 连起来，所以 version 取 `<appVer>.<buildVer>`（跟 cask 的
`version.csv.join(".")` 一样），default.nix 里直接拼地址。这里额外校验一下
downloadUrl 跟拼出来的文件名一致，免得上游改了命名规则却静默算出错的 hash。
"""

from __future__ import annotations

import json
import subprocess
import sys
import urllib.request
from pathlib import Path

API_URL = (
    "https://music.163.com/api/mac/package/download/latest"
    "?arch=arm64&productName=music"
)


def fetch_latest_version() -> str:
    # 上游会按 UA 挡掉非浏览器请求（403），给个正常的浏览器 UA。
    request = urllib.request.Request(API_URL, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        data = json.load(response)["data"]

    app_version = data["appVer"]
    build_version = data["buildVer"]
    version = f"{app_version}.{build_version}"

    download_url = data.get("downloadUrl", "")
    expected = f"NeteaseCloudMusic_Music_official_{version}_arm64.dmg"
    if not download_url.endswith(f"/{expected}"):
        sys.exit(
            f"Error: {API_URL} returned {download_url!r}, "
            f"which does not match {expected!r}"
        )

    return version


def main() -> None:
    flake_root = Path(__file__).resolve().parent.parent.parent

    version = fetch_latest_version()
    print(f"Latest version: {version}")

    result = subprocess.run(
        ["nix-update", "--flake", "neteasemusic", "--version", version],
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
