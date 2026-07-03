local M = {}

local function state_name_from_id(id)
  local name = id:match('([^/\\]+)$') or id
  return name:gsub('%.json$', '')
end

local function state_type_from_id(id)
  return id:match('^([^/\\]+)')
end

function M.apply(config, wezterm)
  local act = wezterm.action
  local save_workspace_event = 'Resurrect: Save Workspace'
  local save_workspace_as_event = 'Resurrect: Save Workspace As...'
  local fuzzy_restore_event = 'Resurrect: Restore Saved State'
  local plugin_dir = '/Users/daniel/.config/wezterm/plugins/resurrect.wezterm'

  wezterm.GLOBAL.resurrect_local_plugin_dir = plugin_dir
  package.path = table.concat({
    plugin_dir .. '/plugin/?.lua',
    plugin_dir .. '/plugin/?/init.lua',
    package.path,
  }, ';')

  local resurrect_modules = {
    'resurrect.file_io',
    'resurrect.fuzzy_loader',
    'resurrect.pane_tree',
    'resurrect.state_manager',
    'resurrect.tab_state',
    'resurrect.window_state',
    'resurrect.workspace_state',
  }

  for _, module_name in ipairs(resurrect_modules) do
    package.loaded[module_name] = nil
  end

  local resurrect = wezterm.plugin.require('file://' .. plugin_dir)
  resurrect.workspace_state = require 'resurrect.workspace_state'
  resurrect.window_state = require 'resurrect.window_state'
  resurrect.tab_state = require 'resurrect.tab_state'
  resurrect.fuzzy_loader = require 'resurrect.fuzzy_loader'
  resurrect.state_manager = require 'resurrect.state_manager'
  resurrect.state_manager.change_state_save_dir(plugin_dir .. '/state/')
  local last_save_marker = '/Users/daniel/.config/wezterm/resurrect-last-save.txt'

  local function workspace_state_path(workspace)
    return plugin_dir .. '/state/workspace/' .. workspace:gsub('/', '+') .. '.json'
  end

  local function trim(value)
    if type(value) ~= 'string' then
      return ''
    end

    return value:gsub('^%s+', ''):gsub('%s+$', '')
  end

  local function count_pane_tree(pane_tree, counts)
    if type(pane_tree) ~= 'table' then
      return
    end

    counts.panes = counts.panes + 1
    if pane_tree.restore and pane_tree.restore.type == 'pi-jump' then
      counts.pi = counts.pi + 1
    elseif pane_tree.restore and pane_tree.restore.type == 'shell-command' then
      counts.commands = counts.commands + 1
    end

    count_pane_tree(pane_tree.right, counts)
    count_pane_tree(pane_tree.bottom, counts)
  end

  local function summarize_workspace_state(state)
    local counts = { windows = 0, tabs = 0, panes = 0, pi = 0, commands = 0, tab_colors = 0 }
    for _, window_state in ipairs(state.window_states or {}) do
      counts.windows = counts.windows + 1
      for _, tab_state in ipairs(window_state.tabs or {}) do
        counts.tabs = counts.tabs + 1
        if type(tab_state.custom_background) == 'string' and tab_state.custom_background ~= '' then
          counts.tab_colors = counts.tab_colors + 1
        end
        count_pane_tree(tab_state.pane_tree, counts)
      end
    end
    return counts
  end

  local function format_save_summary(summary)
    return string.format(
      '%d windows, %d tabs, %d panes, %d tab colors, %d pi restores, %d command restores',
      summary.windows,
      summary.tabs,
      summary.panes,
      summary.tab_colors,
      summary.pi,
      summary.commands
    )
  end

  local function write_last_save_marker(workspace, state_path, timestamp, summary)
    local file = io.open(last_save_marker, 'w')
    if not file then
      return
    end

    file:write('workspace=' .. workspace .. '\n')
    file:write('saved_at=' .. timestamp .. '\n')
    file:write('state_file=' .. state_path .. '\n')
    file:write('windows=' .. summary.windows .. '\n')
    file:write('tabs=' .. summary.tabs .. '\n')
    file:write('panes=' .. summary.panes .. '\n')
    file:write('tab_colors=' .. summary.tab_colors .. '\n')
    file:write('pi_restores=' .. summary.pi .. '\n')
    file:write('command_restores=' .. summary.commands .. '\n')
    file:close()
  end

  local function show_save_status(window, workspace, state_path, summary)
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local short_time = os.date('%H:%M:%S')
    local summary_text = format_save_summary(summary)
    local message = 'Saved workspace: ' .. workspace .. ' at ' .. short_time .. ' (' .. summary_text .. ')'

    wezterm.GLOBAL.resurrect_last_save = message
    write_last_save_marker(workspace, state_path, timestamp, summary)
    window:toast_notification('WezTerm', message, nil, 5000)
    window:set_right_status(wezterm.format {
      { Foreground = { Color = '#50fa7b' } },
      { Text = ' 󰆓 ' .. message .. ' ' },
    })

    wezterm.time.call_after(10, function()
      if wezterm.GLOBAL.resurrect_last_save == message then
        window:set_right_status('')
      end
    end)
  end


  local function restore_opts(pane)
    return {
      window = pane:window(),
      tab = pane:tab(),
      pane = pane,
      relative = true,
      restore_text = true,
      close_open_tabs = true,
      close_open_panes = true,
      on_pane_restore = resurrect.tab_state.default_on_pane_restore,
    }
  end

  local function save_workspace(window, opt_name)
    local state = resurrect.workspace_state.get_workspace_state()
    local save_name = trim(opt_name)
    if save_name == '' then
      save_name = state.workspace
    end

    local state_path = workspace_state_path(save_name)

    local summary = summarize_workspace_state(state)
    resurrect.state_manager.save_state(state, save_name)
    resurrect.state_manager.write_current_state(save_name, 'workspace')
    show_save_status(window, save_name, state_path, summary)
  end

  local function save_workspace_as(window, pane)
    window:perform_action(
      act.PromptInputLine {
        description = 'Save workspace as name',
        action = wezterm.action_callback(function(prompt_window, _prompt_pane, line)
          local save_name = trim(line)
          if save_name == '' then
            return
          end
          save_workspace(prompt_window, save_name)
        end),
      },
      pane
    )
  end

  local function restore_state(id, pane)
    local kind = state_type_from_id(id)
    local name = state_name_from_id(id)
    local opts = restore_opts(pane)

    if kind == 'workspace' then
      -- Do not reuse the pane that launched restore. It may already be running
      -- pi, which would receive the restore command as typed input.
      opts.tab = nil
      opts.pane = nil
    end

    if kind == 'workspace' then
      resurrect.workspace_state.restore_workspace(resurrect.state_manager.load_state(name, 'workspace'), opts)
    elseif kind == 'window' then
      resurrect.window_state.restore_window(pane:window(), resurrect.state_manager.load_state(name, 'window'), opts)
    elseif kind == 'tab' then
      resurrect.tab_state.restore_tab(pane:tab(), resurrect.state_manager.load_state(name, 'tab'), opts)
    end
  end

  local function fuzzy_restore(window, pane)
    resurrect.fuzzy_loader.fuzzy_load(window, pane, function(id)
      restore_state(id, pane)
    end, {
      title = 'Restore WezTerm State',
      description = 'Select state to restore. Enter accepts, Esc cancels, / filters.',
      show_state_with_date = true,
    })
  end

  config.keys = config.keys or {}
  table.insert(config.keys, { key = 's', mods = 'CTRL|SUPER', action = act.EmitEvent(save_workspace_event) })
  table.insert(config.keys, { key = 'S', mods = 'CTRL|SHIFT|SUPER', action = act.EmitEvent(save_workspace_as_event) })
  table.insert(config.keys, { key = 'r', mods = 'CTRL|SUPER', action = act.EmitEvent(fuzzy_restore_event) })

  wezterm.on(save_workspace_event, function(window)
    save_workspace(window)
  end)

  wezterm.on(save_workspace_as_event, function(window, pane)
    save_workspace_as(window, pane)
  end)

  wezterm.on(fuzzy_restore_event, function(window, pane)
    fuzzy_restore(window, pane)
  end)

  local command_palette = require 'command-palette'
  command_palette.add {
    brief = 'Resurrect: Save Workspace',
    doc = 'Save windows, tabs, panes, cwd, and visible text',
    icon = 'md_content_save',
    action = act.EmitEvent(save_workspace_event),
  }
  command_palette.add {
    brief = 'Resurrect: Save Workspace As…',
    doc = 'Save the current workspace under a custom name',
    icon = 'md_content_save_edit',
    action = act.EmitEvent(save_workspace_as_event),
  }
  command_palette.add {
    brief = 'Resurrect: Restore Saved State',
    doc = 'Restore saved workspace, window, or tab state',
    icon = 'md_backup_restore',
    action = act.EmitEvent(fuzzy_restore_event),
  }
end

return M
