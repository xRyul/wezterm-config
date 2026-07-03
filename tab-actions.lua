local M = {}

local tab_background_presets = {
  blue = '#6272a4',
  cyan = '#8be9fd',
  gray = '#44475a',
  green = '#50fa7b',
  grey = '#44475a',
  orange = '#ffb86c',
  pink = '#ff79c6',
  purple = '#bd93f9',
  red = '#ff5555',
  yellow = '#f1fa8c',
}

local function normalize_tab_background(value)
  if value == nil then
    return nil
  end

  local color = value:gsub('^%s+', ''):gsub('%s+$', ''):lower()
  if color == '' or color == 'reset' or color == 'clear' or color == 'default' then
    return ''
  end

  if tab_background_presets[color] then
    return tab_background_presets[color]
  end

  if color:match('^%x%x%x%x%x%x$') then
    return '#' .. color
  end

  if color:match('^#%x%x%x%x%x%x$') then
    return color
  end

  return nil
end

local function readable_text_color(background)
  local red, green, blue = background:match('^#(%x%x)(%x%x)(%x%x)$')
  if red == nil then
    return '#f8f8f2'
  end

  local luminance =
    (0.299 * tonumber(red, 16) + 0.587 * tonumber(green, 16) + 0.114 * tonumber(blue, 16)) / 255

  if luminance > 0.65 then
    return '#282a36'
  end

  return '#f8f8f2'
end

local function tab_shortcut(tab)
  local number = (tab.tab_index or 0) + 1
  if number >= 1 and number <= 9 then
    return '⌘' .. number
  end

  return ''
end

local function fit_tab_text(title, shortcut, max_width, wezterm, fallback)
  shortcut = shortcut or ''
  local text = ' ' .. title .. (shortcut ~= '' and ' ' .. shortcut or '') .. ' '

  if max_width == nil then
    return text
  end

  max_width = tonumber(max_width) or 0
  if max_width <= 0 then
    return ''
  end

  -- If there are too many tabs to read titles, fall back to a tiny marker.
  if max_width <= 2 then
    return wezterm.truncate_right(fallback or text, max_width)
  end

  if shortcut == '' then
    text = wezterm.truncate_right(' ' .. title .. ' ', max_width)
    local padding = max_width - wezterm.column_width(text)
    if padding <= 0 then
      return text
    end

    local left = math.floor(padding / 2)
    local right = padding - left
    return string.rep(' ', left) .. text .. string.rep(' ', right)
  end

  -- Keep the shortcut right-aligned, close to the tab close button.
  local shortcut_text = shortcut .. '  '
  local shortcut_width = wezterm.column_width(shortcut_text)
  if max_width <= shortcut_width + 1 then
    return wezterm.truncate_right(fallback or shortcut, max_width)
  end

  local title_width = max_width - shortcut_width
  local title_text = wezterm.truncate_right(' ' .. title .. ' ', title_width)
  local padding = title_width - wezterm.column_width(title_text)
  if padding <= 0 then
    return title_text .. shortcut_text
  end

  local left = math.floor(padding / 2)
  local right = padding - left
  return string.rep(' ', left) .. title_text .. string.rep(' ', right) .. shortcut_text
end

local function ensure_tab_background_maps(wezterm)
  wezterm.GLOBAL.tab_backgrounds = wezterm.GLOBAL.tab_backgrounds or {}
  wezterm.GLOBAL.tab_backgrounds_by_title = wezterm.GLOBAL.tab_backgrounds_by_title or {}
  wezterm.GLOBAL.tab_title_widths_by_window = wezterm.GLOBAL.tab_title_widths_by_window or {}
end

local function mux_tab_title(tab)
  if tab == nil or tab.get_title == nil then
    return nil
  end

  local ok, title = pcall(function()
    return tab:get_title()
  end)
  if not ok or title == nil or title == '' then
    return nil
  end

  return title
end

local function remember_tab_title_background(wezterm, title, color)
  if title == nil or title == '' then
    return
  end

  ensure_tab_background_maps(wezterm)
  if color == nil or color == '' then
    wezterm.GLOBAL.tab_backgrounds_by_title[title] = nil
  else
    wezterm.GLOBAL.tab_backgrounds_by_title[title] = color
  end
