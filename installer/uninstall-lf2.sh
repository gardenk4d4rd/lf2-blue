#!/usr/bin/env bash
#
# LF2 Blue — GNOME theme uninstaller (full rollback to stock Ubuntu)
#
# Copyright 2026 gardenk4d4rd
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# Restores the prior GTK3/GTK4 and GNOME Shell state that was backed up by
# install-lf2.sh (CSS files AND gsettings values), removes the lf2-blue theme
# dir and any empty gtk config dirs, and removes its own config dir. If no
# backup exists it removes the LF2 files and resets the related gsettings to
# Ubuntu's stock defaults (icon-theme, color-scheme, and any User Themes
# extension setting we enabled).
#
# Usage:  ./uninstall-lf2.sh [--theme-dir PATH] [--no-color-scheme] [--yes]

set -euo pipefail

THEME_NAME="lf2-blue"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_DIR="${SCRIPT_DIR}/themes/${THEME_NAME}"
RESET_COLOR_SCHEME=1
ASSUME_YES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --theme-dir) THEME_DIR="$2"; shift 2 ;;
    --no-color-scheme) RESET_COLOR_SCHEME=0; shift ;;
    --yes) ASSUME_YES=1; shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

BACKUP_DIR="${HOME}/.config/lf2-blue/backups"
GTK4_DIR="${HOME}/.config/gtk-4.0"
GTK3_DIR="${HOME}/.config/gtk-3.0"
SHELL_THEME_DIR="${HOME}/.local/share/themes/${THEME_NAME}"

info()  { printf '\033[1;34m[LF2 Blue]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[LF2 Blue]\033[0m %s\n' "$*" >&2; }

if [[ $EUID -eq 0 ]]; then
  printf '\033[1;31m[LF2 Blue]\033[0m Refusing to run as root.\n' >&2
  exit 1
fi

if (( ASSUME_YES != 1 )); then
  read -rp "Uninstall LF2 Blue theme and restore previous state? [y/N] " ans
  [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]] || { info "Cancelled."; exit 0; }
fi

# Find the most recent backup (best restore candidate)
LATEST="$(ls -1t "$BACKUP_DIR" 2>/dev/null | head -n1 || true)"
RESTORE_DIR=""
if [[ -n "$LATEST" && -d "$BACKUP_DIR/$LATEST" ]]; then
  RESTORE_DIR="$BACKUP_DIR/$LATEST"
fi

restore_or_remove() {
  local backed="$1" target="$2"
  if [[ -n "$RESTORE_DIR" && -f "$RESTORE_DIR/$backed" ]]; then
    mkdir -p "$(dirname "$target")"
    cp -f "$RESTORE_DIR/$backed" "$target"
    info "Restored $target from backup."
  else
    rm -f "$target"
    info "Removed $target (no backup available)."
  fi
}

restore_or_remove "gtk-4.0-gtk.css" "${GTK4_DIR}/gtk.css"
restore_or_remove "gtk-3.0-gtk.css" "${GTK3_DIR}/gtk.css"

# The lf2-blue theme dir (with gnome-shell + gtk-3.0/gtk-4.0 css + index.theme)
# is created entirely by the installer, so it is removed wholesale below.

# Remove the lf2-blue theme dir entirely (it is entirely ours)
if [[ -d "$SHELL_THEME_DIR" ]]; then
  rm -rf "$SHELL_THEME_DIR"
  info "Removed shell theme dir: ${SHELL_THEME_DIR}"
fi

# Restore gsettings. Prefer the exact values backed up by install-lf2.sh;
# if no backup exists, reset to Ubuntu stock defaults.
if command -v gsettings >/dev/null 2>&1; then
  SETTINGS_BACKUP=""
  if [[ -n "$RESTORE_DIR" ]]; then
    SETTINGS_BACKUP="$RESTORE_DIR/settings.conf"
  fi

  if [[ -n "$SETTINGS_BACKUP" && -f "$SETTINGS_BACKUP" && -s "$SETTINGS_BACKUP" ]]; then
    while IFS=$'\t' read -r key val; do
      [[ -z "$key" || -z "$val" ]] && continue
      if [[ "$val" == "UNSET" ]]; then
        gsettings reset "$key" 2>/dev/null \
          && info "Reset $key to stock." \
          || warn "Could not reset $key."
      else
        gsettings set "$key" "$val" 2>/dev/null \
          && info "Restored $key." \
          || warn "Could not restore $key."
      fi
    done < "$SETTINGS_BACKUP"
  else
    # No backup: reset the keys we touch back to Ubuntu's stock defaults.
    gsettings reset org.gnome.desktop.interface icon-theme 2>/dev/null \
      && info "icon-theme reset to stock." \
      || warn "Could not reset icon-theme."
    gsettings reset org.gnome.shell.extensions.user-theme name 2>/dev/null \
      && info "user-theme name reset to stock." \
      || warn "Could not reset user-theme name."

    if (( RESET_COLOR_SCHEME == 1 )); then
      gsettings reset org.gnome.desktop.interface color-scheme 2>/dev/null \
        && info "color-scheme reset to stock." \
        || warn "Could not reset color-scheme."
    fi

    # Remove the User Themes extension we enabled (if present).
    USER_THEME_ID="user-theme@gnome-shell-extensions.gcampax.github.com"
    CUR="$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null || true)"
    if [[ "$CUR" == *"$USER_THEME_ID"* ]]; then
      NEW="$(printf '%s' "$CUR" | sed "s/[, ]*'${USER_THEME_ID}'//")"
      gsettings set org.gnome.shell enabled-extensions "$NEW" 2>/dev/null \
        && info "Removed User Themes extension from enabled list." \
        || warn "Could not update enabled-extensions."
    fi
  fi
fi

# Remove empty gtk config dirs left behind (stock Ubuntu has none).
for d in "$GTK4_DIR" "$GTK3_DIR"; do
  if [[ -d "$d" ]] && [[ -z "$(ls -A "$d" 2>/dev/null)" ]]; then
    rmdir "$d" 2>/dev/null && info "Removed empty dir: ${d}"
  fi
done

# Remove our config dir (backups no longer needed after a successful restore).
if [[ -d "${HOME}/.config/lf2-blue" ]]; then
  rm -rf "${HOME}/.config/lf2-blue"
  info "Removed ${HOME}/.config/lf2-blue"
fi

cat <<EOF

$(info "LF2 Blue uninstalled.")

To fully revert open apps / shell, log out and back in.
EOF
