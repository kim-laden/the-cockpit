-- Platform helpers for The CockPit. © 2026 Laden AS, MIT License.
-- All external commands are argv arrays (never shell-interpolated user text).
return function(wezterm)
  local M = {}
  local triple = wezterm.target_triple or ''
  M.is_windows = triple:find('windows') ~= nil
  M.is_mac = triple:find('apple') ~= nil or triple:find('darwin') ~= nil
  M.is_linux = not M.is_windows and not M.is_mac
  M.sep = package.config:sub(1, 1)
  M.app_dir = wezterm.config_dir                       -- .../config
  M.root = M.app_dir:gsub('[/\\][^/\\]+$', '')          -- install root

  function M.join(...) return table.concat({ ... }, M.sep) end
  function M.exists(path)
    local f = path and io.open(path, 'r')
    if f then f:close(); return true end
    return false
  end
  function M.basename(path) return (tostring(path):gsub('^.*[/\\]', '')) end
  local function safe_name(s) return type(s) == 'string' and s:match('^[%w][%w%._%-]*$') ~= nil end
  M.safe_name = safe_name

  -- Per-user settings live outside the install so upgrades never overwrite them.
  local env_dir = os.getenv('COCKPIT_USER_DIR')
  if env_dir and env_dir ~= '' then
    M.user_dir = env_dir
  elseif M.is_windows then
    M.user_dir = M.join(os.getenv('APPDATA') or wezterm.home_dir, 'TheCockPit')
  else
    local xdg = os.getenv('XDG_CONFIG_HOME')
    if not xdg or xdg == '' then xdg = wezterm.home_dir .. '/.config' end
    M.user_dir = xdg .. '/the-cockpit'
  end
  M.docs_dir = M.join(M.root, 'docs')
  M.examples_dir = M.join(M.app_dir, 'examples')

  local function run(argv)
    local ok, success, out = pcall(wezterm.run_child_process, argv)
    if ok and success and out then return out end
    return nil
  end

  -- macOS GUI apps get a minimal PATH. Ask the login shell once (works for
  -- bash, zsh and fish: a quoted "$PATH" is colon-joined in all of them).
  local base_path = os.getenv('PATH') or ''
  if M.is_mac then
    local login = os.getenv('SHELL')
    if login and login:sub(1, 1) == '/' then
      local out = run({ login, '-l', '-c', 'printf "%s" "$PATH"' })
      if out and out:find('/') then base_path = out end
    end
    for _, extra in ipairs({ '/opt/homebrew/bin', '/usr/local/bin' }) do
      if not (':' .. base_path .. ':'):find(':' .. extra .. ':', 1, true) then base_path = base_path .. ':' .. extra end
    end
    M.login_path = base_path
  end

  -- Resolve several command names in ONE child process. Returns name -> full path.
  local resolved = {}
  function M.which(names)
    local want = {}
    for _, n in ipairs(names) do
      if safe_name(n) and resolved[n] == nil then table.insert(want, n) end
    end
    if #want > 0 then
      for _, n in ipairs(want) do resolved[n] = false end
      if M.is_windows then
        local rank = { ['.exe'] = 1, ['.com'] = 1, ['.cmd'] = 2, ['.bat'] = 2, ['.ps1'] = 3 }
        local best = {}
        local out = run({ 'powershell.exe', '-NoLogo', '-NoProfile', '-NonInteractive', '-Command',
          'Get-Command -CommandType Application,ExternalScript -ErrorAction SilentlyContinue -Name '
          .. table.concat(want, ',') .. ' | ForEach-Object { $_.Name + "`t" + $_.Source }' })
        for line in (out or ''):gmatch('[^\r\n]+') do
          local name, path = line:match('^([^\t]+)\t(.+)$')
          if name then
            local stem, ext = name:lower():match('^(.-)(%.[%w]+)$')
            stem = stem or name:lower(); ext = ext or ''
            local r = rank[ext] or 9
            if best[stem] == nil or r < best[stem].r then best[stem] = { r = r, path = path } end
          end
        end
        for _, n in ipairs(want) do
          if best[n:lower()] then resolved[n] = best[n:lower()].path end
        end
      else
        local extra = wezterm.home_dir .. '/.local/bin:' .. wezterm.home_dir .. '/.cargo/bin:' .. wezterm.home_dir .. '/bin'
        local script = 'PATH="$PATH:' .. extra .. '"; for c in "$@"; do p=$(command -v "$c" 2>/dev/null) && printf "%s\\t%s\\n" "$c" "$p"; done'
        local argv = { '/bin/sh', '-c', script, 'sh' }
        for _, n in ipairs(want) do table.insert(argv, n) end
        local ok, success, out = pcall(wezterm.run_child_process, argv)
        if ok and out then
          for line in out:gmatch('[^\n]+') do
            local name, path = line:match('^([^\t]+)\t(/.+)$')
            if name then resolved[name] = path end
          end
        end
      end
    end
    local result = {}
    for _, n in ipairs(names) do if resolved[n] then result[n] = resolved[n] end end
    return result
  end

  -- Turn a resolved executable into an argv (Windows PowerShell scripts need a host).
  function M.command(path, ...)
    local argv = {}
    if M.is_windows and path:lower():match('%.ps1$') then
      argv = { M.powershell(), '-NoLogo', '-ExecutionPolicy', 'Bypass', '-File', path }
    else
      argv = { path }
    end
    for _, a in ipairs({ ... }) do table.insert(argv, a) end
    return argv
  end

  function M.powershell()
    if M._ps then return M._ps end
    local found = M.which({ 'pwsh' })
    M._ps = found.pwsh or 'powershell.exe'
    return M._ps
  end

  -- ------------------------------------------------------------- user files
  local function load_user_file(name)
    for _, dir in ipairs({ M.user_dir }) do
      local p = M.join(dir, name)
      if M.exists(p) then
        local ok, value = pcall(dofile, p)
        if ok then return value end
        wezterm.log_error('CockPit: could not load ' .. p .. ': ' .. tostring(value))
        return nil
      end
    end
    return nil
  end
  M.load_user_file = load_user_file

  function M.user_settings()
    local v = load_user_file('local.lua')
    if type(v) == 'table' then M._local = v; return v end
    if type(v) == 'function' then M._local_fn = v end
    return {}
  end

  function M.apply_local_overrides(c)
    if M._local_fn then
      local ok, err = pcall(M._local_fn, c, wezterm)
      if not ok then wezterm.log_error('CockPit local.lua: ' .. tostring(err)) end
    elseif M._local then
      for k, v in pairs(M._local) do if k ~= 'shell' then c[k] = v end end
    end
  end

  -- Copy an example into the user dir the first time it is edited.
  function M.ensure_user_file(name)
    local target = M.join(M.user_dir, name)
    if M.exists(target) then return target end
    if M.is_windows then
      run({ 'cmd.exe', '/d', '/c', 'if not exist "' .. M.user_dir .. '" mkdir "' .. M.user_dir .. '"' })
    else
      run({ 'mkdir', '-p', '--', M.user_dir })
    end
    local src = io.open(M.join(M.examples_dir, name), 'rb')
    local content = src and src:read('*a') or '-- The CockPit: ' .. name .. '\nreturn {}\n'
    if src then src:close() end
    local out = io.open(target, 'wb')
    if out then out:write(content); out:close() end
    return target
  end

  -- ---------------------------------------------------------------- shells
  function M.default_shell(override)
    if type(override) == 'table' and type(override[1]) == 'string' then return override end
    if M.is_windows then
      local ps = M.powershell()
      return { ps, '-NoLogo' }
    end
    local found = M.which({ 'fish', 'zsh', 'bash' })
    if found.fish then return { found.fish, '-l' } end
    local login = os.getenv('SHELL')
    if login and login:sub(1, 1) == '/' and M.exists(login) then return { login, '-l' } end
    if found.zsh then return { found.zsh, '-l' } end
    if found.bash then return { found.bash, '-l' } end
    return { '/bin/sh', '-l' }
  end

  function M.extra_shells()
    local list = {}
    if M.is_windows then
      local found = M.which({ 'wsl', 'pwsh' })
      if found.wsl then
        table.insert(list, { label = 'WSL (default Linux distro, fish/bash inside)', args = { found.wsl, '~' } })
      end
      table.insert(list, { label = 'Windows PowerShell', args = { 'powershell.exe', '-NoLogo' } })
      table.insert(list, { label = 'Command Prompt', args = { 'cmd.exe' } })
    else
      local found = M.which({ 'fish', 'zsh', 'bash' })
      for _, n in ipairs({ 'fish', 'zsh', 'bash' }) do
        if found[n] then table.insert(list, { label = n .. ' (login)', args = { found[n], '-l' } }) end
      end
    end
    return list
  end

  -- ------------------------------------------------------- SSH connections
  -- connections.lua in the user dir. Nothing connects until you pick an entry.
  function M.ssh_connections()
    if M._ssh then return M._ssh end
    local raw = load_user_file('connections.lua')
    local list = {}
    M._ssh = list
    if type(raw) ~= 'table' then return list end
    local ssh = M.which({ 'ssh' }).ssh or 'ssh'
    for _, e in ipairs(raw) do
      if type(e) == 'table' then
        local argv = { ssh, '-a', '-o', 'ForwardAgent=no', '-o', 'ForwardX11=no', '-o', 'StrictHostKeyChecking=ask' }
        local dest
        if e.alias and safe_name(e.alias) then
          dest = e.alias
        elseif e.host and type(e.host) == 'string' and e.host:match('^[%w][%w%.%-:]*$') then
          dest = e.host
          if e.user then
            if not safe_name(e.user) then dest = nil else dest = e.user .. '@' .. e.host end
          end
          local port = tonumber(e.port or 22)
          if dest and port and port >= 1 and port <= 65535 and port == math.floor(port) then
            table.insert(argv, '-p'); table.insert(argv, tostring(math.floor(port)))
          else
            dest = nil
          end
        end
        if dest then
          table.insert(argv, '--'); table.insert(argv, dest)
          table.insert(list, { label = tostring(e.label or dest), argv = argv })
        else
          wezterm.log_warn('CockPit: skipped an invalid entry in connections.lua')
        end
      end
    end
    return list
  end

  -- ------------------------------------------------------------- viewers
  function M.pager(path)
    if M.is_windows then
      return {
        args = { M.powershell(), '-NoLogo', '-NoProfile', '-Command',
          'Get-Content -LiteralPath $env:COCKPIT_DOC | Out-Host -Paging; Read-Host "Press Enter to close" | Out-Null' },
        set_environment_variables = { COCKPIT_DOC = path },
      }
    end
    local found = M.which({ 'less', 'more' })
    if found.less then return { args = { found.less, '-R', '--', path } } end
    return { args = { found.more or 'more', path } }
  end

  function M.editor_argv(path)
    if M.is_windows then return nil end -- handled with notepad in the background
    for _, var in ipairs({ 'VISUAL', 'EDITOR' }) do
      local e = os.getenv(var)
      if e and safe_name(M.basename(e)) and not e:find('%s') then
        local p = e:sub(1, 1) == '/' and e or M.which({ e })[e]
        if p then return { p, '--', path } end
      end
    end
    local found = M.which({ 'nano', 'vi' })
    return { found.nano or found.vi or 'vi', '--', path }
  end

  function M.python_candidates()
    if M.is_windows then return { 'py', 'python', 'python3' } end
    return { 'python3', 'python3.14', 'python3.13', 'python3.12', 'python3.11', 'python3.10', 'python' }
  end

  function M.venv_pythons(dir)
    if M.is_windows then
      return { dir .. '\\.venv\\Scripts\\python.exe', dir .. '\\venv\\Scripts\\python.exe' }
    end
    return { dir .. '/.venv/bin/python', dir .. '/venv/bin/python' }
  end

  return M
end
