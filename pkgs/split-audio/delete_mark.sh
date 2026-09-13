#!/usr/bin/env bash
# 删除指定的标记点

MARK_FILE="$1"
MARK_VALUE="$2"

# 从标记文件中删除指定的标记
if [[ -f "$MARK_FILE" ]]; then
  grep -v "^${MARK_VALUE}$" "$MARK_FILE" > /tmp/fzf_marks_temp_$$.txt
  mv /tmp/fzf_marks_temp_$$.txt "$MARK_FILE"
  echo "已删除标记: ${MARK_VALUE}s"
else
  echo "错误: 标记文件不存在"
  exit 1
fi
