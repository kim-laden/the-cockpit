# The CockPit guide

The CockPit is a local-first, emerald terminal cockpit built on WezTerm.
Nothing connects, signs in, uploads or starts a task by itself.

## Keys and mouse
- Right-click, F12 or Ctrl+Alt+Space: the CockPit menu (type to filter).
  Inside apps that use the mouse (vim, htop), hold Shift while right-clicking.
- Ctrl+Shift+D / E: split top-bottom / side by side
- Ctrl+Shift+T / N: new tab / new window
- Ctrl+Shift+W: close the pane (asks first)
- Ctrl+Shift+arrows: move between panes
- Ctrl+Shift+P: all profiles (shells, WSL, SSH)
- Ctrl+Shift+left-drag: move the frameless window
  (menu -> "Window: native title bar toggle" brings back the title bar)

## Shell
fish is used when it is installed. Otherwise your login shell on Linux/macOS,
or PowerShell on Windows (WSL, Windows PowerShell and Command Prompt are in the
profiles). Pick another default with `shell = { ... }` in `local.lua`.

## Your settings
Kept outside the app, so updates never overwrite them:
- Linux/macOS: `~/.config/the-cockpit/`
- Windows: `%APPDATA%\TheCockPit\`

| File | What it is for |
| --- | --- |
| `connections.lua` | your SSH servers (explicit connect only) |
| `agents.lua` | extra AI/CLI tools for the menu |
| `python.lua` | extra Python interpreters |
| `local.lua` | any WezTerm setting: font size, opacity, title bar, Wayland |

Each file can be opened from the menu. "Settings: reload configuration" applies changes.

## SSH
Add servers to `connections.lua`. Agent and X11 forwarding stay off and new host
keys must be confirmed. No keys, tokens or passwords belong in the file; use your
SSH agent, keys or password when you connect, and check a new server's
fingerprint through another channel first.

## Python and learning
The menu lists the Python interpreters it finds, can start the `.venv`/`venv` of
the folder you are in, and has a quick-start sheet for common syntax errors. If
you have an AI command-line tool installed and logged in, "Learning: Python +
<tool> tutor" opens Python and the tool side by side. Copy what you want to ask;
nothing is sent for you.

## Hardware overview
"System: local hardware and driver overview" (or `cockpit --hardware`) prints a
read-only summary. See HARDWARE.md.
