#!/usr/bin/env bash
#
# LF2 Blue — GNOME theme installer (standalone, no Rewaita required)
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
# Theme CSS is derived from Rewaita (GPL-3.0-or-later) by Nathan Perlman:
# https://github.com/SwordPuffin/Rewaita
#
# Applies the LF2 Blue theme to GTK3, GTK4/libadwaita apps, and GNOME Shell.
# Works by writing the theme CSS to the standard per-user locations that
# GTK and GNOME Shell auto-load. No background daemon needed.
#
# Safe to re-run: idempotent, and always backs up the previous state first
# so uninstall-lf2.sh can fully restore it.
#
# Usage:  ./install-lf2.sh [--theme-dir PATH] [--no-color-scheme] [--icon-theme NAME] [--no-icon-theme] [--yes]
#
#   --theme-dir PATH     Where the bundled lf2-blue CSS lives. Defaults to the
#                        directory of this script.
#   --no-color-scheme    Do not change 'color-scheme' to prefer-dark.
#   --icon-theme NAME    Use NAME as the icon theme (e.g. --icon-theme Yaru-blue-dark).
#                        Default is Adwaita (fits LF2 Blue; overrides Ubuntu's orange Yaru).
#   --no-icon-theme      Do not change the icon theme at all.
#   --yes                Skip confirmation prompt.

set -euo pipefail

THEME_NAME="lf2-blue"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_DIR="${SCRIPT_DIR}/themes/${THEME_NAME}"
SET_COLOR_SCHEME=1
ASSUME_YES=0
SET_ICON_THEME=1
ICON_THEME="Adwaita"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --theme-dir) THEME_DIR="$2"; shift 2 ;;
    --no-color-scheme) SET_COLOR_SCHEME=0; shift ;;
    --icon-theme) SET_ICON_THEME=1; ICON_THEME="$2"; shift 2 ;;
    --no-icon-theme) SET_ICON_THEME=0; shift ;;
    --yes) ASSUME_YES=1; shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

GTK4_CSS="${THEME_DIR}/gtk-4.0/gtk.css"
GTK3_CSS="${THEME_DIR}/gtk-3.0/gtk.css"
SHELL_CSS="${THEME_DIR}/gnome-shell/gnome-shell.css"

# ---- helpers -------------------------------------------------------------

info()  { printf '\033[1;34m[LF2 Blue]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[LF2 Blue]\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[1;31m[LF2 Blue]\033[0m %s\n' "$*" >&2; exit 1; }

