# LF2 Blue — Installer

A standalone, no-dependency installer for the **LF2 Blue** GNOME theme. It applies the
theme to GTK3, GTK4/libadwaita apps, and the GNOME Shell **without requiring Rewaita
(or any background daemon)** to be installed or running.

Licensed under **GNU General Public License v3.0 or later** ([../LICENSE](../LICENSE)).
Installer scripts by **gardenk4d4rd**.

## How it works

GTK3 and GTK4 automatically load per-user CSS on every app launch:

| Path | Loaded by |
|------|-----------|
| `~/.config/gtk-4.0/gtk.css` | GTK4 / libadwaita apps (Settings, Files, …) |
| `~/.config/gtk-3.0/gtk.css` | GTK3 apps |
| `~/.local/share/themes/lf2-blue/gnome-shell/gnome-shell.css` | GNOME Shell (via the User Themes extension) |

So the installer just **writes the theme files to those locations** and flips the
matching GSettings. Newly-opened apps and the shell (after login) pick the theme up
automatically. No running process is needed to keep it applied.

## Requirements

- An **Ubuntu / GNOME (Wayland or X11)** desktop
- `gsettings` (part of glib, present by default)
- The **User Themes** extension for the Shell part (`gnome-shell-extensions`)
  - If absent, the installer warns; the GTK parts still install.

## Install

```bash
./install-lf2.sh
```

It is **idempotent** — safe to run again. Each run first backs up the current
`gtk-3.0/gtk.css`, `gtk-4.0/gtk.css`, and any existing `lf2-blue` shell theme to
`~/.config/lf2-blue/backups/<timestamp>/`.

After installing, **log out and back in** (Wayland has no `Alt+F2 → r` reload) to restyle
the shell and any currently-open apps. Newly launched apps pick it up immediately.

### Options

| Flag | Effect |
|------|--------|
| `--theme-dir PATH` | Point at a different copy of the bundled CSS (used by tests). |
| `--no-color-scheme` | Do not change `color-scheme` to `prefer-dark`. |
| `--yes` | Skip the confirmation prompt. |

## Uninstall

```bash
./uninstall-lf2.sh
```

Restores the previous GTK3/GTK4 and Shell state from the newest backup, removes the
`lf2-blue` shell theme, and resets `user-theme name` and `color-scheme` to `default`.
If no backup exists it removes the LF2 files instead.

## What is included

```
themes/lf2-blue/
├── gtk-4.0/gtk.css             # GTK4 / libadwaita standalone theme
├── gtk-3.0/gtk.css             # GTK3 standalone theme
└── gnome-shell/gnome-shell.css # GNOME Shell standalone theme
```

These are **built to mirror Rewaita's own output exactly** — they are the same files
Rewaita generates for the LF2 v0.3 theme, produced standalone so no Rewaita/daemon is
needed. The CSS artifacts are derived from **Rewaita** by Nathan Perlman (SwordPuffin),
licensed under GPL-3.0-or-later ([https://github.com/SwordPuffin/Rewaita](https://github.com/SwordPuffin/Rewaita)).

- `gtk-4.0/gtk.css` — Rewaita's GTK4 mechanism: the LF2 **CSS-variable** sheet
  (`:root { --window-bg-color … --sidebar-border-color … }`) plus the `accent-tabs`
  and `accent-*` extras. libadwaita consumes these variables, which is what themes
  Settings / Files.
- `gtk-3.0/gtk.css` — the full Rewaita **GTK3 template** with the LF2 palette
  substituted in (all `@window-bg-color`, `@headerbar-bg-color`, … tokens resolved).
- `gnome-shell/gnome-shell.css` — Rewaita's **GNOME Shell template** with the LF2
  values substituted, plus the accent-tabs shell block.

The installer writes these to the standard auto-loaded per-user paths and does no
templating at install time. Each file is byte-identical to what Rewaita produces for
LF2 v0.3 on this machine.

## Verification

- The **window background, cards, buttons, borders, text, etc.** are verified working in
  the Docker sandbox (GTK4 auto-loads `gtk-4.0/gtk.css` and selector rules apply).
- The **headerbar / window-control decorations** are verified under a real
  `mutter --nested` compositor session in the sandbox: the standalone CSS themes the
  headerbar full-width Deep Navy with Frame Blue borders and Void content.
- The **GNOME Shell** part is verified under a real systemd/logind session (user-theme
  extension loads `gnome-shell.css`; the panel renders Void with Deep Navy accents and
  Off-White text vs. Adwaita grey). Before/after: `test/artifacts/shell-before-after.png`.
