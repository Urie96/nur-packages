#!/usr/bin/env python3

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from typing import Any, Sequence


DEFAULT_API_URL = "http://localhost:8095/api"
DEFAULT_PLAYER_ID = "ma_898f89378573463c9be057febc2ebba3"
API_URL = os.environ.get("MUSIC_ASSISTANT_URL", DEFAULT_API_URL)
player_id = os.environ.get("MUSIC_ASSISTANT_PLAYER_ID", DEFAULT_PLAYER_ID)


def call(command: str, args: dict[str, Any] | None = None) -> Any:
    """调用 API，并返回解析后的 JSON 响应。"""
    token = os.environ.get("MUSIC_ASSISTANT_TOKEN")
    if not token:
        raise RuntimeError("环境变量 MUSIC_ASSISTANT_TOKEN 未设置")

    payload = json.dumps(
        {"command": command, "args": args},
        ensure_ascii=False,
    ).encode("utf-8")
    request = urllib.request.Request(
        API_URL,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {token}",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"API 请求失败（HTTP {error.code}）：{body}") from error
    except urllib.error.URLError as error:
        raise RuntimeError(f"无法连接 API：{error.reason}") from error


def search(
    query: str,
    media_types: list[str] | None = None,
    library_only: bool = False,
):
    result = call(
        "music/search",
        {
            "search_query": query,
            "library_only": library_only,
            "media_types": media_types,
        },
    )
    priority = [
        "audiobooks",
        "tracks",
        "playlists",
        "albums",
        "artists",
        "radio",
        "podcasts",
        "genres",
    ]
    for key in priority:
        items = result.get(key)
        if items:
            # 只保留 name 包含搜索关键词的项（不区分大小写）
            filtered = [
                item for item in items if query.lower() in item.get("name", "").lower()
            ]
            if filtered:
                return filtered
    return None


def volume_down():
    return call(
        "players/cmd/volume_down",
        {"player_id": player_id},
    )


def volume_up():
    return call(
        "players/cmd/volume_up",
        {"player_id": player_id},
    )


def volume_set(volume_level: int):
    return call(
        "players/cmd/volume_set",
        {"player_id": player_id, "volume_level": volume_level},
    )


def play():
    return call("player_queues/play", {"queue_id": player_id})


def pause():
    return call("player_queues/pause", {"queue_id": player_id})


def next_track():
    return call("players/cmd/next", {"player_id": player_id})


def previous_track():
    return call("players/cmd/previous", {"player_id": player_id})


def add_currently_playing_to_favorites():
    return call("players/add_currently_playing_to_favorites", {"player_id": player_id})


def search_and_play(query: str, media_types: list[str] | None = None) -> bool:
    library_preferred_types = {"track", "audiobook", "playlist"}
    prefer_library = bool(
        media_types is None or library_preferred_types.intersection(media_types)
    )
    search_order = (True, False) if prefer_library else (False, True)
    results = None
    for library_only in search_order:
        results = search(query, media_types, library_only)
        if results:
            break
    if not results:
        print(f"没有找到与“{query}”相关的音乐")
        return False

    media = results[0]
    media_type_names = {
        "track": "歌曲",
        "album": "专辑",
        "artist": "歌手",
        "playlist": "播放列表",
        "radio": "电台",
        "audiobook": "有声书",
        "podcast": "播客",
    }
    media_type = media_type_names.get(media.get("media_type"), "音乐")
    print(f"正在播放{media_type}：{media['name']}")
    call(
        "player_queues/play_media",
        {"queue_id": player_id, "media": media},
    )
    return True


def volume_level(value: str) -> int:
    try:
        level = int(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("音量必须是 0 到 100 的整数") from error
    if not 0 <= level <= 100:
        raise argparse.ArgumentTypeError("音量必须在 0 到 100 之间")
    return level


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="控制 Music Assistant 播放器")
    parser.add_argument(
        "--api-url",
        default=API_URL,
        help="Music Assistant API 地址（默认读取 MUSIC_ASSISTANT_URL）",
    )
    parser.add_argument(
        "--player-id",
        default=player_id,
        help="播放器 ID（默认读取 MUSIC_ASSISTANT_PLAYER_ID）",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    play_parser = subparsers.add_parser("play", help="恢复播放，或搜索并播放音乐")
    play_parser.add_argument("query", nargs="*", metavar="QUERY", help="歌曲或音乐名称")
    play_parser.add_argument(
        "--media-type",
        action="append",
        choices=[
            "track",
            "album",
            "artist",
            "playlist",
            "radio",
            "audiobook",
            "podcast",
        ],
        help="限定媒体类型；可重复指定",
    )

    subparsers.add_parser("pause", help="暂停播放")
    subparsers.add_parser("volume-up", help="调高音量")
    subparsers.add_parser("volume-down", help="调低音量")
    volume_set_parser = subparsers.add_parser("volume-set", help="设置音量")
    volume_set_parser.add_argument("level", type=volume_level, help="0 到 100")
    subparsers.add_parser("next", help="播放下一曲")
    subparsers.add_parser("previous", help="播放上一曲")
    subparsers.add_parser("favorite", help="将当前歌曲添加到喜欢")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    global API_URL, player_id

    args = parse_args(argv)
    API_URL = args.api_url
    player_id = args.player_id

    try:
        if args.command == "play":
            query = " ".join(args.query).strip()
            if query and not search_and_play(query, args.media_type):
                return 1
            if not query:
                play()
                print("已恢复播放")
        elif args.command == "pause":
            pause()
            print("已暂停播放")
        elif args.command == "volume-up":
            volume_up()
            print("已调高音量")
        elif args.command == "volume-down":
            volume_down()
            print("已调低音量")
        elif args.command == "volume-set":
            volume_set(args.level)
            print(f"已将音量设置为 {args.level}%")
        elif args.command == "next":
            next_track()
            print("已切换到下一曲")
        elif args.command == "previous":
            previous_track()
            print("已切换到上一曲")
        elif args.command == "favorite":
            add_currently_playing_to_favorites()
            print("已将当前歌曲添加到喜欢")
    except RuntimeError as error:
        print(f"错误：{error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
