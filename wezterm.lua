local wezterm = require 'wezterm'

-- Let `require` load sibling files from this config directory.
package.path = wezterm.config_dir .. '/?.lua;' .. package.path

local config = wezterm.config_builder()

require('theme').apply(config, wezterm)
require('tab-actions').apply(config, wezterm)
require('keybindings').apply(config, wezterm)
require('platform').apply(config, wezterm)

local is_windows = (wezterm.target_triple or ''):find('windows') ~= nil

local optional_env_vars = {
  resurrect = 'WEZTERM_ENABLE_RESURRECT',
  ['agent-deck'] = 'WEZTERM_ENABLE_AGENT_DECK',
}

local function optional_enabled(module_name)
  if not is_windows then
    return true
  end

  if os.getenv('WEZTERM_ENABLE_PLUGINS') == '1'
    or os.getenv(optional_env_vars[module_name] or '') == '1' then
    return true
  end

  if module_name == 'resurrect' then
    return os.getenv('WEZTERM_DISABLE_RESURRECT') ~= '1'
  end

  if module_name == 'agent-deck' then
    return os.getenv('WEZTERM_DISABLE_AGENT_DECK') ~= '1'
  end

  return false
end

local function apply_optional(module_name)
  if not optional_enabled(module_name) then
    wezterm.log_info('Skipping optional WezTerm module on Windows: ' .. module_name)
    return
  end

  local ok, module = pcall(require, module_name)
  if not ok then
    wezterm.log_warn('Optional WezTerm module failed to load: ' .. module_name .. ': ' .. tostring(module))
    return
  end

  local applied, err = pcall(module.apply, config, wezterm)
  if not applied then
    wezterm.log_warn('Optional WezTerm module failed to apply: ' .. module_name .. ': ' .. tostring(err))
  end
end

apply_optional('resurrect')
apply_optional('agent-deck')

return config
