# Platform availability — 1.1.0

All packages: emerald/graphite theme, CockPit title and launch icon, local shell,
Python and project-environment picker, optional separately installed AI tutor.
IPython must already be installed in the chosen interpreter; no automatic install.
Linux/macOS: `cockpit --ipython PY` and the Bash helper. Windows: menu launches
`PY -m IPython` directly; CLI `cockpit.ps1 -IPython python` or `-IPython project`.

Intel local Markdown journal and dedicated opt-in capture tab are Linux-only.
They require Python 3.9+, util-linux script, procfs, and (for GUI dialogs) kdialog;
xdg-open opens notes. Capture defaults OFF, never records existing panes and never
uploads notes. Visible secrets can be logged; synced folders sync their contents.
Windows/macOS omit these Linux-only executable tools and Intel action items.
The Intel help page describes availability, not a promise of native capture.

Windows/macOS packages have not been executed on their target operating systems.
They remain unsigned/not notarized, as in 1.0.0. Bundled WezTerm remains the same
checksum-pinned upstream 20240203 engine, with its MIT attribution preserved.
On macOS the running Dock icon can remain WezTerm's engine icon.
