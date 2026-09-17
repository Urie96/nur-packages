#!/usr/bin/env python3
"""xopen —— 按类型分派的 open/xdg-open wrapper，SSH 会话里改走 kitty remote。

用法:
    xopen <URL|文件|目录>
    xopen -n <...>       # 只打印将要执行的命令，不执行

分流规则见 --help。
"""

from __future__ import annotations

import argparse
import os
import platform
import re
import shlex
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

# ────────────────────────────── 可调配置 ──────────────────────────────

KITTEN_SCRIPT = "remote.py"  # kitty 侧 remote kitten 的脚本名
REMOTE_CONTROL_CANDIDATES = ("slim-kitten", "kitten")  # 按序探测，优先 slim-kitten
SSH_VARS = ("SSH_CONNECTION", "SSH_CLIENT", "SSH_TTY")  # 只看环境变量判定 SSH
EDITOR_FALLBACK = "nvim"

# 图片用 kitten icat 是唯一不能走 slim-kitten 的分支
ICAT = "kitten"

URL_SCHEME_RE = re.compile(
    r"^(?:[A-Za-z][A-Za-z0-9+.\-]*://|(?:mailto|magnet|tel|data|news):)"
)
BARE_DOMAIN_RE = re.compile(
    r"^(?:(?:[A-Za-z0-9_\-]+\.)+[A-Za-z]{2,}|(?:\d{1,3}\.){3}\d{1,3})"
    r"(?::\d+)?(?:[/?#]\S*)?$"
)


def _exts(spec: str) -> set[str]:
    return {"." + e for e in spec.split()}


VIDEO_EXTS = _exts(
    "mp4 mkv webm mov avi flv wmv m4v mpg mpeg m2ts ts ogv 3gp rmvb vob"
)
AUDIO_EXTS = _exts("mp3 flac wav m4a aac ogg opus wma ape alac aiff mka mid")
IMAGE_EXTS = _exts("jpg jpeg png gif webp bmp tif tiff avif heic ico jxl ppm pgm pbm")
# .svg 故意不算图片：它走文本/默认分支（本地 xdg-open，SSH 里 nvim）
TEXT_EXTS = _exts(
    "txt text md markdown rst org adoc tex bib log csv tsv json jsonc json5 yaml yml "
    "toml ini cfg conf config env properties xml svg html htm xhtml css scss sass less "
    "py pyi pyx rb php pl pm lua sh bash zsh fish ksh nu awk sed c h cc cpp cxx hpp hh "
    "m mm rs go java kt kts scala groovy gradle cs fs vb swift dart zig d jl r ex exs "
    "erl hrl hs ml mli clj cljs el vim nix cmake mk makefile dockerfile sql graphql "
    "proto thrift asm s ld diff patch desktop service rules mod sum lock gitignore "
    "editorconfig conf tmpl tpl j2 jinja sln csproj ipynb"
)

# (后缀 -> 解压器类别)，按后缀长度降序匹配，复合后缀优先
ARCHIVE_SUFFIXES: dict[str, str] = {
    ".zip": "zip",
    ".7z": "7z",
    ".rar": "rar",
    ".tar": "tar",
    ".tar.gz": "tar",
    ".tgz": "tar",
    ".tar.bz2": "tar",
    ".tbz2": "tar",
    ".tbz": "tar",
    ".tar.xz": "tar",
    ".txz": "tar",
    ".tar.zst": "tar",
    ".tzst": "tar",
    ".tar.lz4": "tar",
    ".gz": "gz",
    ".bz2": "bz2",
    ".xz": "xz",
    ".zst": "zst",
    ".lz4": "lz4",
}
# 后缀 -> (类别, 是否单文件流)
EXTRACT_HINT = "若为加密压缩包、多卷压缩包或损坏文件，请手动解压。"

SINGLE_DECOMPRESSORS = {
    "gz": "gzip",
    "bz2": "bzip2",
    "xz": "xz",
    "zst": "zstd",
    "lz4": "lz4",
}
# 类别 -> [(工具, argv 模板)]，取第一个可用的
EXTRACTORS: dict[str, list[tuple[str, list[str]]]] = {
    "tar": [("tar", ["tar", "-xf", "{src}", "-C", "{dst}"])],
    "zip": [
        ("unzip", ["unzip", "-q", "{src}", "-d", "{dst}"]),
        ("7z", ["7z", "x", "-y", "-bso0", "-bsp0", "-o{dst}", "{src}"]),
        ("bsdtar", ["bsdtar", "-xf", "{src}", "-C", "{dst}"]),
    ],
    "7z": [
        ("7z", ["7z", "x", "-y", "-bso0", "-bsp0", "-o{dst}", "{src}"]),
        ("bsdtar", ["bsdtar", "-xf", "{src}", "-C", "{dst}"]),
    ],
    "rar": [
        ("unrar", ["unrar", "x", "-y", "{src}", "{dst}/"]),
        ("7z", ["7z", "x", "-y", "-bso0", "-bsp0", "-o{dst}", "{src}"]),
        ("bsdtar", ["bsdtar", "-xf", "{src}", "-C", "{dst}"]),
    ],
}


