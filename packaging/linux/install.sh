#!/usr/bin/env bash
# Install The CockPit for the current user (no root needed).
# (c) 2026 Laden AS, released under the MIT License.
#
#   ./install.sh                 install into ~/.local/share/the-cockpit
#   ./install.sh --bundled       always unpack the bundled WezTerm, even if one is installed
#   ./install.sh --no-bundled    never unpack it (you install WezTerm yourself)
#   ./install.sh --prefix DIR    install somewhere else (default: ~/.local)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${HOME}/.local"
BUNDLED="auto"
while [ $# -gt 0 ]; do
  case "$1" in
    --bundled) BUNDLED="yes" ;;
    --no-bundled) BUNDLED="no" ;;
    --prefix) PREFIX="${2:?--prefix needs a directory}"; shift ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "install.sh: unknown option $1" >&2; exit 2 ;;
  esac
  shift
done

APP="$PREFIX/share/the-cockpit"
BIN="$PREFIX/bin"
APPS="$PREFIX/share/applications"
ICONS="$PREFIX/share/icons/hicolor"
USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/the-cockpit"

echo "Installing The CockPit $(cat "$HERE/VERSION") into $APP"
mkdir -p "$APP" "$BIN" "$APPS" "$USER_DIR"
# Replace app files but never the user's settings.
rm -rf "${APP:?}/bin" "${APP:?}/config" "${APP:?}/docs" "${APP:?}/tools" "${APP:?}/assets"
cp -R "$HERE/bin" "$HERE/config" "$HERE/docs" "$HERE/tools" "$HERE/assets" "$APP/"
rm -rf "${APP:?}/licenses"; cp -R "$HERE/licenses" "$APP/"
cp "$HERE/LICENSE" "$HERE/README.md" "$HERE/CHANGELOG.md" "$HERE/THIRD_PARTY_NOTICES.md" "$HERE/VERSION" "$APP/"
chmod +x "$APP/bin/cockpit" "$APP/tools/cockpit-hardware.py"

appimage="$(find "$HERE/wezterm" -maxdepth 1 -name 'WezTerm-*.AppImage' 2>/dev/null | head -n 1 || true)"
want_bundled="no"
if [ "$BUNDLED" = "yes" ]; then want_bundled="yes"
elif [ "$BUNDLED" = "auto" ] && ! command -v wezterm >/dev/null 2>&1; then want_bundled="yes"; fi
if [ "$want_bundled" = "yes" ]; then
  if [ -z "$appimage" ]; then
    echo "No bundled WezTerm in this package; install it from https://wezterm.org/install/linux.html" >&2
  else
    echo "Unpacking the bundled WezTerm (no FUSE needed)..."
    tmp="$(mktemp -d)"
    cp "$appimage" "$tmp/wezterm.AppImage" && chmod +x "$tmp/wezterm.AppImage"
    (cd "$tmp" && ./wezterm.AppImage --appimage-extract >/dev/null)
    rm -rf "${APP:?}/wezterm" && mv "$tmp/squashfs-root" "$APP/wezterm" && rm -rf "$tmp"
    "$APP/wezterm/usr/bin/wezterm" --version
  fi
else
  echo "Using the WezTerm already on this system: $(command -v wezterm || echo 'not found')"
fi

ln -sf "$APP/bin/cockpit" "$BIN/cockpit"
for size in 48 128 256 512; do
  mkdir -p "$ICONS/${size}x${size}/apps"
  cp "$HERE/assets/icons/the-cockpit-$size.png" "$ICONS/${size}x${size}/apps/the-cockpit.png"
done
sed "s|@EXEC@|$APP/bin/cockpit|g" "$HERE/packaging/linux/the-cockpit.desktop" > "$APPS/the-cockpit.desktop"
chmod 644 "$APPS/the-cockpit.desktop"

for f in connections.lua agents.lua python.lua local.lua; do
  [ -e "$USER_DIR/$f" ] || cp "$HERE/config/examples/$f" "$USER_DIR/$f"
done

command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APPS" >/dev/null 2>&1 || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q -t "$ICONS" >/dev/null 2>&1 || true

echo
echo "Done. Start it from your app menu (The CockPit) or run: $BIN/cockpit"
case ":$PATH:" in *":$BIN:"*) ;; *) echo "Tip: add $BIN to your PATH to type just 'cockpit'." ;; esac
command -v fish >/dev/null 2>&1 || echo "Tip: install fish for the default CockPit shell (otherwise your login shell is used)."
echo "Your settings: $USER_DIR (SSH servers go in connections.lua)."
