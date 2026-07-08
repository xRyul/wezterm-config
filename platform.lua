local M = {}

function M.apply(config, wezterm)
  local target = wezterm.target_triple or ''
  local is_windows = target:find('windows') ~= nil

  if not is_windows then
    return
  end

  -- Keep Windows WezTerm launching into this WSL distro by default.
  config.default_domain = 'WSL:Ubuntu'
  config.default_cwd = '//wsl$/Ubuntu/home/daniel'

  -- On Windows, the default native titlebar sits above WezTerm's tab bar.
  -- Integrated buttons place minimize/maximize/close into the tab bar instead.
  config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'
  config.integrated_title_button_style = 'Windows'
  config.integrated_title_button_alignment = 'Right'

  -- Match the previous Windows config so the new checkout does not change
  -- terminal density too aggressively on first load.
  config.font = wezterm.font('Iosevka Term')
  config.font_size = 10.0
  config.line_height = 1.2
end

return M
