local wezterm = require 'wezterm'
local act = wezterm.action

local config = wezterm.config_builder and wezterm.config_builder() or {}

-- Set PowerShell 7 as default shell
config.default_prog = { "C:\\Program Files\\PowerShell\\7\\pwsh.exe" }

-- Font configuration (Nerd Font for better icon support)
config.font = wezterm.font('JetBrainsMono Nerd Font', { weight = 'Regular' })
config.font_size = 11.0
-- Enable ligatures for better code readability
config.harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' }

-- Optional: Set leader key (here, CTRL+SHIFT+SPACE)
config.leader = { key = "Space", mods = "CTRL|SHIFT" }

config.keys = {
  -- Split pane vertically (right)
  {
    key = "|",
    mods = "LEADER|SHIFT",
    action = act.SplitPane { direction = "Right", size = { Percent = 50 } },
  },
  -- Split pane horizontally (down)
  {
    key = "-",
    mods = "LEADER",
    action = act.SplitPane { direction = "Down", size = { Percent = 50 } },
  },
  -- Move between panes (vim-style)
  { key = "h", mods = "CTRL", action = act.ActivatePaneDirection "Left" },
  { key = "j", mods = "CTRL", action = act.ActivatePaneDirection "Down" },
  { key = "k", mods = "CTRL", action = act.ActivatePaneDirection "Up" },
  { key = "l", mods = "CTRL", action = act.ActivatePaneDirection "Right" },
  -- Resize panes
  { key = "h", mods = "ALT", action = act.AdjustPaneSize { "Left", 5 } },
  { key = "j", mods = "ALT", action = act.AdjustPaneSize { "Down", 5 } },
  { key = "k", mods = "ALT", action = act.AdjustPaneSize { "Up", 5 } },
  { key = "l", mods = "ALT", action = act.AdjustPaneSize { "Right", 5 } },
  -- Close current pane
  { key = "x", mods = "LEADER", action = act.CloseCurrentPane { confirm = true } },
  -- Zoom current pane
  { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
  -- Swap panes
  { key = "{", mods = "LEADER|SHIFT", action = act.PaneSelect { mode = "SwapWithActiveKeepFocus" } },
  -- Move to previous/next pane
  { key = ";", mods = "LEADER", action = act.ActivatePaneDirection "Prev" },
  { key = "o", mods = "LEADER", action = act.ActivatePaneDirection "Next" },
  -- Tab management
  { key = "c", mods = "LEADER", action = act.SpawnTab "CurrentPaneDomain" },
  { key = "w", mods = "LEADER", action = act.ShowTabNavigator },
  { key = "&", mods = "LEADER|SHIFT", action = act.CloseCurrentTab { confirm = true } },
}

-- Optional: Put the tab bar at the bottom
config.tab_bar_at_bottom = true

-- Optional: More scrollback
config.scrollback_lines = 5000

-- Optional: Remove window padding
config.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }

return config
