#!/usr/bin/env bash
# 导出单个分段为音频文件

AUDIO_FILE="$1"
SEGMENT_NUM="$2"
START_TIME="$3"
END_TIME="$4"

# 获取文件信息
BASENAME=$(basename "$AUDIO_FILE" | sed 's/\.[^.]*$//')
EXT="${AUDIO_FILE##*.}"

# 输出目录和文件
OUTPUT_DIR="${BASENAME}_parts"
mkdir -p "$OUTPUT_DIR"

OUTPUT_FILE="$OUTPUT_DIR/part${SEGMENT_NUM}.$EXT"

# 计算时长
DURATION=$(echo "$END_TIME - $START_TIME" | bc)

# 导出分段（只保留音频，移除封面和元数据）
echo -e "\033[1;33m导出分段 ${SEGMENT_NUM}: ${START_TIME}s -> ${END_TIME}s (时长: ${DURATION}s)\033[0m"
ffmpeg -v error -y \
  -ss "$START_TIME" \
  -t "$DURATION" \
  -i "$AUDIO_FILE" \
  -c copy \
  -map 0:a:0 \
  -map_metadata -1 \
  "$OUTPUT_FILE"

echo -e "\033[1;32m✓ 已导出: $OUTPUT_FILE\033[0m"
