local M = {}

local plugin_url = 'https://github.com/Eric162/wezterm-agent-deck'


local function load_plugin(wezterm)
  if M.agent_deck ~= nil then
    return M.agent_deck
  end

  M.agent_deck = wezterm.plugin.require(plugin_url)
  return M.agent_deck
end

local pi_status_patterns = {
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
}

local pi_waiting_notifications = {}

local function strip_ansi(text)
  if type(text) ~= 'string' then
    return ''
  end

  return text
    :gsub('\27%].-\007', '')
    :gsub('\27%].-\27\\', '')
    :gsub('\27%[[0-9;?]*[A-Za-z]', '')
    :gsub('\r', '')
end

local function pane_text(pane)
  local ok, text = pcall(function()
    return pane:get_lines_as_text(100)
  end)
  if ok and type(text) == 'string' and text ~= '' then
    return strip_ansi(text)
  end

  ok, text = pcall(function()
    return pane:get_logical_lines_as_text(100)
  end)
  if ok and type(text) == 'string' then
    return strip_ansi(text)
  end

  return ''
end

local function matches_any(text, patterns)
  if text == '' then
    return false
  end

  local lower_text = text:lower()
  for _, pattern in ipairs(patterns or {}) do
    local lower_pattern = pattern:lower()
    local ok, found = pcall(function()
      return lower_text:find(lower_pattern)
    end)
    if ok and found then
      return true
    end
    if not ok and lower_text:find(lower_pattern, 1, true) then
      return true
    end
  end

  return false
end

local function pane_has_pi_waiting_prompt(pane)
  return matches_any(pane_text(pane), pi_status_patterns.waiting)
end

local function applescript_quote(value)
  value = tostring(value or '')
  value = value:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', ' ')
  return '"' .. value .. '"'
end

local function notify_pi_waiting(window, wezterm, pane_id)
  if pi_waiting_notifications[pane_id] then
    return
  end

  pi_waiting_notifications[pane_id] = true
  local message = 'Pi needs your input at ' .. os.date('%H:%M:%S')

  -- macOS suppresses banners from the foreground app. Use osascript as an
  -- external sender so Pi prompts are visible even while WezTerm is focused.
  local script = table.concat({
    'display notification ' .. applescript_quote(message),
    'with title ' .. applescript_quote('Pi / WezTerm'),
    'subtitle ' .. applescript_quote('Attention Needed'),
    'sound name ' .. applescript_quote('Glass'),
  }, ' ')

  local ok, err = pcall(function()
    wezterm.background_child_process { 'osascript', '-e', script }
  end)

  if ok then
    wezterm.log_info('[agent-deck] Pi waiting osascript notification sent for pane ' .. tostring(pane_id))
  else
    wezterm.log_warn('[agent-deck] Pi waiting osascript notification failed: ' .. tostring(err))
    pcall(function()
      window:toast_notification('WezTerm', message, nil, 5000)
    end)
    pcall(function()
      wezterm.background_child_process { '/usr/bin/afplay', '/System/Library/Sounds/Glass.aiff' }
    end)
  end
end

local function clear_pi_waiting_notification(_wezterm, pane_id)
  pi_waiting_notifications[pane_id] = nil
end

local function apply_pi_waiting_overrides(window, agent_deck, wezterm)
  local ok, tabs = pcall(function()
    return window:mux_window():tabs()
  end)
  if not ok or tabs == nil then
    return
  end

  local active_panes = {}
  for _, mux_tab in ipairs(tabs) do
    for _, pane in ipairs(mux_tab:panes()) do
      local pane_id = pane:pane_id()
      active_panes[pane_id] = true

      local state = agent_deck.get_agent_state(pane_id)
      if state == nil then
        clear_pi_waiting_notification(wezterm, pane_id)
      elseif pane_has_pi_waiting_prompt(pane) then
        notify_pi_waiting(window, wezterm, pane_id)
        state.status = 'waiting'
        state.pi_waiting_override = true
      elseif state.pi_waiting_override then
        state.pi_waiting_override = nil
        clear_pi_waiting_notification(wezterm, pane_id)
      elseif state.status ~= 'waiting' then
        clear_pi_waiting_notification(wezterm, pane_id)
      end
    end
  end

  for pane_id, _ in pairs(pi_waiting_notifications) do
    if not active_panes[pane_id] then
      pi_waiting_notifications[pane_id] = nil
    end
  end
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

  agent_deck.apply_to_config(config, {
    update_interval = 1000,
    cooldown_ms = 2000,
    max_lines = 100,

    -- Agent Deck owns detection/cleanup; this config owns tab and right-status rendering.
    tab_title = { enabled = false },
    right_status = { enabled = false },

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
        status_patterns = pi_status_patterns,
      },
    },

    notifications = {
      enabled = true,
      -- Waiting notifications are handled by the Pi-specific osascript override below.
      on_waiting = false,
      on_finished = true,
      timeout_ms = 5000,
      -- Use native WezTerm toasts for non-Pi plugin notifications.
      backend = 'native',
    },
  })

  wezterm.on('update-status', function(window)
    local pause_until = tonumber(wezterm.GLOBAL.agent_deck_right_status_pause_until or 0) or 0
    if os.time() < pause_until then
      return
    end

    apply_pi_waiting_overrides(window, agent_deck, wezterm)
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
