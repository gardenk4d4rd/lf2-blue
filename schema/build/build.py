#!/usr/bin/env python3
"""Rebuild LF2 Blue theme artifacts from canonical sources.

Copyright 2026 gardenk4d4rd — GPL-3.0-or-later (see ../../LICENSE)

SOURCE OF TRUTH pipeline. Mirrors Rewaita's exact build logic
(src/window.py:on_theme_selected + src/utils.py:parse_gtk_theme/get_accent_color).

Theme CSS is derived from Rewaita (GPL-3.0-or-later) by Nathan Perlman:
https://github.com/SwordPuffin/Rewaita

Inputs (canonical, in ../sources/):
  lf2-blue-theme.css        - arish's LF2 v0.3 theme file (Rawait 'data/dark/lf2 v0.3.css')
  rewaita-gtk3-template.css - Rewaita src/themes/gtk3-template/gtk.css
  rewaita-shell-template.css- Rewaita src/themes/gnome-shell-template.css
  rewaita-css_templates.py  - Rewaita src/themes/css_templates.py (for accent_tab_css_gs)
  rewaita-prefs.json        - arish's Rewaita preferences (schema inputs)

Outputs (the delivered theme, byte-identical to what Rewaita generates):
  gtk-4.0/gtk.css           - Rewaita GTK4 mechanism (theme variables + extras)
  gtk-3.0/gtk.css           - gtk3-template with palette substituted
  gnome-shell/gnome-shell.css - shell template + accent-tabs shell block

Usage:
  python3 build.py [OUTDIR]
  OUTDIR defaults to ../out
"""
import json
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "sources")
OUT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "out"))

THEME_CSS = os.path.join(SRC, "lf2-blue-theme.css")
GTK3_TPL = os.path.join(SRC, "rewaita-gtk3-template.css")
SHELL_TPL = os.path.join(SRC, "rewaita-shell-template.css")
CSS_TPLS = os.path.join(SRC, "rewaita-css_templates.py")
PREFS = os.path.join(SRC, "rewaita-prefs.json")


def load_css_templates_module():
    """Import Rewaita css_templates.py to get accent_tab_css_gs (accent-tabs)."""
    import importlib.util
    spec = importlib.util.spec_from_file_location("rewaita_css_templates", CSS_TPLS)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    css_templates = load_css_templates_module()
    accent_tab_css_gs = css_templates.accent_tab_css_gs

    with open(PREFS) as f:
        P = json.load(f)

    # ---- read theme + templates ----
    with open(THEME_CSS) as f:
        gtk_css = f.read()
    # Strip leading CSS comment header (attribution lives in the source file,
    # not in the shipped artifacts, keeping the on-disk gtk.css pure CSS).
    gtk_css = re.sub(r"^/\*.*?\*/\s*", "", gtk_css, flags=re.S)
    with open(GTK3_TPL) as f:
        gtk3 = f.read()
    with open(SHELL_TPL) as f:
        shell = f.read()

    # ---- parse theme :root variables (Rewaita window.py color_pattern) ----
    pattern = r'--([a-z0-9-]+)\s*:\s*(#[a-fA-F0-9]+|[a-z0-9_-]+(?:\([^)]*\))?)\s*;'
    refs = {}
    colors = {}
    for m in re.finditer(pattern, gtk_css):
        name, value = m.groups()
        if value.startswith('@'):
            refs.setdefault(value[1:], []).append(name)
        else:
            colors[name] = value
    for ref, deps in refs.items():
        if ref in colors:
            for n in deps:
                colors[n] = colors[ref]

    # ---- accent (get_accent_color; accent map, accent-fg pref) ----
    accent_map = {
        "'blue'": "blue-1", "'teal'": "blue-2", "'green'": "green-1",
        "'yellow'": "yellow-1", "'orange'": "orange-1", "'red'": "red-1",
        "'pink'": "purple-1", "'purple'": "purple-2", "'slate'": "dark-1",
    }
    accent_color = colors[accent_map[P.get("accent", "'blue'")]]
    accent_fg = "#EEEEEE" if P.get("accent-fg", False) else "#222222"
    colors["accent-color"] = accent_color
    colors["accent-fg-color"] = accent_fg

    # ---- parse_gtk_theme derivations ----
    border_color = colors["accent-color"] if P.get("window", False) else "transparent"
    colors["border-color"] = border_color
    colors["overview-bg-color"] = colors["window-bg-color"]
    colors["panel-bg-color"] = colors["window-bg-color"]
    colors["panel-fg-color"] = colors["window-fg-color"]
    rgb = tuple(int(colors["accent-color"][i:i + 2], 16) for i in (1, 3, 5))
    colors["accent-transparent"] = f"rgba({rgb[0]}, {rgb[1]}, {rgb[2]}, 0.5)"
    colors["search-fg-color"] = "white" if P.get("light-text", False) else colors["window-fg-color"]

    # ---- GTK3: substitute every theme-dict token into the template ----
    for k in colors.keys():
        gtk3 = gtk3.replace(f"@{k}", colors[k])

    # ---- Shell: substitute items_to_replace ----
    items = ["window-bg-color", "window-fg-color", "card-bg-color", "headerbar-bg-color",
             "accent-color", "border-color", "red-1", "panel-bg-color", "panel-fg-color",
             "overview-bg-color", "search-fg-color", "accent-transparent", "accent-fg-color"]
    for it in items:
        shell = shell.replace(f"@{it}", colors[it])
    if P.get("accent-tabs", False):
        shell += accent_tab_css_gs
    # arish's installed Rewaita also resolves accent tokens in the appended block
    shell = shell.replace("@accent-color", colors["accent-color"])
    shell = shell.replace("@accent-fg-color", colors["accent-fg-color"])

    # ---- GTK4: raw theme + accent-tabs block + accent defines ----
    accent_tab_css_gtk4 = """
*:selected {
    color: var(--accent-bg-color);
}

*:checked:not(expander) {
    color: var(--accent-fg-color);
    background-color: var(--accent-bg-color);
}
"""
    gtk4_extras = "\n" + (accent_tab_css_gtk4 if P.get("accent-tabs", False) else "")
    gtk4_extras += f"\n@define-color accent_bg_color {accent_color};\n@define-color accent_fg_color {accent_fg};"
    gtk4 = gtk_css + gtk4_extras

    # ---- write outputs ----
    os.makedirs(os.path.join(OUT, "gtk-4.0"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "gtk-3.0"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "gnome-shell"), exist_ok=True)
    with open(os.path.join(OUT, "gtk-4.0", "gtk.css"), "w") as f:
        f.write(gtk4)
    with open(os.path.join(OUT, "gtk-3.0", "gtk.css"), "w") as f:
        f.write(gtk3)
    with open(os.path.join(OUT, "gnome-shell", "gnome-shell.css"), "w") as f:
        f.write(shell)

    print("Built artifacts in", OUT)
    print(" accent_color =", accent_color, "accent_fg =", accent_fg)


if __name__ == "__main__":
    main()
