#!/usr/bin/env bash
# 音频标记分割工具

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INPUT=""
START_TIME=""
MARK_FILE=""  # 将在 main 函数中根据音频文件名设置

show_usage() {
  echo "用法: $0 <音频文件> [--start=起始位置]"
  echo
  echo "工作流程:"
  echo "  1. 播放音频并打标签 (空格键)"
  echo "  2. 打标结束后打开fzf选择不同分段"
  echo "  3. fzf退出之后询问是否继续分割"
  echo "  4. 输入y之后，将文件切割为多个文件"
  echo
  exit 1
}

# 解析参数
while [[ $# -gt 0 ]]; do
  case "$1" in
    --start=*)
      START_TIME="${1#*=}"
      shift
      ;;
    *)
      if [[ -z "$INPUT" ]]; then
        INPUT="$1"
      fi
      shift
      ;;
  esac
done

# 切割音频
split_audio() {
  local audio_file="$1"
  local mark_file="$2"

  # 获取文件名(不含扩展名)作为输出目录
  local basename=$(basename "$audio_file" | sed 's/\.[^.]*$//')
  local output_dir="${basename}_parts"

  # 创建输出目录
  mkdir -p "$output_dir"

  # 获取文件扩展名
  local ext="${audio_file##*.}"

  # 读取所有标记
  mapfile -t marks < "$mark_file"

  # 排序标记并去重
  IFS=$'\n' sorted_marks=($(sort -nu <<<"${marks[*]}"))
  unset IFS

  # 添加开头形成分段点
  split_points=(0 "${sorted_marks[@]}")

  # 获取音频总时长
  local duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$audio_file")
  duration=${duration%.*}

  # 计算段数: 标记数 + 1
  local segment_count=$((${#sorted_marks[@]} + 1))

  echo
  echo "标记点: ${sorted_marks[*]}"
  echo "将切割 $segment_count 段音频..."
  echo "输出目录: $output_dir"
  echo

  # 切割音频 (分段点之间形成段)
  for i in "${!split_points[@]}"; do
    local start_time="${split_points[$i]}"

    # 计算结束时间
    local end_time
    if [[ $i -lt $((${#split_points[@]} - 1)) ]]; then
      end_time="${split_points[$((i + 1))]}"
    else
      # 最后一段使用音频总时长
      end_time="$duration"
    fi

    # 计算时长
    local duration_segment=$(echo "$end_time - $start_time" | bc)

    # 输出文件名 (补零)
    local num=$(printf "%02d" $((i + 1)))
    local output_file="$output_dir/part${num}.$ext"

    echo "[$((i + 1))/$segment_count] 切割: ${start_time}s -> ${end_time}s (时长: ${duration_segment}s)"

    # 使用ffmpeg切割（只保留音频，移除封面和元数据）
    ffmpeg -v error -y \
      -ss "$start_time" \
      -t "$duration_segment" \
      -i "$audio_file" \
      -c copy \
      -map 0:a:0 \
      -map_metadata -1 \
      "$output_file"
  done

  # 将标记文件移动到输出目录
  if [[ -f "$mark_file" ]]; then
    mv "$mark_file" "$output_dir/"
    echo "已保存标记文件到: $output_dir/$(basename "$mark_file")"
  fi

  echo
  echo "完成! 共切割 $segment_count 段音频到目录: $output_dir"
}

# 浏览和播放分段
browse_segments() {
  local audio_file="$1"
  local mark_file="$2"

  if [[ ! -s "$mark_file" ]]; then
    echo "未找到标记点"
    return
  fi

  "$SCRIPT_DIR/generate_segments.sh" "$audio_file" "$mark_file" |
    fzf --prompt="选择分段> " \
      --header="Enter:播放 | Ctrl-D:删除标记 | Ctrl-E:编辑标记 | Ctrl-X:导出分段 | Ctrl-C:退出" \
      --header-lines=1 \
      --layout=reverse \
      --delimiter="|" \
      --bind="enter:execute(echo -e \"\033[1;32m▶ 播放分段 {1}: \033[1;36m{2}s \033[0m→ \033[1;36m{3}s\033[0m\" && mpv --no-video --start={2} --end={3} \"$audio_file\")" \
      --bind="ctrl-d:execute-silent($SCRIPT_DIR/delete_mark.sh \"$mark_file\" {3})+reload($SCRIPT_DIR/generate_segments.sh \"$audio_file\" \"$mark_file\")" \
      --bind="ctrl-e:execute-silent($SCRIPT_DIR/delete_mark.sh \"$mark_file\" {3})+become($0 \"$audio_file\" --start={3})" \
      --bind="ctrl-x:execute($SCRIPT_DIR/export_segment.sh \"$audio_file\" {1} {2} {3})" \
      --exit-0
}

# 主流程
main() {
  [[ -z "$INPUT" ]] && show_usage

  if [[ ! -f "$INPUT" ]]; then
    echo "错误: 找不到音频文件 '$INPUT'"
    exit 1
  fi

  # 根据音频文件名设置标记文件
  local basename=$(basename "$INPUT" | sed 's/\.[^.]*$//')
  MARK_FILE="${basename}_marks.txt"

  echo "=== 音频标记模式 ==="
  echo "音频: $INPUT"
  if [[ -n "$START_TIME" ]]; then
    echo "起始位置: ${START_TIME}秒 (编辑模式)"
  fi
  echo "按 [空格] 记录时间点"
  echo "按 [q] 退出播放"
  echo

  # 如果是编辑模式，不清空标记文件
  if [[ -z "$START_TIME" ]]; then
    >"$MARK_FILE"
  fi

  # 播放音频
  local lua_script="$SCRIPT_DIR/mpv_mark.lua"
  if [[ -n "$START_TIME" ]]; then
    mpv --no-video --script="$lua_script" --script-opts="mark_file=$MARK_FILE" --input-conf="/dev/null" --start="$START_TIME" "$INPUT"
  else
    mpv --no-video --script="$lua_script" --script-opts="mark_file=$MARK_FILE" --input-conf="/dev/null" "$INPUT"
  fi

  echo
  if [[ -s "$MARK_FILE" ]]; then
    local mark_count=$(wc -l <"$MARK_FILE")
    echo "已记录 $mark_count 个标记点"
    echo
    browse_segments "$INPUT" "$MARK_FILE"

    echo
    read -p "是否切割音频? (y/n): " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      split_audio "$INPUT" "$MARK_FILE"
    fi
  else
    echo "未记录任何标记点"
  fi
}

main
