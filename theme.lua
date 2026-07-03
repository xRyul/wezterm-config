local M = {}

function M.apply(config, wezterm)
  local target = wezterm.target_triple or ''
  local is_macos = target:find('apple%-darwin') ~= nil

  -- Match Ghostty config:
  --   theme = Dracula
  --   macos-titlebar-style = tabs
  -- plus Ghostty defaults for font size and window padding.
  config.color_scheme = 'Dracula'
  config.font_size = 13.0
  config.max_fps = 120

  -- Dracula-styled command palette. WezTerm uses the foreground color as
  -- the selected-row background, so purple gives the palette a clear accent.
  config.command_palette_bg_color = '#282a36'
  config.command_palette_fg_color = '#bd93f9'
  config.command_palette_font_size = 14.5
  config.command_palette_rows = 14
  config.palette_max_key_assigments_for_action = 1

  config.window_padding = {
    left = 2,
    right = 2,
    top = 2,
    bottom = 2,
  }

  -- Tab/titlebar setup. Integrated traffic-light buttons are macOS-only.
  config.enable_tab_bar = true
  config.hide_tab_bar_if_only_one_tab = false
  config.use_fancy_tab_bar = true
  config.show_new_tab_button_in_tab_bar = false
  -- High cap; tab-actions.lua computes the real equal width per window.
  config.tab_max_width = 999

  if is_macos then
    config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'
    config.window_frame = {
      active_titlebar_bg = '#282a36',
      inactive_titlebar_bg = '#282a36',
    }
  end

  -- Match Ghostty's unfocused split dimming.
  -- Ghostty default: unfocused-split-opacity = 0.7.
  config.inactive_pane_hsb = {
    saturation = 0.85,
    brightness = 0.70,
  }

  -- Keep the tab bar visually aligned with Dracula.
  config.colors = {
    split = '#44475a',
    tab_bar = {
      background = '#282a36',
      active_tab = {
        bg_color = '#44475a',
        fg_color = '#f8f8f2',
        intensity = 'Bold',
      },
      inactive_tab = {
        bg_color = '#282a36',
        fg_color = '#6272a4',
      },
      inactive_tab_hover = {
        bg_color = '#44475a',
        fg_color = '#f8f8f2',
      },
      new_tab = {
        bg_color = '#282a36',
        fg_color = '#bd93f9',
      },
      new_tab_hover = {
        bg_color = '#44475a',
        fg_color = '#f8f8f2',
      },
    },
  }
end

return M
