local wezterm = require 'wezterm'

-- Let `require` load sibling files from this config directory.
package.path = wezterm.config_dir .. '/?.lua;' .. package.path

local config = wezterm.config_builder()

require('theme').apply(config, wezterm)
require('tab-actions').apply(config, wezterm)
require('keybindings').apply(config, wezterm)
require('resurrect').apply(config, wezterm)

return config
