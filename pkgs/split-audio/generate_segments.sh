#!/usr/bin/env bash
# 生成分段列表

AUDIO_FILE="$1"
MARK_FILE="$2"

if [[ ! -s "$MARK_FILE" ]]; then
  exit 0
fi

# 获取音频总时长
duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$AUDIO_FILE")
duration=${duration%.*}

# 读取并排序标记
IFS=$'\n' read -d '' -r -a marks < <(sort -nu "$MARK_FILE" && printf '\0')

# 打印表头
printf "#|起始|结束|时长\n"

# 生成分段: 0 -> mark1 -> mark2 -> ... -> 结束
start=0
num=1

for mark in "${marks[@]}"; do
  seg_duration=$(echo "$mark - $start" | bc)
  printf "%02d|%.3f|%.3f|%.1f\n" "$num" "$start" "$mark" "$seg_duration"
  start=$mark
  ((num++))
done

# 最后一段
seg_duration=$(echo "$duration - $start" | bc)
printf "%02d|%.3f|%.3f|%.1f\n" "$num" "$start" "$duration" "$seg_duration"