end

local function set_active_tab_background(wezterm, window, color)
  ensure_tab_background_maps(wezterm)
  local tab = window:active_tab()
  local tab_id = tostring(tab:tab_id())
  local title = mux_tab_title(tab)

  if color == '' then
    wezterm.GLOBAL.tab_backgrounds[tab_id] = nil
  else
    wezterm.GLOBAL.tab_backgrounds[tab_id] = color
  end
  remember_tab_title_background(wezterm, title, color)
end

local function apply_tab_name_and_background(wezterm, window, line)
  if line == nil then
    return false
  end

  local text = line:gsub('^%s+', ''):gsub('%s+$', '')
  local name, color_name = text:match('^(.-)%s*|%s*(.-)%s*$')
  if name == nil then
    name, color_name = text:match('^(.-)%s*,%s*(.-)%s*$')
  end

  if name == nil or color_name == nil then
    return false
  end

  name = name:gsub('^%s+', ''):gsub('%s+$', '')
  local color = normalize_tab_background(color_name)
  if color == nil then
    return false
  end

  if name ~= '' then
    window:active_tab():set_title(name)
  end
  set_active_tab_background(wezterm, window, color)
  return true
end

local function remembered_tab_width(tab, max_width, wezterm)
  ensure_tab_background_maps(wezterm)

  local window_width = wezterm.GLOBAL.tab_title_widths_by_window[tostring(tab.window_id)]
  if window_width ~= nil then
    return window_width
  end

  -- Retro tab bar passes a real available width; fancy passes config.tab_max_width.
  if max_width ~= nil and max_width < 999 then
    return max_width
  end

  return nil
end

local function tab_title(tab, wezterm, max_width)
  local title = tab.tab_title
  if title == nil or title == '' then
    title = tab.active_pane and tab.active_pane.title or nil
  end
  if title == nil or title == '' then
    title = 'wezterm'
  end

  ensure_tab_background_maps(wezterm)
  local tab_id = tostring(tab.tab_id)
  local custom_background = wezterm.GLOBAL.tab_backgrounds[tab_id] or wezterm.GLOBAL.tab_backgrounds_by_title[title]
  if custom_background ~= nil then
    wezterm.GLOBAL.tab_backgrounds[tab_id] = custom_background
    remember_tab_title_background(wezterm, title, custom_background)
  end

  local compact_label = tab.is_active and tostring((tab.tab_index or 0) + 1) or '·'
  local text = fit_tab_text(title, tab_shortcut(tab), remembered_tab_width(tab, max_width, wezterm), wezterm, compact_label)

  if custom_background == nil then
    return { { Text = text } }
  end

  return {
    { Background = { Color = custom_background } },
    { Foreground = { Color = readable_text_color(custom_background) } },
    { Text = text },
  }
end

