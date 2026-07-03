local M = {}

function M.apply(config, wezterm)
  local act = wezterm.action
  local target = wezterm.target_triple or ''
  local is_macos = target:find('apple%-darwin') ~= nil
  local is_windows = target:find('windows') ~= nil


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
    { key = 'RightArrow', mods = 'SUPER', action = act.SendString '\x05' },
    { key = 'LeftArrow', mods = 'SUPER', action = act.SendString '\x01' },
    { key = 'Backspace', mods = 'SUPER', action = act.SendString '\x15' },
    { key = 'LeftArrow', mods = 'ALT', action = act.SendString '\x1bb' },
    { key = 'RightArrow', mods = 'ALT', action = act.SendString '\x1bf' },
  }

  -- Mouse shortcuts inside the terminal pane.
  -- Super/Cmd + right-click opens a tab actions menu without replacing plain right-click behavior.
  config.mouse_bindings = {
    {
      event = { Up = { streak = 1, button = 'Right' } },
      mods = 'SUPER',
      action = act.EmitEvent 'show-tab-actions',
    },
  }

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
