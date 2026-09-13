-- mpv_mark.lua
local marks = {}

-- 标记文件名（可以通过命令行选项 --script-opts=mark_file=xxx.txt 修改）
local mark_file = "marks.txt"

-- 尝试从脚本选项中读取（如果提供的话）
local function read_opts()
  local opts_str = mp.get_property("options/script-opts", "")
  if opts_str and opts_str ~= "" then
    for opt in opts_str:gmatch("[^,]+") do
      local key, val = opt:match("^%s*([^=]+)%s*=%s*(.-)%s*$")
      if key == "mark_file" and val and val ~= "" then
        mark_file = val
      end
    end
  end
end
read_opts()

-- 智能跳转配置
local base_seek_step = 5  -- 初始步长（秒）
local seek_timeout = 0.8  -- 超时时间（秒）

-- 跳转状态跟踪
local last_seek_time = 0
local last_seek_dir = nil
local seek_consecutive_count = 0

-- 计算当前步长
local function get_seek_step(direction)
  local current_time = mp.get_time()

  -- 检查是否超时或改变方向
  if current_time - last_seek_time > seek_timeout or last_seek_dir ~= direction then
    seek_consecutive_count = 0
  end

  seek_consecutive_count = seek_consecutive_count + 1
  last_seek_time = current_time
  last_seek_dir = direction

  -- 根据连续次数计算步长：5 -> 10 -> 20 -> 30
  local steps = {5, 10, 20, 30}
  local index = math.min(seek_consecutive_count, #steps)
  return steps[index]
end

mp.add_key_binding('space', 'mark_time', function()
  local time_pos = mp.get_property_number('time-pos', 0)
  table.insert(marks, time_pos)

  -- 写入文件
  local file = io.open(mark_file, 'a')
  if file then
    file:write(string.format('%.3f\n', time_pos))
    file:close()
  end

  mp.osd_message(string.format('标记: %.2f秒', time_pos))
end)

mp.add_key_binding('LEFT', 'seek_backward', function()
  local step = get_seek_step('left')
  mp.commandv('seek', -step, 'relative', 'exact')
  local time_pos = mp.get_property_number('time-pos', 0)
  mp.osd_message(string.format('◀ %.0f秒 (%.1f秒)', step, time_pos))
end)

mp.add_key_binding('RIGHT', 'seek_forward', function()
  local step = get_seek_step('right')
  mp.commandv('seek', step, 'relative', 'exact')
  local time_pos = mp.get_property_number('time-pos', 0)
  mp.osd_message(string.format('▶ %.0f秒 (%.1f秒)', step, time_pos))
end)

mp.register_event('shutdown', function()
  if #marks > 0 then
    print '\n标记的时间点:'
    for i, mark in ipairs(marks) do
      print(string.format('%d. %.3f秒', i, mark))
    end
  end
end)
