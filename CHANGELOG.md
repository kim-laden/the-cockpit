# Changelog

All notable changes to The CockPit are listed here. Versions follow semantic versioning.

## [1.1.0] — 2026-11-08

### Added
- **IPython workspace**: menu actions and `cockpit --ipython` / `cockpit-ipython` run
  `python -m IPython` in the interpreter you pick (system Python, project `.venv`/`venv`,
  or an optional CockPit learning venv). No silent fallback to another environment.
  If IPython is missing, you get clear install instructions — project envs are never
  modified automatically.
- **Intel Journal** (local Markdown, opt-in): notes, selection capture, case label,
  folder picker, and `cockpit-journal run -- …` for command logging. Dedicated
  **Intel: start capture session (new tab)** logs printed terminal output while ON;
  capture defaults to OFF. Passwords typed with no echo are not recorded. Journals
  stay under `~/Documents/TheCockPit/Intel` (configurable). Symlinked destinations
  refused. Warning: logged output may include secrets; cloud-synced folders sync them.
- Window title branding shows **The CockPit** (pane status when available).

### Fixed
- Capture sessions now call util-linux `script` correctly.
- Intel menu actions handle return values properly.
- Helper tools are found relative to the package, wherever it is installed.

### Notes
- Built on WezTerm (MIT) by Wez Furlong — unchanged as the terminal engine.
- Existing 1.0.0 features (Python REPL picker, optional AI tutor, explicit SSH,
  hardware overview, layouts) are preserved.
- Capture does not hook every shell or read history; WezTerm has no live per-pane
  output API, so capture uses a dedicated labelled tab.

## [1.0.0] — 2026-11-07

First public, open-source release. © 2026 Laden AS, released under the MIT License.

### Added
- Emerald CockPit theme, menu, fish default, Python learning, optional AI CLIs,
  explicit SSH, hardware overview, and multi-platform packages (see 1.0.0 notes).