backup() {
  local src="$1" dest="$2"
  if [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dest")"
    cp -f "$src" "$dest"
  fi
}

# ---- decoration ------------------------------------------------------------

# LF2 Blue palette (ANSI 24-bit)
C_VOID='\033[38;2;8;15;20m'
C_NAVY='\033[38;2;26;43;106m'
C_FRAME='\033[38;2;35;124;255m'
C_SLATE='\033[38;2;74;92;138m'
C_WHITE='\033[38;2;239;240;255m'
C_ROYAL='\033[38;2;59;78;209m'
C_RESET='\033[0m'

# LF2 Blue ASCII logo (Frame Blue)
LOGO=(
'# ::::::::::::::::::::::::::::::::::::::::::'
'# ::::::::::::::::::::::::::::::::::::::::::'
'# ::    _________        __    __         ::'
'# ::   / / __/__ \      / /_  / /_  _____ ::'
'# ::  / / /_ __/ /     / __ \/ / / / / _ \::'
'# :: / / __// __/     / /_/ / / /_/ /  __/::'
'# ::/_/_/  /____/    /_.___/_/\__,_/\___/ ::'
'# ::                                      ::'
'# ::::::::::::::::::::::::::::::::::::::::::'
'# ::::::::::::::::::::::::::::::::::::::::::'
)

BANNER_W=64
BAR=$(printf '━%.0s' $(seq 1 $BANNER_W))

print_banner() {
  clear
  printf "\n"
  for line in "${LOGO[@]}"; do
    printf "  ${C_FRAME}%s${C_RESET}\n" "$line"
  done
  printf "\n"
  printf "${C_FRAME}%s${C_RESET}\n" "$BAR"
  printf "  ${C_VOID}██${C_RESET} Void   ${C_NAVY}██${C_RESET} Navy   ${C_FRAME}██${C_RESET} Frame   ${C_SLATE}██${C_RESET} Slate   ${C_WHITE}██${C_RESET} White   ${C_ROYAL}██${C_RESET} Royal\n"
  printf "${C_FRAME}%s${C_RESET}\n" "$BAR"
}

# Palette sentences, shown across the install steps
SENTENCES=(
  "Void Black fills every window and content surface."
  "Deep Navy coats headerbars, cards, and popovers."
  "Frame Blue traces borders, tabs, and accents."
  "Slate Blue draws separators, scrollbar rests, and hover states."
  "Off-White lights every label, title, and icon."
  "Royal Blue marks the fallback accent."
)

SENT_IDX=0
next_sentence() {
  local msg="${SENTENCES[$SENT_IDX]:-}"
  if [[ -n "$msg" ]]; then
    printf "  ${C_FRAME}▸${C_RESET} %s\n" "$msg"
    SENT_IDX=$(( SENT_IDX + 1 ))
  fi
}

# ---- pre-flight ----------------------------------------------------------

[[ $EUID -eq 0 ]] && die "Refusing to run as root. The theme installs per-user."

for f in "$GTK4_CSS" "$GTK3_CSS" "$SHELL_CSS"; do
  [[ -f "$f" ]] || die "Missing theme file: $f"
done

GTK4_DIR="${HOME}/.config/gtk-4.0"
GTK3_DIR="${HOME}/.config/gtk-3.0"
SHELL_THEME_DIR="${HOME}/.local/share/themes/${THEME_NAME}/gnome-shell"
BACKUP_DIR="${HOME}/.config/lf2-blue/backups"
STAMP="$(date +%Y%m%d_%H%M%S)"

print_banner
printf "\n"
info "Installing LF2 Blue theme for user: $(whoami)"

if (( ASSUME_YES != 1 )); then
  read -rp "Proceed? Existing gtk3/gtk4 css and lf2-blue shell theme will be backed up. [y/N] " ans
  [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]] || die "Cancelled."
fi

# ---- 1. backup current state --------------------------------------------

mkdir -p "${BACKUP_DIR}/${STAMP}"

backup "${GTK4_DIR}/gtk.css"      "${BACKUP_DIR}/${STAMP}/gtk-4.0-gtk.css"
backup "${GTK3_DIR}/gtk.css"      "${BACKUP_DIR}/${STAMP}/gtk-3.0-gtk.css"
backup "${SHELL_THEME_DIR}/gnome-shell.css" "${BACKUP_DIR}/${STAMP}/shell-gnome-shell.css"

# Snapshot the gsettings keys we may change, so uninstall can restore the
# exact previous values (not just a generic reset). Format: key<TAB>value.
SETTINGS_BACKUP="${BACKUP_DIR}/${STAMP}/settings.conf"
: > "$SETTINGS_BACKUP"
if command -v gsettings >/dev/null 2>&1; then
  for key in \
    "org.gnome.desktop.interface color-scheme" \
    "org.gnome.desktop.interface icon-theme" \
    "org.gnome.shell.extensions.user-theme name" \
    "org.gnome.shell enabled-extensions"; do
    val="$(gsettings get $key 2>/dev/null || true)"
    if [[ -n "$val" ]]; then
      printf '%s\t%s\n' "$key" "$val" >> "$SETTINGS_BACKUP"
    else
      printf '%s\tUNSET\n' "$key" >> "$SETTINGS_BACKUP"
    fi
  done
fi

# If a prior LF2 Blue backup exists and we have none fresh, keep the newest
# non-LF2 state so uninstall can still restore it. (Nothing to do here: the
# backup above captures whatever was in place before this run.)

info "Backed up previous state to: ${BACKUP_DIR}/${STAMP}"
next_sentence

# ---- 2. install GTK css --------------------------------------------------
next_sentence

mkdir -p "$GTK4_DIR" "$GTK3_DIR"
# Follow Rewaita's mechanism: write the theme css to the per-user auto-loaded
# gtk.css (gtk-4.0 and gtk-3.0). GTK loads it on top of the Adwaita base for
# every app, including libadwaita (Nautilus, Settings). Same as Rewaita.
cp -f "$GTK4_CSS" "${GTK4_DIR}/gtk.css"
cp -f "$GTK3_CSS" "${GTK3_DIR}/gtk.css"
info "Installed GTK css (gtk-4.0 and gtk-3.0)."

