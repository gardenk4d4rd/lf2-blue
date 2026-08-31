#!/usr/bin/env bash
# Verify the LF2 Blue schema is intact and still reproduces the shipped artifacts.
set -euo pipefail
cd "$(dirname "$0")"

echo "== 1. verify source checksums =="
sha256sum -c checksums.txt || { echo "SOURCE CHECKSUM MISMATCH"; exit 1; }

echo "== 2. regenerate artifacts =="
rm -rf out
python3 build/build.py out

echo "== 3. compare regenerated vs installer css =="
ok=1
for pair in \
  "out/gtk-4.0/gtk.css:../installer/themes/lf2-blue/gtk-4.0/gtk.css" \
  "out/gtk-3.0/gtk.css:../installer/themes/lf2-blue/gtk-3.0/gtk.css" \
  "out/gnome-shell/gnome-shell.css:../installer/themes/lf2-blue/gnome-shell/gnome-shell.css"; do
  a="${pair%%:*}"; b="${pair##*:}"
  if diff -q "$a" "$b" >/dev/null 2>&1; then
    echo "  OK   $a == $b"
  else
    echo "  FAIL $a != $b"
    ok=0
  fi
done
[ $ok -eq 1 ] && echo "ALL CHECKS PASSED" || { echo "VERIFICATION FAILED"; exit 1; }