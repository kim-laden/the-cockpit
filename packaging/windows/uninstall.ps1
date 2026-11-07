# Remove The CockPit for the current user. Settings in %APPDATA%\TheCockPit are kept unless -Purge.
# (c) 2026 Laden AS, released under the MIT License.
[CmdletBinding()]
param([switch]$Purge)
$ErrorActionPreference = 'Stop'
$Dest = Join-Path $env:LOCALAPPDATA 'Programs\TheCockPit'
foreach ($lnk in (Join-Path ([Environment]::GetFolderPath('Programs')) 'The CockPit.lnk'),
                 (Join-Path ([Environment]::GetFolderPath('Desktop')) 'The CockPit.lnk')) {
  if (Test-Path -LiteralPath $lnk) { Remove-Item -LiteralPath $lnk -Force }
}
if (Test-Path -LiteralPath $Dest) { Remove-Item -LiteralPath $Dest -Recurse -Force }
if ($Purge) { Remove-Item -LiteralPath (Join-Path $env:APPDATA 'TheCockPit') -Recurse -Force -ErrorAction SilentlyContinue }
Write-Host 'The CockPit was removed.'
