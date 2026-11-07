# Install The CockPit for the current user on Windows 10/11 (no admin needed).
# (c) 2026 Laden AS, released under the MIT License.
#
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 [-Desktop]
#
# Copies the app (with the bundled WezTerm) to %LOCALAPPDATA%\Programs\TheCockPit,
# adds a Start menu shortcut (and a desktop shortcut with -Desktop), and seeds your
# settings in %APPDATA%\TheCockPit without overwriting existing files.
[CmdletBinding()]
param([switch]$Desktop)
$ErrorActionPreference = 'Stop'
$Here = $PSScriptRoot
$Dest = Join-Path $env:LOCALAPPDATA 'Programs\TheCockPit'
$UserDir = Join-Path $env:APPDATA 'TheCockPit'

Write-Host "Installing The CockPit $(Get-Content (Join-Path $Here 'VERSION')) to $Dest"
if (Test-Path -LiteralPath $Dest) {
  foreach ($d in 'bin', 'config', 'docs', 'tools', 'assets', 'licenses', 'wezterm') {
    $p = Join-Path $Dest $d
    if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force }
  }
}
New-Item -ItemType Directory -Force -Path $Dest, $UserDir | Out-Null
foreach ($item in 'bin', 'config', 'docs', 'tools', 'assets', 'licenses', 'wezterm', 'LICENSE', 'README.md', 'CHANGELOG.md', 'THIRD_PARTY_NOTICES.md', 'VERSION', 'Start-TheCockPit.cmd', 'uninstall.ps1') {
  $src = Join-Path $Here $item
  if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination $Dest -Recurse -Force }
}
foreach ($f in 'connections.lua', 'agents.lua', 'python.lua', 'local.lua') {
  $target = Join-Path $UserDir $f
  if (-not (Test-Path -LiteralPath $target)) { Copy-Item -LiteralPath (Join-Path $Dest "config\examples\$f") -Destination $target }
}

$gui = Join-Path $Dest 'wezterm\wezterm-gui.exe'
if (-not (Test-Path -LiteralPath $gui)) { throw "Bundled WezTerm missing: $gui" }
$config = Join-Path $Dest 'config\cockpit.lua'
$icon = Join-Path $Dest 'assets\icons\the-cockpit.ico'
$arguments = "--config-file `"$config`" start --always-new-process --class the-cockpit"

function New-Shortcut([string]$Path) {
  $shell = New-Object -ComObject WScript.Shell
  $lnk = $shell.CreateShortcut($Path)
  $lnk.TargetPath = $gui
  $lnk.Arguments = $arguments
  $lnk.WorkingDirectory = $HOME
  $lnk.IconLocation = "$icon,0"
  $lnk.Description = 'The CockPit - emerald terminal cockpit built on WezTerm'
  $lnk.Save()
}
$startMenu = Join-Path ([Environment]::GetFolderPath('Programs')) 'The CockPit.lnk'
New-Shortcut $startMenu
if ($Desktop) { New-Shortcut (Join-Path ([Environment]::GetFolderPath('Desktop')) 'The CockPit.lnk') }

Write-Host ''
Write-Host 'Done. Open "The CockPit" from the Start menu.'
Write-Host "Your settings: $UserDir (SSH servers go in connections.lua)."
Write-Host 'Tip: install WSL (wsl --install) to get a Linux shell with fish inside The CockPit.'