function M.apply(config, wezterm)
  local act = wezterm.action

  ensure_tab_background_maps(wezterm)
  -- Only the first augment-command-palette handler is used by WezTerm,
  -- so collect entries in a plain Lua module that other modules append to.
  local command_palette = require 'command-palette'
  command_palette.reset()
  local function add_command_palette_entry(entry)
    command_palette.add(entry)
  end

  local rename_tab = act.PromptInputLine {
    description = 'Rename tab',
    action = wezterm.action_callback(function(window, pane, line)
      if line then
        window:active_tab():set_title(line)
      end
    end),
  }

  local set_tab_background = act.PromptInputLine {
    description = 'Tab color: blue, cyan, gray, green, orange, pink, purple, red, yellow, #rrggbb, reset',
    action = wezterm.action_callback(function(window, pane, line)
      local color = normalize_tab_background(line)
      if color == nil then
        window:toast_notification('WezTerm', 'Unknown tab color', nil, 3000)
        return
      end

      set_active_tab_background(wezterm, window, color)
    end),
  }

  local rename_and_set_tab_background = act.PromptInputLine {
    description = 'Tab name and color: name | purple, name | #44475a, or name | reset',
    action = wezterm.action_callback(function(window, pane, line)
      if not apply_tab_name_and_background(wezterm, window, line) then
        window:toast_notification('WezTerm', 'Use: name | color', nil, 3000)
      end
    end),
  }

  local tab_actions_menu = act.InputSelector {
    title = 'Tab actions',
    alphabet = 'nxbcagokpry',
    choices = {
      { id = 'rename', label = 'Rename tab...' },
      { id = 'reset', label = 'Reset tab color' },
      { id = 'blue', label = 'Blue' },
      { id = 'cyan', label = 'Cyan' },
      { id = 'gray', label = 'Gray' },
      { id = 'green', label = 'Green' },
      { id = 'orange', label = 'Orange' },
      { id = 'pink', label = 'Pink' },
      { id = 'purple', label = 'Purple' },
      { id = 'red', label = 'Red' },
      { id = 'yellow', label = 'Yellow' },
    },
    action = wezterm.action_callback(function(window, pane, id)
      if id == nil then
        return
      end

      if id == 'rename' then
        window:perform_action(rename_tab, pane)
      elseif id == 'reset' then
        set_active_tab_background(wezterm, window, '')
      elseif tab_background_presets[id] then
        set_active_tab_background(wezterm, window, tab_background_presets[id])
      end
    end),
  }

  wezterm.on('rename-tab', function(window, pane)
    window:perform_action(rename_tab, pane)
  end)

  wezterm.on('set-tab-background', function(window, pane)
    window:perform_action(set_tab_background, pane)
  end)

  wezterm.on('rename-and-set-tab-background', function(window, pane)
    window:perform_action(rename_and_set_tab_background, pane)
  end)

  wezterm.on('show-tab-actions', function(window, pane)
    window:perform_action(tab_actions_menu, pane)
  end)

  add_command_palette_entry {
    brief = 'Tabs: Actions Menu',
    doc = 'Rename, recolor, or reset the active tab',
    icon = 'md_tab',
    action = act.EmitEvent 'show-tab-actions',
  }
  add_command_palette_entry {
    brief = 'Tabs: Rename Tab',
    doc = 'Set a custom name for the active tab',
    icon = 'md_rename_box',
    action = act.EmitEvent 'rename-tab',
  }
  add_command_palette_entry {
    brief = 'Tabs: Set Tab Color',
    doc = 'Set or reset the active tab background color',
    icon = 'md_format_color_fill',
    action = act.EmitEvent 'set-tab-background',
  }
  add_command_palette_entry {
    brief = 'Tabs: Rename and Color Tab',
    doc = 'Set both tab name and background color',
    icon = 'md_palette',
    action = act.EmitEvent 'rename-and-set-tab-background',
  }

  wezterm.on('augment-command-palette', function()
    return command_palette.entries()
  end)

  wezterm.on('update-status', function(window, pane)
    ensure_tab_background_maps(wezterm)

    local ok_window_id, window_id = pcall(function()
      return window:window_id()
    end)
    local ok_dims, dims = pcall(function()
      return pane:get_dimensions()
    end)
    local ok_tabs, tab_infos = pcall(function()
      return window:mux_window():tabs_with_info()
    end)

    if not ok_window_id or not ok_dims or not ok_tabs then
      return
    end

    local tab_count = #tab_infos
    local cols = tonumber(dims.cols) or 0
    if tab_count <= 0 or cols <= 0 then
      return
    end

    local effective = window:effective_config()
    local reserve = effective.show_new_tab_button_in_tab_bar and 3 or 0
    local width = math.floor((cols - reserve) / tab_count)
    wezterm.GLOBAL.tab_title_widths_by_window[tostring(window_id)] = math.max(width, 1)
  end)

  -- Fancy/native-height tab bar + padded titles gives equal-width tabs while preserving custom colors.
  wezterm.on('format-tab-title', function(tab, tabs, panes, cfg, hover, max_width)
    return tab_title(tab, wezterm, max_width)
  end)
end

return M