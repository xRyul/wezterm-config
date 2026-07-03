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
- Local `resurrect.wezterm` integration for saving/restoring workspace layouts.
- `Ctrl+Cmd+S` saves the current workspace.
- `Ctrl+Cmd+R` opens the resurrect fuzzy restore picker.

## Resurrect plugin

This config expects a local `resurrect.wezterm` checkout at `plugins/resurrect.wezterm`. The plugin checkout and saved state files are intentionally ignored here; keep the forked plugin code in its own repository.
