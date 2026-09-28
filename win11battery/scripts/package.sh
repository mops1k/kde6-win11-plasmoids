#!/usr/bin/env bash
# Упаковка плазмоида в .plasmoid (zip-архив KPackage) для установки
# через «Добавить виджеты → Установить из файла…» или
# kpackagetool6 --type Plasma/Applet --install <файл>.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_ID="org.mops1k.win11battery"
VERSION="$(sed -n 's/.*"Version": *"\([^"]*\)".*/\1/p' "$SRC_DIR/metadata.json" | head -1)"
OUT_DIR="$SRC_DIR/dist"
OUT="$OUT_DIR/${APP_ID}-${VERSION}.plasmoid"

mkdir -p "$OUT_DIR"
rm -f "$OUT"

# В корне архива должны лежать metadata.json и contents/.
# zip может отсутствовать в системе, поэтому используем python3.
python3 - "$SRC_DIR" "$OUT" <<'PY'
import os
import sys
import zipfile

src, out = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as archive:
    archive.write(os.path.join(src, "metadata.json"), "metadata.json")
    for root, _dirs, files in os.walk(os.path.join(src, "contents")):
        for name in sorted(files):
            full = os.path.join(root, name)
            archive.write(full, os.path.relpath(full, src))
PY

echo "==> Собран $OUT"
echo "Установка: kpackagetool6 --type Plasma/Applet --install \"$OUT\""
