# LF2 Blue — Schema (Source of Truth)

This directory is the **authoritative, reproducible source of truth** for the LF2 Blue
theme as delivered by the standalone installer. Everything here lets us regenerate the
exact theme artifacts that were verified to apply perfectly on a fresh, isolated Ubuntu
user — and nothing about it depends on Rewaita being installed or running.

## License & Attributions

This project is licensed under **GPL-3.0-or-later** ([../LICENSE](../LICENSE)).

The Rewaita template files in `sources/` (`rewaita-gtk3-template.css`,
`rewaita-shell-template.css`, `rewaita-css_templates.py`) are from
[**Rewaita**](https://github.com/SwordPuffin/Rewaita) by Nathan Perlman (SwordPuffin),
licensed under **GPL-3.0-or-later**. Their original license headers are preserved.

The LF2 v0.3 theme (`sources/lf2-blue-theme.css`) and `build/build.py` are original work
by **gardenk4d4rd**.

## Layout

```
schema/
├── README.md              # this manifest
├── sources/               # canonical inputs (locked, signed by checksums)
│   ├── lf2-blue-theme.css             # LF2 v0.3 theme (arish's Rewaita data/dark/lf2 v0.3.css)
│   ├── rewaita-gtk3-template.css      # Rewaita src/themes/gtk3-template/gtk.css
│   ├── rewaita-shell-template.css     # Rewaita src/themes/gnome-shell-template.css
│   ├── rewaita-css_templates.py       # Rewaita src/themes/css_templates.py (accent_tab_css_gs)
│   └── rewaita-prefs.json             # Rewaita preferences (canonical config inputs)
├── build/
│   └── build.py           # the build schema: reproduces Rewaita's build logic in Python
└── out/                   # generated artifacts (byte-identical to installer's css)
    ├── gtk-4.0/gtk.css
    ├── gtk-3.0/gtk.css
    └── gnome-shell/gnome-shell.css
```

## How the theme is derived (build schema)

The installer ships the **same files Rewaita generates** for the LF2 v0.3 dark theme,
built standalone so no Rewaita/daemon is required. `build/build.py` replicates Rewaita's
exact pipeline:

- **GTK4** (`gtk-4.0/gtk.css`) = the LF2 theme's CSS-variable sheet (`:root { --window-bg-color
  … --sidebar-border-color … }`) verbatim, plus the `accent-tabs` block
  (`*:selected`, `*:checked:not(expander)`) and `@define-color accent_bg_color
  #237CFF; @define-color accent_fg_color #EEEEEE;`. libadwaita (Settings, Files) consumes
  these variables — this is what themes them.
- **GTK3** (`gtk-3.0/gtk.css`) = the full Rewaita gtk3-template with every `@token`
  substituted with the LF2 palette values.
- **GNOME Shell** (`gnome-shell/gnome-shell.css`) = the Rewaita shell template with the LF2
  values substituted, plus the accent-tabs shell block.

`rewaita-prefs.json` encodes the config that shaped the build (accent=`blue`, `accent-fg`,
`accent-tabs`, `light-text`, etc.). Changing it would change the derived accent/foreground
choices; the defaults here reproduce the verified-working output exactly.

## Regenerating the artifacts

```bash
cd schema
./build/build.py out        # or: python3 build/build.py out
```

This writes `out/gtk-4.0/gtk.css`, `out/gtk-3.0/gtk.css`, and
`out/gnome-shell/gnome-shell.css`. The output is **byte-identical** to the css shipped in
`../installer/themes/lf2-blue/`.

## Canonical checksums

Regenerated artifacts (must always match the installer's delivered css):

| Artifact                     | SHA-256 |
|------------------------------|---------|
| gtk-4.0/gtk.css              | `1e5e352957fc0891768ca097a52384e3919daa51d2d9399e3abe07eeb7c0d0ff` |
| gtk-3.0/gtk.css              | `eaa1148bc714927556b1261e0cea96249063cce9aa936c18f15d88a27af62e47` |
| gnome-shell/gnome-shell.css  | `4c4c2e02d1d60d798b50f66a27fd333a7b0df8ebe37535df5725b8315d3576e6` |

Sources:

| Source                          | SHA-256 |
|---------------------------------|---------|
| lf2-blue-theme.css              | `556f2879fb38b2c53ee8dd7da609ba478ec652e1bc538335a6b5c20eddf9070b` |
| rewaita-gtk3-template.css       | `5b4f694521b6c251e6f29405723a0ae09345dd57317d5667b052ed14645a8895` |
| rewaita-shell-template.css      | `1d780b11d4b42f5da571aed25b472f67c93e575da672f4b2af5f65c211f0c44a` |
| rewaita-css_templates.py        | `1d87772acd366a6d8395491641b613ab10477c30f3fa1923a2e6a08f58721dfc` |
| rewaita-prefs.json              | `89fa1096fb730a3cf03a9bc01d146f7117156a587c51e8e3e62cbe36e7f0a0d0` |
| build/build.py                  | `e59b3e810f7a80ff349d6513c8fa1eec0ac1fe3feb6da2e57a1e2c7eaf2dc6e4` |

## Expected GSettings (what the installer sets / expects)

These are the values the installer applies on the target user (read-only reference):

| Key | Value |
|-----|-------|
| `org.gnome.desktop.interface color-scheme` | `prefer-dark` |
| `org.gnome.desktop.interface icon-theme` | `Adwaita` |
| `org.gnome.shell.extensions.user-theme name` | `lf2-blue` |
| (User Themes extension) | `user-theme@gnome-shell-extensions.gcampax.github.com` |

Note: `gtk-theme` is intentionally **not** set — Rewaita's mechanism layers the per-user
css on top of the Adwaita base, which themes Settings/Files correctly.
