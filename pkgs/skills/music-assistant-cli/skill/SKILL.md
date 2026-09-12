---
name: music-assistant-cli
description: 通过 Music Assistant 控制音乐播放。用户要求播放或继续播放音乐、暂停、调整音量、切换上一曲/下一曲，或把当前播放的歌曲添加到喜欢时，都应使用此技能；即使用户只说“声音大一点”“下一首”“喜欢这首”等简短指令，也要触发。仅控制音乐时优先于通用 Home Assistant 技能。
---

# Music Assistant

使用 `scripts/music-assistant-cli` 控制默认 Music Assistant 播放器。

## 执行原则

1. 直接执行用户请求，不要只解释命令。
2. 每个请求只调用一次最匹配的命令；成功后简短确认。
3. 用户要求播放某位歌手的歌时，例如“播放周杰伦的歌”“来点陈奕迅”“放一些 Taylor Swift”，提取歌手名并使用 `play --media-type artist <歌手名>`。这类请求是在播放该歌手的音乐，不要作为普通歌曲搜索。
4. 其他播放请求根据用户明确表达的类型使用对应参数：歌曲用 `--media-type track`，专辑用 `--media-type album`，播放列表用 `--media-type playlist`。如果无法判断类型，才使用不带 `--media-type` 的 `play`。
5. 用户要求播放喜欢的歌或我的收藏时，使用 `play --media-type playlist 我最喜欢`。
6. 查询词保留用户给出的歌曲名、歌手名、专辑名或播放列表名，不要翻译；可以去掉“的歌”“来点”等仅表达意图的语法成分。
7. 用户只说“播放”“继续播放”或“恢复播放”而未指定内容时，运行不带查询词的 `play`。
8. 用户说“停止播放”时按暂停处理，运行 `pause`。
9. “声音大一点/小一点”使用 `volume-up`/`volume-down`；用户给出具体百分比时使用 `volume-set`。
10. “喜欢这首”“收藏当前歌曲”等请求使用 `favorite`。不要先搜索歌曲，因为该命令只收藏当前正在播放的项目。
11. 如果命令失败或没有搜索结果，直接转述 CLI 的错误或未找到提示；不要改用互联网搜索，也不要重复执行可能产生副作用的命令。

## 命令

所有命令都从本技能目录执行：

```bash
# 搜索并播放最佳匹配；查询词可以包含空格
scripts/music-assistant-cli play 父亲写的散文诗

# 播放某位歌手的音乐
scripts/music-assistant-cli play --media-type artist 周杰伦

# 播放指定歌曲
scripts/music-assistant-cli play --media-type track 晴天 周杰伦

# 其他可选类型为 album、playlist、radio、audiobook、podcast

# 恢复、暂停
scripts/music-assistant-cli play
scripts/music-assistant-cli pause

# 调整音量
scripts/music-assistant-cli volume-up
scripts/music-assistant-cli volume-down
scripts/music-assistant-cli volume-set 35

# 切歌与收藏当前歌曲
scripts/music-assistant-cli previous
scripts/music-assistant-cli next
scripts/music-assistant-cli favorite
```