# ---- 3. install GNOME Shell theme ---------------------------------------
next_sentence

mkdir -p "$SHELL_THEME_DIR"
cp -f "$SHELL_CSS" "${SHELL_THEME_DIR}/gnome-shell.css"

# Write the shell theme's index.theme. This directory is for the GNOME Shell
# theme ONLY. We deliberately do NOT install gtk-3.0/gtk-4.0 css here: our css
# is a partial override sheet meant to layer on top of the Adwaita base via
# ~/.config/gtk-4.0/gtk.css (USER priority, which libadwaita apps respect).
# A partial css used as a *base* theme (e.g. by setting gtk-theme) leaves
# Nautilus/Settings mostly unstyled.
cat > "${HOME}/.local/share/themes/${THEME_NAME}/index.theme" <<EOF
[Desktop Entry]
Type=X-GNOME-Metatheme
Name=LF2 Blue
Comment=LF2 Blue GNOME Shell theme (Void/Deep Navy/Frame/Slate palette)
Encoding=UTF-8

[GNOME Shell]
Name=LF2 Blue
EOF

info "Installed GNOME Shell theme: ${THEME_NAME}"

# ---- 4. ensure user-theme extension is enabled --------------------------
next_sentence

USER_THEME_ID="user-theme@gnome-shell-extensions.gcampax.github.com"
ENABLED_EXT="$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null || true)"

if [[ "$ENABLED_EXT" == *"$USER_THEME_ID"* ]]; then
  info "User Themes extension already enabled."
else
  if command -v gsettings >/dev/null 2>&1; then
    if [[ -z "$ENABLED_EXT" || "$ENABLED_EXT" == "@as []" || "$ENABLED_EXT" == "[]" ]]; then
      gsettings set org.gnome.shell enabled-extensions "['${USER_THEME_ID}']" 2>/dev/null \
        && info "Enabled User Themes extension." \
        || warn "Could not enable User Themes extension (may need it installed)."
    else
      # append to existing list via dconf is tricky in pure gsettings; try python-free approach
      NEW="$(printf '%s' "$ENABLED_EXT" | sed "s/\]/,\\'${USER_THEME_ID}\\']/")"
      gsettings set org.gnome.shell enabled-extensions "$NEW" 2>/dev/null \
        && info "Enabled User Themes extension." \
        || warn "Could not enable User Themes extension (may need it installed)."
    fi
  else
    warn "gsettings not found; enable 'User Themes' via Extensions app after login."
  fi
fi

# ---- 5. apply gsettings --------------------------------------------------
next_sentence

if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.shell.extensions.user-theme name "$THEME_NAME" 2>/dev/null \
    && info "GNOME Shell user theme set to '${THEME_NAME}'." \
    || warn "Could not set user-theme name (User Themes extension may be absent)."

  # NOTE: we intentionally DO NOT set org.gnome.desktop.interface gtk-theme.
  # Setting it to lf2-blue makes libadwaita apps (Nautilus, Settings) treat our
  # partial gtk.css as their base stylesheet instead of Adwaita, leaving them
  # mostly unstyled. The per-user ~/.config/gtk-4.0/gtk.css on top of the
  # Adwaita base is the mechanism that works (same as Rewaita).

  if (( SET_COLOR_SCHEME == 1 )); then
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null \
      && info "color-scheme set to 'prefer-dark'." \
      || warn "Could not set color-scheme."
  fi

  if (( SET_ICON_THEME == 1 )); then
    gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME" 2>/dev/null \
      && info "icon-theme set to '${ICON_THEME}'." \
      || warn "Could not set icon-theme '${ICON_THEME}' (not installed?)."
  fi
else
  warn "gsettings not found; apply shell theme + color-scheme manually after login."
fi

# ---- 6. done -------------------------------------------------------------

next_sentence

printf "\n"
printf "${C_FRAME}%s${C_RESET}\n" "$BAR"
printf "  ${C_WHITE}LF2 Blue${C_RESET} installed successfully.\n\n"
printf "  To fully apply:\n"
printf "    - Log out and back in (Wayland has no Alt+F2 'r' reload), OR\n"
printf "    - Restart any apps that are currently open (new apps pick it up automatically).\n\n"
printf "  To roll back later, run:  ${C_FRAME}./uninstall-lf2.sh${C_RESET}\n"
printf "${C_FRAME}%s${C_RESET}\n" "$BAR"
printf "\n"
