@echo off
rem The CockPit portable launcher. (c) 2026 Laden AS, MIT License.
start "" "%~dp0wezterm\wezterm-gui.exe" --config-file "%~dp0config\cockpit.lua" start --always-new-process --class the-cockpit --cwd "%USERPROFILE%"
