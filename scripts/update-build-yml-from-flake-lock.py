#!/usr/bin/env python3
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(
    subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
)
flake_lock = ROOT / "flake.lock"
build_yml = ROOT / ".github" / "workflows" / "build.yml"

lock = json.loads(flake_lock.read_text())
locked = lock["nodes"]["nixpkgs"]["locked"]
url = f'nixpkgs=https://github.com/{locked["owner"]}/{locked["repo"]}/archive/{locked["rev"]}.tar.gz'

text = build_yml.read_text()
pattern = r'(^\s*-\s*nixpkgs=https://github\.com/[^\n]+\.tar\.gz\s*$)'
replacement = f'          - {url}'

new_text, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
if count != 1:
    raise SystemExit("Did not find exactly one nixPath entry to replace in .github/workflows/build.yml")

build_yml.write_text(new_text)
print(f"Updated {build_yml} to {url}")