class Fail(Exception):
    """面向用户的错误，打印 'xopen: ...' 后以 1 退出。"""


@dataclass
class Plan:
    argv: list[str]
    stdout_path: str | None = None
    mkdir_path: str | None = None
    note: str = ""
    hint: str = ""

    def display(self) -> str:
        cmd = shlex.join(self.argv)
        if self.stdout_path:
            cmd += f" > {shlex.join([self.stdout_path])}"
        return cmd


# ────────────────────────────── 小工具 ──────────────────────────────


def eprint(*a: object) -> None:
    print(*a, file=sys.stderr)


def has(tool: str) -> bool:
    return shutil.which(tool) is not None


def need(tool: str) -> str:
    path = shutil.which(tool)
    if path is None:
        raise Fail(f"命令不存在: {tool}")
    return path


def in_ssh() -> bool:
    return any(os.environ.get(v) for v in SSH_VARS)


def opener() -> str:
    """本地桌面打开器：macOS 用 open，其余用 xdg-open。"""
    return "open" if platform.system() == "Darwin" else "xdg-open"


def remote_ctl() -> str:
    for cand in REMOTE_CONTROL_CANDIDATES:
        path = shutil.which(cand)
        if path:
            return path
    raise Fail(f"SSH 会话里需要 {' 或 '.join(REMOTE_CONTROL_CANDIDATES)}，都没找到")


def editor_argv() -> list[str]:
    return shlex.split(os.environ.get("EDITOR") or EDITOR_FALLBACK)


def is_url(s: str) -> bool:
    return bool(URL_SCHEME_RE.match(s))


def looks_like_bare_domain(s: str) -> bool:
    # 形如路径的（绝对 /、相对 ./ ../、家目录 ~）一律不当域名，路径就是路径；
    # 注意不能只看"含斜杠"，baidu.com/foo 这种域名带路径也要能用
    if s.startswith(("/", ".", "~")):
        return False
    return bool(BARE_DOMAIN_RE.match(s))


def is_textual(path: Path) -> bool:
    try:
        chunk = path.open("rb").read(8192)
    except OSError:
        return False
    if b"\0" in chunk:
        return False
    try:
        chunk.decode("utf-8")
    except UnicodeDecodeError:
        return False
    return True


def split_archive(name: str) -> tuple[str, str] | None:
    """('a.tar.gz') -> ('a', 'tar')"""
    low = name.lower()
    for suffix in sorted(ARCHIVE_SUFFIXES, key=len, reverse=True):
        if low.endswith(suffix) and len(low) > len(suffix):
            return name[: len(name) - len(suffix)], ARCHIVE_SUFFIXES[suffix]
    return None


def unique_path(base: Path) -> Path:
    if not base.exists():
        return base
    for i in range(1, 1000):
        cand = base.with_name(f"{base.name}-{i}")
        if not cand.exists():
            return cand
    raise Fail(f"同名目录太多，无法为 {base} 找到可用名字")


# ────────────────────────────── 分流 ──────────────────────────────


def build_plan(target: str, ssh: bool) -> Plan:
    if is_url(target):
        return Plan(url_argv(target, ssh))

    if not os.path.exists(target) and looks_like_bare_domain(target):
        return Plan(url_argv("https://" + target, ssh))

    src = Path(os.path.realpath(target))
    if not src.exists():
        raise Fail(f"路径不存在，也不像 URL: {target}")

    if src.is_dir():
        return Plan(dir_argv(src, ssh))

    name = src.name
    ext = src.suffix.lower()

    archive = split_archive(name)
    if archive:
        plan = archive_plan(src, *archive)
        if plan is not None:
            return plan
        # 没有可用的解压命令：本地兜底 open/xdg-open，SSH 会话里直接报错
        tried = "/".join(archive_tools(archive[1]))
        if ssh:
            raise Fail(f"没有可用的解压命令（{tried} 都不存在），请手动解压: {name}")
        return Plan([need(opener()), str(src)])

    if ext in VIDEO_EXTS:
        return Plan(video_argv(src, ssh))
    if ext in AUDIO_EXTS:
        return Plan(audio_argv(src, ssh))
    if ext in IMAGE_EXTS:
        return Plan(image_argv(src, ssh))
    if ext in TEXT_EXTS or is_textual(src):
        return Plan(text_argv(src, ssh))

    # 未知二进制
    if ssh:
        raise Fail(f"SSH 会话里不知道怎么打开这个二进制文件: {name}（请手动处理）")
    return Plan([need(opener()), str(src)])


def url_argv(url: str, ssh: bool) -> list[str]:
    if ssh:
        return [remote_ctl(), "@", "action", "open_url", url]
    return [need(opener()), url]


def text_argv(path: Path, ssh: bool) -> list[str]:
    if ssh:
        return [*editor_argv(), str(path)]
    return [need(opener()), str(path)]


def video_argv(path: Path, ssh: bool) -> list[str]:
    if ssh:
        return kitten_argv("mpv_video", path)
    return [need("mpv"), "--no-terminal", str(path)]


