# Changelog

All notable changes to The CockPit are listed here. Versions follow semantic versioning.

## [1.0.0] — 2026-11-07

First public, open-source release. © 2026 Laden AS, released under the MIT License.

### Added
- Emerald CockPit theme for WezTerm: green-on-black palette, frameless window with
  resize borders, JetBrains Mono, subtle transparency.
- CockPit menu on right-click, F12 or Ctrl+Alt+Space: tabs, splits, three ready-made
  layouts, pane navigation and resizing, clipboard, scrollback search, font size,
  transparency, title bar, window size, fullscreen.
- fish as the default shell when installed; falls back to your login shell on
  Linux/macOS and to PowerShell on Windows, with WSL, Windows PowerShell and
  Command Prompt profiles.
- Python learning: interpreter discovery, one-click REPLs, project `.venv`/`venv`
  launcher, a quick-start cheatsheet for common syntax errors, and a tutor prompt
  template.
- Optional AI CLI discovery (Grok, Claude Code, Codex, Cursor Agent, Gemini, plus
  your own profiles). Nothing is installed, signed in or sent automatically; a
  "Python + AI tutor side by side" layout appears when a tool is installed.
- Explicit-only SSH connections from a user-editable `connections.lua` example
  (agent and X11 forwarding off, host key confirmation on).
- `cockpit-hardware`: a read-only, privacy-filtered hardware and driver overview
  for Linux, macOS and Windows.
- Packages: Linux `.tar.gz` (user installer), AppImage and `.deb`; Windows `.zip`
  (installer script and portable launcher); macOS `.zip` with `The CockPit.app`.
  The `.tar.gz`, AppImage, Windows and macOS packages bundle the official WezTerm
  20240203-110809-5046fc22 release.
