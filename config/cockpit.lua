-- The CockPit — an emerald terminal cockpit built on WezTerm.
-- © 2026 Laden AS, released under the MIT License. See LICENSE.
--
-- WezTerm loads this file with:  wezterm --config-file <this file> start --class the-cockpit
-- Everything is local-first: nothing connects, signs in or uploads by itself.

local wezterm = require 'wezterm'
local c = wezterm.config_builder and wezterm.config_builder() or {}

local here = wezterm.config_dir
local sep = package.config:sub(1, 1)
local function module(name)
  return dofile(here .. sep .. 'cockpit' .. sep .. name .. '.lua')
end

local platform = module('platform')(wezterm)
local user = platform.user_settings()

module('theme')(wezterm, c, platform)

-- Default shell: fish when installed (the CockPit default), otherwise the
-- user's login shell on Linux/macOS, or PowerShell on Windows. Override with
-- `shell = { ... }` in local.lua.
local shell = platform.default_shell(user.shell)
c.default_prog = shell
c.default_cwd = wezterm.home_dir
if platform.login_path then
  -- macOS apps started from Finder get a minimal PATH; reuse the login shell's.
  c.set_environment_variables = { PATH = platform.login_path }
end

local function local_shell()
  return { args = shell, domain = { DomainName = 'local' }, cwd = wezterm.home_dir }
end

local launch = {
  { label = 'Local shell (' .. platform.basename(shell[1]) .. ')', args = shell, cwd = wezterm.home_dir },
}
for _, extra in ipairs(platform.extra_shells()) do table.insert(launch, extra) end
for _, conn in ipairs(platform.ssh_connections()) do
  table.insert(launch, { label = 'SSH: ' .. conn.label .. ' (explicit connection)', args = conn.argv, cwd = wezterm.home_dir })
end
c.launch_menu = launch

local act = wezterm.action
c.keys = {
  { key = 'd', mods = 'CTRL|SHIFT', action = act.SplitVertical(local_shell()) },
  { key = 'e', mods = 'CTRL|SHIFT', action = act.SplitHorizontal(local_shell()) },
  { key = 't', mods = 'CTRL|SHIFT', action = act.SpawnCommandInNewTab(local_shell()) },
  { key = 'n', mods = 'CTRL|SHIFT', action = act.SpawnCommandInNewWindow(local_shell()) },
  { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentPane { confirm = true } },
  { key = 'p', mods = 'CTRL|SHIFT', action = act.ShowLauncherArgs { flags = 'FUZZY|LAUNCH_MENU_ITEMS' } },
}
for key, dir in pairs({ LeftArrow = 'Left', RightArrow = 'Right', UpArrow = 'Up', DownArrow = 'Down' }) do
  table.insert(c.keys, { key = key, mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection(dir) })
end

module('menu')(wezterm, c, platform, local_shell)

platform.apply_local_overrides(c)
return c
