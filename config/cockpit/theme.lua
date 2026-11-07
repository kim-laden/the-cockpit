-- Emerald CockPit look. © 2026 Laden AS, MIT License.
return function(wezterm, c, platform)
  local bg, bg2, hack, code = '#06140e', '#030805', '#00ff9d', '#00e5ff'
  c.colors = {
    foreground = '#a8ffcf', background = bg,
    cursor_bg = hack, cursor_fg = bg, cursor_border = hack,
    selection_bg = '#176343', selection_fg = '#ffffff',
    scrollbar_thumb = '#0d2a1c', split = hack, compose_cursor = '#b8ff66',
    ansi = { '#06140e', '#fa6464', '#49e68c', '#e0d478', '#61b8e8', '#b49ae8', '#66dbc2', '#d3ebdf' },
    brights = { '#42745c', '#ff8d8d', '#8bffae', '#f5ec9e', '#9bdcff', '#d4baff', '#9cffe3', '#ffffff' },
    tab_bar = {
      background = bg2,
      active_tab = { bg_color = '#0a2218', fg_color = hack, intensity = 'Bold' },
      inactive_tab = { bg_color = bg, fg_color = '#5a8a72' },
      inactive_tab_hover = { bg_color = '#0c1a14', fg_color = code },
      new_tab = { bg_color = bg, fg_color = hack },
      new_tab_hover = { bg_color = '#0a2218', fg_color = code },
    },
  }
  -- JetBrains Mono ships inside WezTerm, so this font exists on every platform.
  c.font = wezterm.font_with_fallback({ 'JetBrains Mono', 'DejaVu Sans Mono', 'Menlo', 'Consolas' })
  c.font_size = platform.is_mac and 13 or 12
  c.line_height = 1.08
  c.window_background_opacity = 0.96
  c.window_padding = { left = 8, right = 8, top = 8, bottom = 8 }
  c.inactive_pane_hsb = { saturation = 0.9, brightness = 0.7 }
  c.default_cursor_style = 'BlinkingBar'
  c.cursor_blink_rate = 520
  c.scrollback_lines = 20000
  c.audible_bell = 'Disabled'
  c.enable_tab_bar = false
  c.use_fancy_tab_bar = false
  c.tab_bar_at_bottom = true
  c.check_for_updates = false
  c.skip_close_confirmation_for_processes_named = {}
  -- Frameless with resize borders; Ctrl+Shift+left-drag moves the window and
  -- the menu can bring back the native title bar.
  c.window_decorations = 'RESIZE'
  local edge = '#145c3a'
  c.window_frame = {
    border_left_width = 2, border_right_width = 2, border_top_height = 2, border_bottom_height = 2,
    border_left_color = edge, border_right_color = edge, border_top_color = edge, border_bottom_color = edge,
  }
  wezterm.on('format-tab-title', function(tab, _tabs, _panes, _cfg, _hover, max_width)
    local title = tab.active_pane.title
    if #title > max_width - 4 then title = title:sub(1, max_width - 5) .. '…' end
    return { { Text = ' ⬢ ' .. title .. ' ' } }
  end)
end
