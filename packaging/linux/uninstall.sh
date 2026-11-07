#!/usr/bin/env bash
# Remove The CockPit (keeps your settings in ~/.config/the-cockpit unless --purge).
# (c) 2026 Laden AS, released under the MIT License.
set -euo pipefail
PREFIX="${HOME}/.local"; PURGE="no"
while [ $# -gt 0 ]; do
  case "$1" in
    --prefix) PREFIX="${2:?}"; shift ;;
    --purge) PURGE="yes" ;;
    *) echo "uninstall.sh: unknown option $1" >&2; exit 2 ;;
  esac; shift
done
APP="$PREFIX/share/the-cockpit"
case "$APP" in */share/the-cockpit) ;; *) echo "refusing odd path $APP" >&2; exit 1 ;; esac
rm -rf -- "$APP"
if [ -L "$PREFIX/bin/cockpit" ]; then rm -f -- "$PREFIX/bin/cockpit"; fi
rm -f -- "$PREFIX/share/applications/the-cockpit.desktop"
for size in 48 128 256 512; do rm -f -- "$PREFIX/share/icons/hicolor/${size}x${size}/apps/the-cockpit.png"; done
if [ "$PURGE" = "yes" ]; then rm -rf -- "${XDG_CONFIG_HOME:-$HOME/.config}/the-cockpit"; fi
echo "The CockPit was removed.$([ "$PURGE" = yes ] || echo " Settings kept in ${XDG_CONFIG_HOME:-$HOME/.config}/the-cockpit.")"
