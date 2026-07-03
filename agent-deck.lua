local M = {}

local plugin_url = 'https://github.com/Eric162/wezterm-agent-deck'

local function terminal_notifier_path()
  local candidates = {
    '/opt/homebrew/bin/terminal-notifier',
    '/usr/local/bin/terminal-notifier',
  }

  for _, path in ipairs(candidates) do
    local file = io.open(path, 'r')
    if file then
      file:close()
      return path
    end
  end

  return 'terminal-notifier'
end

local function load_plugin(wezterm)
  if M.agent_deck ~= nil then
    return M.agent_deck
  end

  M.agent_deck = wezterm.plugin.require(plugin_url)
  return M.agent_deck
end

local function pane_states(tab)
  local agent_deck = M.agent_deck
  if agent_deck == nil then
    return {}
  end

  local states = {}
  for _, pane_info in ipairs(tab.panes or {}) do
    local state = agent_deck.get_agent_state(pane_info.pane_id)
    if state ~= nil then
      table.insert(states, state)
    end
  end

  return states
end

local function add_status_badge(items, agent_deck, counts, status, label)
  local count = counts[status] or 0
  if count <= 0 then
    return
  end

  if #items > 0 then
    table.insert(items, { Text = '  ' })
  end

  table.insert(items, { Foreground = { Color = agent_deck.get_status_color(status) } })
  table.insert(items, { Text = agent_deck.get_status_icon(status) .. ' ' .. count .. ' ' .. label })
end

local function right_status_items(agent_deck)
  local counts = agent_deck.count_agents_by_status()
  local items = {}

  add_status_badge(items, agent_deck, counts, 'waiting', 'waiting')
  add_status_badge(items, agent_deck, counts, 'working', 'working')
  add_status_badge(items, agent_deck, counts, 'idle', 'idle')

  if #items == 0 then
    return items
  end

  table.insert(items, 1, { Text = ' ' })
  table.insert(items, { Text = ' ' })
  return items
end

function M.apply(config, wezterm)
  local agent_deck = load_plugin(wezterm)

  agent_deck.setup {
    update_interval = 1000,
    cooldown_ms = 2000,
    max_lines = 100,

    colors = {
      working = '#50fa7b',
      waiting = '#f1fa8c',
      idle = '#8be9fd',
      inactive = '#6272a4',
    },

    icons = {
      style = 'unicode',
      unicode = {
        working = '●',
        waiting = '◔',
        idle = '○',
        inactive = '◌',
      },
    },

    agents = {
      pi = {
        patterns = { 'pi%-coding%-agent' },
        executable_patterns = {
          '@earendil%-works/pi%-coding%-agent',
          '/pi%-coding%-agent',
          '/pi$',
          '^pi$',
        },
        argv_patterns = {
          '@earendil%-works/pi%-coding%-agent',
          'pi%-coding%-agent',
          '^pi%s',
          '^pi$',
        },
        title_patterns = {
          'pi coding agent',
          '^pi$',
        },
        status_patterns = {
          -- Pi's startup/help text contains words like "thinking" and
          -- "batching-tool-calls"; the plugin's default generic patterns treat
          -- those as active work. Match Pi's actual transient status messages instead.
          working = {
            'working%.%.%.',
            'compacting context%.%.%.',
            'auto%-compacting%.%.%.',
            'context overflow detected, auto%-compacting%.%.%.',
            'summarizing branch%.%.%.',
            'retrying %(%d+/%d+%) in %d+s%.%.%.',
          },
          waiting = {
            -- pi-permissions
            'dangerous command detected',
            'permission required',
            'how do you want to proceed%?',
            'allow once',
            'allow for session',
            'always allow',
            'esc reject',

            -- questionnaire/custom UI
            'enter select',
            'enter confirm',
            'esc cancel',
            'your answer:',
            'ready to submit',
            'unanswered:',

            -- pi-show-diffs
            'review proposed file change',
            'how should pi handle this change%?',
            'enter/y approve',
            'approve %+ enable auto',
            'editing inline',

            -- generic extension prompts
            'allow command',
            'allow tool',
            'do you trust',
            'press enter to continue',
            'esc dismiss',
          },
        },
      },
    },

    notifications = {
      enabled = true,
      on_waiting = true,
      on_finished = true,
      timeout_ms = 5000,
      backend = 'terminal-notifier',
      terminal_notifier = {
        path = terminal_notifier_path(),
        sound = 'default',
        group = 'wezterm-agent-deck',
        title = 'WezTerm Agents',
        activate = true,
        finished_sound = false,
      },
    },
  }

  config.status_update_interval = 1000

  wezterm.on('update-status', function(window)
    local ok, err = pcall(function()
      for _, mux_tab in ipairs(window:mux_window():tabs()) do
        for _, pane in ipairs(mux_tab:panes()) do
          agent_deck.update_pane(pane)
        end
      end
    end)

    if not ok then
      wezterm.log_warn('[agent-deck-config] update failed: ' .. tostring(err))
      return
    end

    local pause_until = tonumber(wezterm.GLOBAL.agent_deck_right_status_pause_until or 0) or 0
    if os.time() < pause_until then
      return
    end

    window:set_right_status(wezterm.format(right_status_items(agent_deck)))
  end)
end

function M.tab_indicator_width(tab, wezterm)
  local agent_deck = M.agent_deck
  if agent_deck == nil then
    return 0
  end

  local width = 0
  for _, state in ipairs(pane_states(tab)) do
    width = width + wezterm.column_width(agent_deck.get_status_icon(state.status))
  end

  return width
end

function M.tab_indicator_items(tab)
  local agent_deck = M.agent_deck
  if agent_deck == nil then
    return {}
  end

  local items = {}
  for _, state in ipairs(pane_states(tab)) do
    table.insert(items, { Foreground = { Color = agent_deck.get_status_color(state.status) } })
    table.insert(items, { Text = agent_deck.get_status_icon(state.status) })
  end

  return items
end

return M
