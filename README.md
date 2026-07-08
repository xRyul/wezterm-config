# WezTerm Config

A compact WezTerm configuration inspired by Ghostty defaults, using Dracula colors and macOS-style keyboard shortcuts.

## Features

- Dracula color scheme.
- Compact window padding and 13pt font size.
- Native/fancy WezTerm tab bar with Dracula-themed colors.
- Ghostty-like shortcuts for tabs, panes, search, fullscreen, and config reloads.
- `Cmd+D` splits right.
- `Cmd+Shift+D` splits down.
- `Cmd+Shift+R` renames the current tab.
- `Cmd+Shift+B` sets a tab background color.
- `Cmd + right-click` opens a tab actions menu.
- Tab colors can be selected by name or custom hex value.
- Small portability guards for platform-specific behavior.
- Remote `wezterm-agent-deck` integration for AI-agent tab indicators, right-status summaries, and macOS notifications for Pi waiting prompts.
- Local `resurrect.wezterm` integration for saving/restoring workspace layouts.
- `Ctrl+Cmd+S` saves the current workspace.
- `Ctrl+Cmd+R` opens the resurrect fuzzy restore picker.

## Plugins and external tools

- `wezterm-agent-deck` — remote WezTerm plugin loaded with `wezterm.plugin.require('https://github.com/Eric162/wezterm-agent-deck')`; detects AI-agent panes for custom tab indicators, right-status summaries, and notifications.
- `resurrect.wezterm` — local fork used because this config needs Pi-aware restore metadata: restore an entire saved workspace/session or jump back into one specific saved leaf/pane. This is what lets a Pi task resume at the exact pane/leaf instead of only restoring the whole workspace. It also preserves cwd, visible text, tab colors, and Pi restore commands.
- `osascript` — macOS notification helper used for Pi waiting prompts so banners still appear while WezTerm is focused. Agent-finished events use WezTerm native toasts.

## Windows / WSL setup

> Windows WezTerm is native Windows, but this config and local plugin forks live in WSL.

- Config checkout: `\\wsl.localhost\Ubuntu\home\daniel\Developer\Projects\wezterm-config`.
- Windows shim: `C:\Users\daniel\.config\wezterm\wezterm.lua` loads the WSL checkout.
- Resurrect fork checkout: `\\wsl.localhost\Ubuntu\home\daniel\Developer\Projects\resurrect.wezterm`.
- WSL plugin symlink: `~/.config/wezterm/plugins/resurrect.wezterm -> ~/Developer/Projects/resurrect.wezterm`.
- Windows loads `resurrect.wezterm` directly from the WSL checkout because native WezTerm rejects WSL UNC `file://` plugin URLs when the top-level config is loaded from the Windows shim.
- Windows aliases: `Ctrl+Alt+S` saves the workspace, `Ctrl+Alt+Shift+S` saves as, and `Ctrl+Alt+R` opens the resurrect restore picker.