def audio_argv(path: Path, ssh: bool) -> list[str]:
    if ssh:
        return kitten_argv("mpv_audio", path)
    return [need("mpv"), str(path)]


def image_argv(path: Path, ssh: bool) -> list[str]:
    if ssh:
        if not has(ICAT):
            raise Fail(f"SSH 会话里显示图片需要 {ICAT}（slim-kitten 不支持 icat）")
        return [need(ICAT), "icat", str(path)]
    return [need(opener()), str(path)]


def dir_argv(path: Path, ssh: bool) -> list[str]:
    if path.name.lower().startswith("kicad"):
        if ssh:
            return [need("nvim"), str(path)]
        if platform.system() == "Darwin":
            return [need("open"), "-a", "Kicad", str(path)]
        return [need("xdg-open"), str(path)]
    if ssh:
        return [need("nvim"), str(path)]
    return [need(opener()), str(path)]


def kitten_argv(action: str, path: Path) -> list[str]:
    return [remote_ctl(), "@", "kitten", KITTEN_SCRIPT, action, str(path)]


def archive_tools(kind: str) -> list[str]:
    if kind in SINGLE_DECOMPRESSORS:
        return [SINGLE_DECOMPRESSORS[kind]]
    return [tool for tool, _ in EXTRACTORS.get(kind, [])]


def archive_plan(src: Path, stem: str, kind: str) -> Plan | None:
    """返回 None 表示没有可用的解压命令，调用方自行兜底。"""
    base = src.parent / stem
    dst = unique_path(base)

    if kind in SINGLE_DECOMPRESSORS:
        tool = SINGLE_DECOMPRESSORS[kind]
        if not has(tool):
            return None
        return Plan(
            [tool, "-dc", str(src)],
            stdout_path=str(dst / stem),
            mkdir_path=str(dst),
            note=f"已解压到 {dst}",
            hint=EXTRACT_HINT,
        )

    for tool, tpl in EXTRACTORS.get(kind, []):
        if has(tool):
            argv = [str(src) if a == "{src}" else a.replace("{dst}", str(dst)) for a in tpl]
            return Plan(argv, mkdir_path=str(dst), note=f"已解压到 {dst}", hint=EXTRACT_HINT)
    return None


# ────────────────────────────── 入口 ──────────────────────────────

EPILOG = """\
分流规则（SSH 会话由 SSH_CONNECTION/SSH_CLIENT/SSH_TTY 判定）:

  URL                SSH: <slim-kitten|kitten> @ action open_url URL
                     本地: open / xdg-open
                     （带 scheme 或形如域名即算 URL，不存在的路径优先当 URL，
                       但以 / ./ ../ ~ 开头的仍当作路径处理）
  文本文件/目录       SSH: $EDITOR（默认 nvim）/ nvim
                     本地: open / xdg-open
  视频 / 音频         SSH: ... @ kitten remote.py mpv_video|mpv_audio PATH
                     本地: mpv --no-terminal / mpv
  图片（非 svg）      SSH: kitten icat PATH（slim-kitten 不支持 icat）
                     本地: open / xdg-open
  kicad* 目录         SSH: nvim   macOS: open -a Kicad   其他: xdg-open
  压缩包              解压到同名目录（已存在则改名 -1/-2...）
                     解压工具缺失: 本地兜底 open / xdg-open，SSH 里直接报错
"""


def parse_args(argv: list[str]) -> argparse.Namespace:
    ap = argparse.ArgumentParser(
        prog="xopen",
        description="按类型分派的 open/xdg-open wrapper，SSH 会话里走 kitty remote。",
        epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("target", metavar="URL|FILE|DIR", help="要打开的目标")
    ap.add_argument(
        "-n", "--print", dest="dry_run", action="store_true",
        help="只打印将要执行的命令，不执行",
    )
    return ap.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    ns = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        plan = build_plan(ns.target, in_ssh())
    except Fail as e:
        eprint(f"xopen: {e}")
        return 1

    if ns.dry_run:
        print(plan.display())
        return 0

    if plan.mkdir_path:
        try:
            os.mkdir(plan.mkdir_path)
        except OSError as e:
            eprint(f"xopen: 无法创建目录 {plan.mkdir_path}: {e}")
            return 1

    try:
        if plan.stdout_path:
            with open(plan.stdout_path, "wb") as fh:
                rc = subprocess.run(plan.argv, stdout=fh).returncode
        else:
            rc = subprocess.run(plan.argv).returncode
    except FileNotFoundError as e:
        eprint(f"xopen: 命令不存在: {e.filename}")
        return 1

    if rc == 0 and plan.note:
        print(plan.note)
    if rc != 0:
        eprint(f"xopen: 命令失败（退出码 {rc}）: {plan.display()}")
        if plan.hint:
            eprint(f"xopen: {plan.hint}")
        if plan.mkdir_path:
            try:  # 只在空目录时删掉，不会误删已解压出来的文件
                os.rmdir(plan.mkdir_path)
            except OSError:
                pass
    return rc


if __name__ == "__main__":
    sys.exit(main())
