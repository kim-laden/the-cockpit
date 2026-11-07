# Third-party notices

The CockPit is © 2026 Laden AS and released under the MIT License (see `LICENSE`).
It is a configuration, launcher and packaging layer on top of WezTerm. The CockPit's
own source does not contain third-party code. The **downloadable packages** also
bundle the unmodified official WezTerm release listed below.

## WezTerm

- Project: https://wezterm.org/ · https://github.com/wez/wezterm
- Author: Wez Furlong
- License: MIT (full text: `licenses/WezTerm-LICENSE.md`)
- Version bundled: `20240203-110809-5046fc22` (latest stable release at the time of packaging)
- Official release assets used, unmodified, verified against the `.sha256` files
  published with the release:

| Asset | SHA-256 |
| --- | --- |
| `WezTerm-20240203-110809-5046fc22-Ubuntu20.04.AppImage` (Linux) | `34010a07076d2272c4d4f94b5e0dae608a679599e8d729446323f88f956c60f0` |
| `WezTerm-windows-20240203-110809-5046fc22.zip` (Windows) | `57e5d03b585303d81e8b8e96d1230362852eb39aca92b3b29c7a42cfb82f9ac4` |
| `WezTerm-macos-20240203-110809-5046fc22.zip` (macOS, universal) | `e77388cad55f2e9da95a220a89206a6c58f865874a629b7c3ea3c162f5692224` |

In the Windows package the debug symbol file `wezterm.pdb` is left out to save space;
every other file is as released. Source code for that exact version:
https://github.com/wez/wezterm/releases/tag/20240203-110809-5046fc22

### Fonts and libraries embedded in WezTerm

WezTerm embeds the JetBrains Mono, Noto Color Emoji and Roboto fonts under the
SIL Open Font License 1.1 (`licenses/WezTerm-fonts-LICENSE_OFL.txt`), and
Symbols Nerd Font Mono built from OFL-licensed Nerd Fonts icon sets
(`licenses/WezTerm-fonts-LICENSE_POWERLINE_EXTRA.txt` covers the Powerline Extra
symbols, MIT, © Ryan L McIntyre). WezTerm's binaries also include Rust crates and,
on Linux and Windows, shared libraries under their own permissive licenses; see
the WezTerm repository for the complete list.

## Optional tools you install yourself

fish, Python, OpenSSH, WSL and any AI command-line tools (Grok, Claude Code, Codex,
Cursor Agent, Gemini, ...) are **not** bundled. The CockPit only detects them and
starts them when you choose them; each is covered by its own license and terms.
