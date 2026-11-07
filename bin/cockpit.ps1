# The CockPit launcher for Windows (PowerShell 5.1+ or PowerShell 7).
# (c) 2026 Laden AS, released under the MIT License.
[CmdletBinding()]
param(
  [string]$Ssh,
  [switch]$Hardware,
  [switch]$Version,
  [Parameter(ValueFromRemainingArguments = $true)][string[]]$Program
)
$ErrorActionPreference = 'Stop'
$CockpitVersion = '1.0.0'
$Root = Split-Path -Parent $PSScriptRoot
$Config = Join-Path $Root 'config\cockpit.lua'

if ($Version) { "The CockPit $CockpitVersion"; exit 0 }

$candidates = @()
if ($env:COCKPIT_WEZTERM) { $candidates += $env:COCKPIT_WEZTERM }
$candidates += (Join-Path $Root 'wezterm\wezterm-gui.exe')
$candidates += (Join-Path $env:ProgramFiles 'WezTerm\wezterm-gui.exe')
$onPath = Get-Command wezterm-gui.exe -ErrorAction SilentlyContinue
if ($onPath) { $candidates += $onPath.Source }
$Wez = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if (-not $Wez) {
  Write-Error 'The CockPit needs WezTerm. Use the Windows download that bundles it, install WezTerm from https://wezterm.org/install/windows.html, or set COCKPIT_WEZTERM.'
  exit 127
}

$argv = @('--config-file', $Config, 'start', '--always-new-process', '--class', 'the-cockpit', '--cwd', $HOME)
if ($Ssh) {
  if ($Ssh -notmatch '^[A-Za-z0-9][A-Za-z0-9._@:-]*$') { Write-Error "-Ssh needs an alias or user@host"; exit 2 }
  $argv += @('--', 'ssh.exe', '-a', '-o', 'ForwardAgent=no', '-o', 'ForwardX11=no', '-o', 'StrictHostKeyChecking=ask', '--', $Ssh)
} elseif ($Hardware) {
  $py = Get-Command py.exe -ErrorAction SilentlyContinue
  if (-not $py) { $py = Get-Command python.exe -ErrorAction SilentlyContinue }
  if (-not $py) { Write-Error 'The hardware overview needs Python 3 (python.org).'; exit 127 }
  # Paths travel through the environment, so spaces or quotes in them cannot break the command.
  $env:COCKPIT_PY = $py.Source
  $env:COCKPIT_HW = Join-Path $Root 'tools\cockpit-hardware.py'
  $argv += @('--', 'powershell.exe', '-NoLogo', '-NoProfile', '-Command',
    "& `$env:COCKPIT_PY `$env:COCKPIT_HW; Read-Host 'Press Enter to close' | Out-Null")
} elseif ($Program) {
  $argv += @('--') + $Program
}
# Windows PowerShell 5.1 does not quote array arguments, so build one command line
# with the standard CommandLineToArgvW quoting rules.
function Quote-Arg([string]$a) {
  if ($a -eq '') { return '""' }
  if ($a -notmatch '[\s"]') { return $a }
  $escaped = $a -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1'
  return '"' + $escaped + '"'
}
$line = ($argv | ForEach-Object { Quote-Arg $_ }) -join ' '
Start-Process -FilePath $Wez -ArgumentList $line -WorkingDirectory $HOME
