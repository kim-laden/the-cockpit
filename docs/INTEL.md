> **Platform: Linux only.** Not available natively in the Windows/macOS packages. See PLATFORMS.md.

# The CockPit Intel Journal

Local Markdown notes for findings while you work. **Capture is OFF until you turn it on.**

## Warning
Logged terminal output can include secrets (tokens, keys, passwords you paste or that print on screen). Typed passwords that never echo are not recorded. If the journal folder is inside Dropbox/cloud sync, notes leave the machine. There is **no** automatic redaction.

## Default folder
`~/Documents/TheCockPit/Intel` — daily files like `2026-11-08-intel.md` (optional case label in the name).

## Menu (F12 / right-click in CockPit)
- **Intel: start capture session (new tab)** — opens a labelled tab; everything *printed* there is appended live to today’s journal. Exit the shell or use **Intel: stop capture** to end.
- **Intel: stop capture**
- **Intel: status**
- **Intel: quick note**
- **Intel: save selection → journal** (selected text only; never whole scrollback)
- **Intel: set folder (picker)** / **Intel: set case label**
- **Intel: open today’s journal** / **Intel: open folder**

Limitation: WezTerm has no supported live “on-output” hook for an arbitrary existing pane. Capture is a **dedicated tab**, not a silent hook on btop/fish panes you already have open.

## CLI
```bash
cockpit-journal status
cockpit-journal set-folder --gui
cockpit-journal set-case pentest-lab
cockpit-journal note -t recon "host responds on 443"
cockpit-journal run -- nmap -sV 10.0.0.0/32     # example only; you choose the command
cockpit-journal capture                          # interactive capture shell
cockpit-journal stop
cockpit-journal open
```

`run` streams stdout/stderr to your terminal and appends argv, cwd, exit code, and output. Exit code is preserved.
- Symlinked journal folders/files are refused.
