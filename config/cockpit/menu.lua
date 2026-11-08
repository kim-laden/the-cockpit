-- The CockPit menu: right-click or F12. © 2026 Laden AS, MIT License.
-- Every entry runs only when you pick it. Commands are argv arrays.
return function(wezterm, c, P, local_shell)
  local act = wezterm.action
  local entries = {}
  local function add(label, action) table.insert(entries, { label = label, action = action }) end
  local function callback(fn) return wezterm.action_callback(fn) end
  local function spec(argv, cwd, env)
    local s = local_shell(); s.args = argv
    if cwd then s.cwd = cwd end
    if env then s.set_environment_variables = env end
    return s
  end
  local function toast(window, title, msg) window:toast_notification(title, msg, nil, 4500) end
  local function toggle(window, key, first, second)
    local o = window:get_config_overrides() or {}
    local current = o[key]
    if current == nil then current = window:effective_config()[key] end
    if current == first then o[key] = second else o[key] = first end
    window:set_config_overrides(o)
  end
  local function document(name)
    local view = P.pager(P.join(P.docs_dir, name))
    return act.SpawnCommandInNewTab(spec(view.args, nil, view.set_environment_variables))
  end
  local function edit_user_file(name)
    return callback(function(window, pane)
      local path = P.ensure_user_file(name)
      if P.is_windows then
        wezterm.background_child_process({ 'notepad.exe', path })
      else
        window:perform_action(act.SpawnCommandInNewTab(spec(P.editor_argv(path))), pane)
      end
    end)
  end
  local function layout(count)
    return callback(function(window, _pane)
      local _, left = window:mux_window():spawn_tab(local_shell())
      if count >= 2 then
        local s = local_shell(); s.direction = 'Right'; s.size = 0.5
        local right = left:split(s)
        if count == 3 then
          local b = local_shell(); b.direction = 'Bottom'; b.size = 0.5
          right:split(b)
        end
      end
      left:activate()
    end)
  end

  -- Terminals and layouts ---------------------------------------------------
  add('Terminal: new local tab', act.SpawnCommandInNewTab(local_shell()))
  add('Terminal: new local window', act.SpawnCommandInNewWindow(local_shell()))
  add('Split: side by side (local)', act.SplitHorizontal(local_shell()))
  add('Split: top / bottom (local)', act.SplitVertical(local_shell()))
  add('Connections: all profiles (shells, WSL, SSH)', act.ShowLauncherArgs { flags = 'FUZZY|LAUNCH_MENU_ITEMS', title = 'CockPit profiles' })

  -- SSH: only entries the user wrote in connections.lua ---------------------
  local conns = P.ssh_connections()
  for _, conn in ipairs(conns) do
    add('Connections: SSH ' .. conn.label .. ' (explicit, new window)', act.SpawnCommandInNewWindow(spec(conn.argv)))
  end
  if #conns == 0 then
    add('Connections: no SSH servers yet - add one in connections.lua', edit_user_file('connections.lua'))
  end
  add('Connections: edit SSH connections', edit_user_file('connections.lua'))

  -- AI CLI tools you installed and logged into yourself ----------------------
  local agent_catalog = {
    { name = 'Grok (xAI)', cmd = 'grok' },
    { name = 'Claude Code', cmd = 'claude' },
    { name = 'Codex (OpenAI)', cmd = 'codex' },
    { name = 'Cursor Agent', cmd = 'cursor-agent' },
    { name = 'Gemini (Google)', cmd = 'gemini' },
  }
  local names = {}
  for _, a in ipairs(agent_catalog) do table.insert(names, a.cmd) end
  local found = P.which(names)
  local installed = {}
  for _, a in ipairs(agent_catalog) do
    local path = found[a.cmd]
    if path then
      table.insert(installed, { name = a.name, argv = P.command(path) })
      add('Agent: ' .. a.name .. '  (new local tab)', act.SpawnCommandInNewTab(spec(P.command(path))))
    else
      add('Agent: ' .. a.name .. '  - not installed', callback(function(w)
        toast(w, 'The CockPit', a.name .. ' CLI is not installed on this machine.')
      end))
    end
  end
  local custom_agents = P.load_user_file('agents.lua')
  if type(custom_agents) == 'table' then
    for _, p in ipairs(custom_agents) do
      if type(p) == 'table' and type(p.argv) == 'table' and type(p.argv[1]) == 'string' then
        local cwd
        if type(p.cwd) == 'string' and p.cwd ~= '' then cwd = p.cwd:gsub('^~', wezterm.home_dir) end
        local label = p.label or table.concat(p.argv, ' ')
        table.insert(installed, { name = label, argv = p.argv })
        add('Agent (custom): ' .. label .. '  (new local tab)', act.SpawnCommandInNewTab(spec(p.argv, cwd)))
      end
    end
  end
  add('Agents: edit custom profiles', edit_user_file('agents.lua'))

  -- Python and learning -----------------------------------------------------
  local py_catalog, seen = {}, {}
  local cands = P.python_candidates()
  local py_found = P.which(cands)
  for _, cand in ipairs(cands) do
    local path = py_found[cand]
    if path and not seen[path] then
      seen[path] = true
      local ok, success, out, err = pcall(wezterm.run_child_process, P.command(path, '--version'))
      if ok and success then
        local ver = ((out ~= nil and out ~= '' and out) or err or ''):gsub('%s+$', '')
        if not seen[ver] then
          seen[ver] = true
          table.insert(py_catalog, { name = cand, path = path, ver = ver })
        end
      end
    end
  end
  for _, pe in ipairs(py_catalog) do
    add('Python: start ' .. pe.name .. '  [' .. pe.ver .. ']  (new local tab)', act.SpawnCommandInNewTab(spec(P.command(pe.path))))
  end
  if #py_catalog == 0 then
    add('Python: not found - install Python 3 from python.org or your package manager', callback(function(w)
      toast(w, 'The CockPit - Python', 'No Python 3 interpreter was found on PATH.')
    end))
  end
  local function local_cwd(pane)
    local cwd = pane:get_current_working_dir()
    if not cwd then return nil end
    local path, host
    if type(cwd) == 'userdata' then path = cwd.file_path; host = cwd.host
    else host = cwd:match('^file://([^/]*)'); path = cwd:gsub('^file://[^/]*', '') end
    if path == nil or path == '' then return nil end
    if host ~= nil and host ~= '' and host ~= 'localhost' and host ~= wezterm.hostname() then return nil end
    if P.is_windows then path = path:gsub('^/(%a:)', '%1'):gsub('/', '\\') end
    return path
  end
  add('Python: start project .venv / venv (current local folder)', callback(function(window, pane)
    local dir = local_cwd(pane)
    if not dir then return toast(window, 'The CockPit - Python', 'No local folder for this pane (SSH panes are ignored).') end
    for _, py in ipairs(P.venv_pythons(dir)) do
      if P.exists(py) then
        return window:perform_action(act.SpawnCommandInNewTab(spec({ py }, dir)), pane)
      end
    end
    toast(window, 'The CockPit - Python', 'No .venv or venv found in:\n' .. dir)
  end))
  local custom_py = P.load_user_file('python.lua')
  if type(custom_py) == 'table' then
    for _, pe in ipairs(custom_py) do
      if type(pe) == 'table' and type(pe.path) == 'string' and P.exists(pe.path) then
        local cwd
        if type(pe.cwd) == 'string' and pe.cwd ~= '' then cwd = pe.cwd:gsub('^~', wezterm.home_dir) end
        add('Python (custom): ' .. (pe.label or pe.path) .. '  (new local tab)', act.SpawnCommandInNewTab(spec({ pe.path }, cwd)))
      end
    end
  end
  if #py_catalog > 0 then
    for _, a in ipairs(installed) do
      add('Learning: Python + ' .. a.name .. ' tutor (side by side)', callback(function(window, _pane)
        local _, left = window:mux_window():spawn_tab(spec(P.command(py_catalog[1].path)))
        local s = spec(a.argv); s.direction = 'Right'; s.size = 0.5
        left:split(s); left:activate()
      end))
    end
  end
  add('Learning: Python quick-start cheatsheet', document('PYTHON-START.md'))
  add('Learning: tutor prompt template (copy into your AI)', document('PYTHON-TUTOR.md'))
  add('Learning: copy selection for your tutor (copy only, no send)', act.CopyTo 'Clipboard')
  add('Learning: edit custom interpreters', edit_user_file('python.lua'))

  -- Layout, navigation, clipboard, appearance, window -----------------------

  -- IPython (explicit; python -m IPython in chosen interpreter) ------------
  local tools_journal = P.join(P.root, 'tools', 'cockpit-journal')
  local tools_ipy = P.join(P.root, 'tools', 'cockpit-ipython')
  local function ipy_spec(arg, cwd)
    local s = local_shell()
    if P.is_windows then s.args = { arg, '-m', 'IPython' }
    else s.args = { tools_ipy, arg } end
    if cwd then s.cwd = cwd end
    return s
  end
  for _, pe in ipairs(py_catalog) do
    add('IPython: ' .. pe.name .. '  [' .. pe.ver .. ']  (new local tab)', act.SpawnCommandInNewTab(ipy_spec(pe.path)))
  end
  if not P.is_windows then
    add('IPython: Python 3.11 learning venv (if created)  (new local tab)', act.SpawnCommandInNewTab(ipy_spec('python3.11')))
  end
  add('IPython: project .venv / venv (current local folder)', callback(function(window, pane)
    local dir = local_cwd(pane)
    if not dir then return toast(window, 'The CockPit - IPython', 'No local folder for this pane (SSH panes are ignored).') end
    if P.is_windows then
      for _, py in ipairs(P.venv_pythons(dir)) do
        if P.exists(py) then
          return window:perform_action(act.SpawnCommandInNewTab(ipy_spec(py, dir)), pane)
        end
      end
      return toast(window, 'The CockPit - IPython', 'No project .venv or venv in this folder.')
    end
    window:perform_action(act.SpawnCommandInNewTab(ipy_spec('project', dir)), pane)
  end))

  -- Intel Journal requires Linux util-linux script, procfs and KDE dialogs.
  if P.is_linux then
  add('Intel: start capture session (new tab)  [OPT-IN — logs printed output]',
      act.SpawnCommandInNewTab((function()
        local s = local_shell(); s.args = { tools_journal, 'capture' }; return s
      end)()))
  add('Intel: stop capture', callback(function(window, pane)
    local ok, out, err = wezterm.run_child_process({ tools_journal, 'stop' })
    toast(window, 'The CockPit Intel', (out or err or 'done'):gsub('%s+$',''))
  end))
  add('Intel: status', callback(function(window, pane)
    local ok, out, err = wezterm.run_child_process({ tools_journal, 'status' })
    toast(window, 'The CockPit Intel', (out or err or '?'):gsub('%s+$',''):sub(1, 900))
  end))
  add('Intel: quick note', callback(function(window, pane)
    local ok, out, err = wezterm.run_child_process({
      'kdialog', '--textinputbox',
      'The CockPit Intel note (local; may contain secrets if you type them):', '',
      '--title', 'The CockPit Intel'
    })
    local text = (out or ''):gsub('%s+$','')
    if not ok or text == '' then return toast(window, 'The CockPit Intel', 'Note cancelled or empty.') end
    local ok2, out2, err2 = wezterm.run_child_process({ tools_journal, 'note', text })
    toast(window, 'The CockPit Intel', (out2 or err2 or 'saved'):gsub('%s+$',''))
  end))
  add('Intel: save selection → journal', callback(function(window, pane)
    local text = nil
    if window.get_selection_text_for_pane then
      local ok, t = pcall(function() return window:get_selection_text_for_pane(pane) end)
      if ok then text = t end
    end
    if not text or text:match('^%s*$') then
      return toast(window, 'The CockPit Intel',
        'No selection. Select text first (selection only — not scrollback).')
    end
    local cwd = local_cwd(pane)
    local args = { tools_journal, 'selection', '--text', text }
    if cwd then table.insert(args, '--cwd'); table.insert(args, cwd) end
    local ok, out, err = wezterm.run_child_process(args)
    toast(window, 'The CockPit Intel', (out or err or 'saved'):gsub('%s+$',''))
  end))
  add('Intel: set folder (picker)', callback(function(window, pane)
    local ok, out, err = wezterm.run_child_process({ tools_journal, 'set-folder', '--gui' })
    toast(window, 'The CockPit Intel', (out or err or 'done'):gsub('%s+$',''))
  end))
  add('Intel: set case label', callback(function(window, pane)
    local ok, out, err = wezterm.run_child_process({
      'kdialog', '--inputbox', 'Case label (in today\'s filename; empty clears):', '',
      '--title', 'The CockPit Intel'
    })
    local case = (out or ''):gsub('%s+$','')
    local ok2, out2, err2 = wezterm.run_child_process({ tools_journal, 'set-case', case })
    toast(window, 'The CockPit Intel', (out2 or err2 or 'done'):gsub('%s+$',''))
  end))
  add('Intel: open today’s journal', callback(function(window, pane)
    wezterm.run_child_process({ tools_journal, 'open' })
  end))
  add('Intel: open folder', callback(function(window, pane)
    wezterm.run_child_process({ tools_journal, 'open', '--folder' })
  end))
  end
  add('Intel: help / platform availability', document('INTEL.md'))

  add('Layout: one local terminal (new tab)', layout(1))
  add('Layout: two local columns (new tab)', layout(2))
  add('Layout: three local panes (new tab)', layout(3))
  add('Layout: focus / unzoom selected pane', act.TogglePaneZoomState)
  add('Layout: rotate panes clockwise', act.RotatePanes 'Clockwise')
  add('Navigate: select pane', act.PaneSelect { mode = 'Activate' })
  add('Navigate: tabs', act.ShowTabNavigator)
  for _, direction in ipairs({ 'Left', 'Right', 'Up', 'Down' }) do
    add('Resize pane: ' .. direction, act.AdjustPaneSize { direction, 5 })
  end
  add('Clipboard: copy selection', act.CopyTo 'Clipboard')
  add('Clipboard: paste (into focused terminal)', act.PasteFrom 'Clipboard')
  add('Scrollback: search', act.Search 'CurrentSelectionOrEmptyString')
  add('Scrollback: copy / selection mode', act.ActivateCopyMode)
  add('Font: larger', act.IncreaseFontSize)
  add('Font: smaller', act.DecreaseFontSize)
  add('Font: reset', act.ResetFontSize)
  add('Appearance: toggle tabs', callback(function(w) toggle(w, 'enable_tab_bar', true, false) end))
  add('Appearance: toggle transparency', callback(function(w) toggle(w, 'window_background_opacity', 1.0, 0.86) end))
  add('Window: restore (unmaximize)', callback(function(w) w:restore() end))
  add('Window: maximize', callback(function(w) w:maximize() end))
  add('Window: hide / minimize', act.Hide)
  add('Window: fullscreen toggle', act.ToggleFullScreen)
  add('Window: native title bar toggle', callback(function(w) toggle(w, 'window_decorations', 'TITLE|RESIZE', 'RESIZE') end))
  add('Window size: 1000 x 700', callback(function(w) w:restore(); w:set_inner_size(1000, 700) end))
  add('Window size: 1400 x 900', callback(function(w) w:restore(); w:set_inner_size(1400, 900) end))
  add('Close: selected pane (confirm)', act.CloseCurrentPane { confirm = true })
  add('Close: current tab and its panes (confirm)', act.CloseCurrentTab { confirm = true })

  -- System and help ---------------------------------------------------------
  local hw_script = P.join(P.root, 'tools', 'cockpit-hardware.py')
  add('System: local hardware and driver overview (read-only)', callback(function(window, pane)
    if #py_catalog == 0 then return toast(window, 'The CockPit', 'The hardware overview needs Python 3.') end
    local py = py_catalog[1].path
    local argv
    if P.is_windows then
      argv = { P.powershell(), '-NoLogo', '-NoProfile', '-Command',
        '& $env:COCKPIT_PY $env:COCKPIT_HW; Read-Host "Press Enter to close" | Out-Null' }
    else
      argv = { '/bin/sh', '-c', '"$0" "$1"; printf "\\nPress Enter to close..."; read -r _', py, hw_script }
    end
    window:perform_action(act.SpawnCommandInNewTab(spec(argv, nil, { COCKPIT_PY = py, COCKPIT_HW = hw_script })), pane)
  end))
  add('Help: CockPit guide', document('GUIDE.md'))
  add('Help: hardware overview notes', document('HARDWARE.md'))
  add('Settings: edit local overrides (local.lua)', edit_user_file('local.lua'))
  add('Settings: reload configuration', act.ReloadConfiguration)

  local choices = {}
  for i, entry in ipairs(entries) do table.insert(choices, { id = tostring(i), label = entry.label }) end
  local menu = act.InputSelector {
    title = 'The CockPit — terminals, layouts, connections, Python & window',
    fuzzy = true,
    choices = choices,
    action = callback(function(window, pane, id)
      if not id then return end
      local entry = entries[tonumber(id)]
      if entry then window:perform_action(entry.action, pane) end
    end),
  }
  table.insert(c.keys, { key = 'F12', mods = 'NONE', action = menu })
  table.insert(c.keys, { key = 'Space', mods = 'CTRL|ALT', action = menu }) -- laptops where F12 needs Fn
  c.mouse_bindings = c.mouse_bindings or {}
  table.insert(c.mouse_bindings, { event = { Down = { streak = 1, button = 'Right' } }, mods = 'NONE', action = act.Nop })
  table.insert(c.mouse_bindings, { event = { Up = { streak = 1, button = 'Right' } }, mods = 'NONE', action = menu })
  -- Apps that use the mouse (vim, htop) still get it; hold Shift to reach the menu.
  table.insert(c.mouse_bindings, { event = { Drag = { streak = 1, button = 'Left' } }, mods = 'CTRL|SHIFT', action = act.StartWindowDrag })
  return entries
end
