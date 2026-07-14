local M = {}

function M.apply(config, wezterm)
  local act = wezterm.action
  local target = wezterm.target_triple or ''
  local is_macos = target:find('apple%-darwin') ~= nil
  local is_windows = target:find('windows') ~= nil

  local copy_or_send_interrupt = wezterm.action_callback(function(window, pane)
    local selection = window:get_selection_text_for_pane(pane)
    if selection ~= nil and selection ~= '' then
      window:perform_action(act.CopyTo 'Clipboard', pane)
    else
      window:perform_action(act.SendKey { key = 'c', mods = 'CTRL' }, pane)
    end
  end)


  -- Ghostty-like macOS shortcuts.
  config.keys = {
    -- Config, app, tabs, and windows.
    { key = ',', mods = 'SUPER', action = act.EmitEvent 'open-config' },
    { key = ',', mods = 'SHIFT|SUPER', action = act.ReloadConfiguration },
    { key = 'n', mods = 'SUPER', action = act.SpawnWindow },
    { key = 't', mods = 'SUPER', action = act.SpawnTab 'CurrentPaneDomain' },
    { key = 'q', mods = 'SUPER', action = act.QuitApplication },
    { key = 'p', mods = 'SHIFT|SUPER', action = act.ActivateCommandPalette },

    -- Ghostty's Cmd+W closes the current terminal surface, not always the tab.
    { key = 'w', mods = 'SUPER', action = act.CloseCurrentPane { confirm = true } },
    { key = 'w', mods = 'ALT|SUPER', action = act.CloseCurrentTab { confirm = true } },
    -- WezTerm has no exact close-window action here; with one pane this closes the window.
    { key = 'w', mods = 'SHIFT|SUPER', action = act.CloseCurrentPane { confirm = true } },

    -- Tabs.
    { key = '[', mods = 'SHIFT|SUPER', action = act.ActivateTabRelative(-1) },
    { key = ']', mods = 'SHIFT|SUPER', action = act.ActivateTabRelative(1) },
    { key = 'R', mods = 'SHIFT|SUPER', action = act.EmitEvent 'rename-tab' },
    { key = 'B', mods = 'SHIFT|SUPER', action = act.EmitEvent 'set-tab-background' },

    -- Splits/panes: Ghostty Cmd+D = split right, Cmd+Shift+D = split down.
    { key = 'd', mods = 'SUPER', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    { key = 'D', mods = 'SHIFT|SUPER', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
    { key = '[', mods = 'SUPER', action = act.ActivatePaneDirection 'Prev' },
    { key = ']', mods = 'SUPER', action = act.ActivatePaneDirection 'Next' },
    { key = 'UpArrow', mods = 'ALT|SUPER', action = act.ActivatePaneDirection 'Up' },
    { key = 'DownArrow', mods = 'ALT|SUPER', action = act.ActivatePaneDirection 'Down' },
    { key = 'LeftArrow', mods = 'ALT|SUPER', action = act.ActivatePaneDirection 'Left' },
    { key = 'RightArrow', mods = 'ALT|SUPER', action = act.ActivatePaneDirection 'Right' },
    { key = 'UpArrow', mods = 'CTRL|SUPER', action = act.AdjustPaneSize { 'Up', 10 } },
    { key = 'DownArrow', mods = 'CTRL|SUPER', action = act.AdjustPaneSize { 'Down', 10 } },
    { key = 'LeftArrow', mods = 'CTRL|SUPER', action = act.AdjustPaneSize { 'Left', 10 } },
    { key = 'RightArrow', mods = 'CTRL|SUPER', action = act.AdjustPaneSize { 'Right', 10 } },
    { key = 'Enter', mods = 'SHIFT|SUPER', action = act.TogglePaneZoomState },

    -- Fullscreen.
    { key = 'Enter', mods = 'SUPER', action = act.ToggleFullScreen },
    { key = 'f', mods = 'CTRL|SUPER', action = act.ToggleFullScreen },

    -- Clipboard/search/selection.
    { key = 'c', mods = 'SUPER', action = act.CopyTo 'Clipboard' },
    { key = 'v', mods = 'SUPER', action = act.PasteFrom 'Clipboard' },
    { key = 'f', mods = 'SUPER', action = act.Search 'CurrentSelectionOrEmptyString' },
    { key = 'e', mods = 'SUPER', action = act.Search 'CurrentSelectionOrEmptyString' },
    -- { key = 'k', mods = 'SUPER', action = act.ClearScrollback 'ScrollbackAndViewport' },

    -- Scrolling and shell-style line movement.
    { key = 'Home', mods = 'SUPER', action = act.ScrollToTop },
    { key = 'End', mods = 'SUPER', action = act.ScrollToBottom },
    { key = 'PageUp', mods = 'SUPER', action = act.ScrollByPage(-1) },
    { key = 'PageDown', mods = 'SUPER', action = act.ScrollByPage(1) },
    { key = 'UpArrow', mods = 'SHIFT|SUPER', action = act.ScrollToPrompt(-1) },
    { key = 'DownArrow', mods = 'SHIFT|SUPER', action = act.ScrollToPrompt(1) },
    { key = 'UpArrow', mods = 'SUPER', action = act.ScrollToPrompt(-1) },
    { key = 'DownArrow', mods = 'SUPER', action = act.ScrollToPrompt(1) },
    { key = 'LeftArrow', mods = 'ALT', action = act.SendString '\x1bb' },
    { key = 'RightArrow', mods = 'ALT', action = act.SendString '\x1bf' },
  }

  if not is_windows then
    -- Non-Windows shell-style line movement. On Windows these raw control bytes
    -- can trigger font warnings for unrenderable control glyphs such as U+0001.
    table.insert(config.keys, { key = 'RightArrow', mods = 'SUPER', action = act.SendString '\x05' })
    table.insert(config.keys, { key = 'LeftArrow', mods = 'SUPER', action = act.SendString '\x01' })
    table.insert(config.keys, { key = 'Backspace', mods = 'SUPER', action = act.SendString '\x15' })
  end

  if is_windows then
    -- Windows-friendly aliases for the macOS Cmd/Super bindings above.
    -- The original Super bindings are kept for macOS; these avoid relying on
    -- Win-key chords that Windows often intercepts.
    local function add_windows_key(key, mods, action)
      table.insert(config.keys, { key = key, mods = mods, action = action })
    end

    -- Config, app, tabs, and windows. Windows mirrors macOS/Ghostty
    -- by using Ctrl where macOS uses Cmd/Super.
    add_windows_key(',', 'CTRL', act.EmitEvent 'open-config')
    add_windows_key(',', 'CTRL|SHIFT', act.ReloadConfiguration)
    add_windows_key('n', 'CTRL', act.SpawnWindow)
    add_windows_key('t', 'CTRL', act.SpawnTab 'CurrentPaneDomain')
    add_windows_key('q', 'CTRL', act.QuitApplication)
    add_windows_key('p', 'CTRL|SHIFT', act.ActivateCommandPalette)

    -- Close actions: mirror Cmd+W / Opt+Cmd+W / Shift+Cmd+W.
    add_windows_key('w', 'CTRL', act.CloseCurrentPane { confirm = true })
    add_windows_key('phys:W', 'CTRL', act.CloseCurrentPane { confirm = true })
    add_windows_key('w', 'CTRL|ALT', act.CloseCurrentTab { confirm = true })
    add_windows_key('w', 'CTRL|SHIFT', act.CloseCurrentPane { confirm = true })

    -- Tabs and tab metadata.
    add_windows_key('[', 'CTRL|SHIFT', act.ActivateTabRelative(-1))
    add_windows_key(']', 'CTRL|SHIFT', act.ActivateTabRelative(1))
    add_windows_key('r', 'CTRL|SHIFT', act.EmitEvent 'rename-tab')
    add_windows_key('b', 'CTRL|SHIFT', act.EmitEvent 'set-tab-background')
    add_windows_key('x', 'CTRL|SHIFT', act.EmitEvent 'reset-tab-background')

    -- Splits and pane movement.
    add_windows_key('d', 'CTRL', act.SplitHorizontal { domain = 'CurrentPaneDomain' })
    add_windows_key('phys:D', 'CTRL', act.SplitHorizontal { domain = 'CurrentPaneDomain' })
    add_windows_key('d', 'CTRL|SHIFT', act.SplitVertical { domain = 'CurrentPaneDomain' })
    add_windows_key('phys:D', 'CTRL|SHIFT', act.SplitVertical { domain = 'CurrentPaneDomain' })
    add_windows_key('[', 'CTRL', act.ActivatePaneDirection 'Prev')
    add_windows_key(']', 'CTRL', act.ActivatePaneDirection 'Next')
    add_windows_key('LeftArrow', 'CTRL|ALT', act.ActivatePaneDirection 'Left')
    add_windows_key('RightArrow', 'CTRL|ALT', act.ActivatePaneDirection 'Right')
    add_windows_key('UpArrow', 'CTRL|ALT', act.ActivatePaneDirection 'Up')
    add_windows_key('DownArrow', 'CTRL|ALT', act.ActivatePaneDirection 'Down')
    -- macOS uses Ctrl+Cmd+Arrow; use Ctrl+Shift+Alt on Windows to avoid
    -- colliding with the plain Ctrl+Arrow prompt-scrolling aliases below.
    add_windows_key('LeftArrow', 'CTRL|SHIFT|ALT', act.AdjustPaneSize { 'Left', 10 })
    add_windows_key('RightArrow', 'CTRL|SHIFT|ALT', act.AdjustPaneSize { 'Right', 10 })
    add_windows_key('UpArrow', 'CTRL|SHIFT|ALT', act.AdjustPaneSize { 'Up', 10 })
    add_windows_key('DownArrow', 'CTRL|SHIFT|ALT', act.AdjustPaneSize { 'Down', 10 })
    add_windows_key('Enter', 'CTRL|SHIFT', act.TogglePaneZoomState)

    -- Fullscreen.
    add_windows_key('Enter', 'CTRL', act.ToggleFullScreen)
    add_windows_key('f', 'CTRL|ALT', act.ToggleFullScreen)

    -- Clipboard/search/selection.
    add_windows_key('c', 'CTRL', copy_or_send_interrupt)
    add_windows_key('v', 'CTRL', act.PasteFrom 'Clipboard')
    add_windows_key('f', 'CTRL', act.Search 'CurrentSelectionOrEmptyString')
    add_windows_key('e', 'CTRL', act.Search 'CurrentSelectionOrEmptyString')

    -- Scrolling.
    add_windows_key('Home', 'CTRL', act.ScrollToTop)
    add_windows_key('End', 'CTRL', act.ScrollToBottom)
    add_windows_key('PageUp', 'CTRL', act.ScrollByPage(-1))
    add_windows_key('PageDown', 'CTRL', act.ScrollByPage(1))
    add_windows_key('UpArrow', 'CTRL|SHIFT', act.ScrollToPrompt(-1))
    add_windows_key('DownArrow', 'CTRL|SHIFT', act.ScrollToPrompt(1))
    add_windows_key('UpArrow', 'CTRL', act.ScrollToPrompt(-1))
    add_windows_key('DownArrow', 'CTRL', act.ScrollToPrompt(1))
  end

  -- Remove WezTerm's Cmd+1..9 tab shortcuts so Herdr receives the original keys.
  if is_macos then
    for index = 1, 9 do
      table.insert(config.keys, {
        key = tostring(index),
        mods = 'SUPER',
        action = act.DisableDefaultAssignment,
      })
    end
  end

  -- Mouse shortcuts inside the terminal pane.
  -- Super/Cmd + right-click opens a tab actions menu without replacing plain right-click behavior.
  config.mouse_bindings = {
    {
      event = { Up = { streak = 1, button = 'Right' } },
      mods = 'SUPER',
      action = act.EmitEvent 'show-tab-actions',
    },
  }

  if is_windows then
    -- Windows-friendly alias for keyboards where Cmd maps to Win/Super or
    -- where Win-key mouse chords are intercepted before WezTerm sees them.
    table.insert(config.mouse_bindings, {
      event = { Up = { streak = 1, button = 'Right' } },
      mods = 'CTRL',
      action = act.EmitEvent 'show-tab-actions',
    })
  end

  config.key_tables = {
    search_mode = {
      { key = 'Enter', mods = 'NONE', action = act.CopyMode 'PriorMatch' },
      { key = 'Escape', mods = 'NONE', action = act.CopyMode 'Close' },
      { key = 'F', mods = 'SHIFT|SUPER', action = act.CopyMode 'Close' },
      { key = 'g', mods = 'SUPER', action = act.CopyMode 'NextMatch' },
      { key = 'G', mods = 'SHIFT|SUPER', action = act.CopyMode 'PriorMatch' },
      { key = 'n', mods = 'CTRL', action = act.CopyMode 'NextMatch' },
      { key = 'p', mods = 'CTRL', action = act.CopyMode 'PriorMatch' },
      { key = 'r', mods = 'CTRL', action = act.CopyMode 'CycleMatchType' },
      { key = 'u', mods = 'CTRL', action = act.CopyMode 'ClearPattern' },
      { key = 'PageUp', mods = 'NONE', action = act.CopyMode 'PriorMatchPage' },
      { key = 'PageDown', mods = 'NONE', action = act.CopyMode 'NextMatchPage' },
      { key = 'UpArrow', mods = 'NONE', action = act.CopyMode 'PriorMatch' },
      { key = 'DownArrow', mods = 'NONE', action = act.CopyMode 'NextMatch' },
    },
  }

  if is_windows then
    table.insert(config.key_tables.search_mode, { key = 'f', mods = 'CTRL', action = act.CopyMode 'Close' })
    table.insert(config.key_tables.search_mode, { key = 'g', mods = 'CTRL', action = act.CopyMode 'NextMatch' })
    table.insert(config.key_tables.search_mode, { key = 'g', mods = 'CTRL|SHIFT', action = act.CopyMode 'PriorMatch' })
  end

  wezterm.on('open-config', function()
    local command
    if is_macos then
      command = { 'open', wezterm.config_file }
    elseif is_windows then
      command = { 'cmd.exe', '/C', 'start', '', wezterm.config_file }
    else
      command = { 'xdg-open', wezterm.config_file }
    end

    wezterm.background_child_process(command)
  end)

  local command_palette = require 'command-palette'
  command_palette.add {
    brief = 'Config: Open WezTerm Config',
    doc = 'Open the active WezTerm config file',
    icon = 'md_cog',
    action = act.EmitEvent 'open-config',
  }
end

return M
