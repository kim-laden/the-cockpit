#!/bin/sh
# Static checks for The CockPit. (c) 2026 Laden AS, MIT License.
set -eu
cd "$(dirname "$0")/.."
echo "== shellcheck"
shellcheck -x bin/cockpit packaging/linux/install.sh packaging/linux/uninstall.sh packaging/macos/cockpit-launcher scripts/check.sh
echo "== unit tests"
python3 -m unittest discover -s tests -q
echo "== WezTerm parses the config (temp HOME, no GUI)"
WEZ="${COCKPIT_WEZTERM:-$(command -v wezterm || true)}"
if [ -n "$WEZ" ]; then
  tmp="$(mktemp -d)"
  HOME="$tmp" XDG_CONFIG_HOME="$tmp/.config" XDG_RUNTIME_DIR="$tmp" \
    "$WEZ" --config-file config/cockpit.lua show-keys > "$tmp/keys.txt" 2> "$tmp/err.txt"
  if grep -q 'The CockPit' "$tmp/keys.txt" && ! grep -qi 'error' "$tmp/err.txt"; then
    echo "config OK ($("$WEZ" --version))"
  else
    cat "$tmp/err.txt"; exit 1
  fi
  rm -rf "$tmp"
else
  echo "skipped: no wezterm (set COCKPIT_WEZTERM)"
fi
