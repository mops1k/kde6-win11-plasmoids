#!/usr/bin/env bash
# Готовый релиз плазмоидов Win11 одним архивом: собранные C++-плазмоиды
# (win11tray, win11tasks), QML-плагин уведомлений win11clock, .plasmoid для
# QML-плазмоидов и скомпилированные переводы плюс манифест с версиями и
# контрольными суммами. Конечный пользователь сборкой не занимается:
#   scripts/online-install.sh            (скачать релиз с GitHub и установить)
#   scripts/install.sh --prebuilt-dir prebuilt   (установить из распакованного архива)
#
#   --tag <tag>        имя версии (по умолчанию git describe, иначе v<версия metadata.json>)
#   --out-dir <dir>    каталог для архива (по умолчанию dist/)
#   --jobs <n>         параллельная сборка (по умолчанию nproc)
#   --keep-stage       не удалять временный каталог сборки
#   -h, --help         эта справка
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ORDER=(win11tray win11tasks win11battery win11clock win11keyboardlayout)
declare -A APP_ID=(
    [win11tray]="org.mops1k.win11tray"
    [win11tasks]="org.mops1k.win11tasks"
    [win11battery]="org.mops1k.win11battery"
    [win11clock]="org.mops1k.win11clock"
    [win11keyboardlayout]="org.mops1k.win11keyboardlayout"
)
QML_APPS=(win11battery win11clock win11keyboardlayout)
CPP_APPS=(win11tray win11tasks)

OUT_DIR="$REPO_ROOT/dist"
TAG=""
JOBS="$(nproc 2>/dev/null || echo 4)"
KEEP_STAGE=0

usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; }

while (($#)); do
    case "$1" in
        --tag) shift; (($#)) || { echo "--tag требует значение" >&2; exit 2; }; TAG="$1" ;;
        --tag=*) TAG="${1#--tag=}" ;;
        --out-dir) shift; (($#)) || { echo "--out-dir требует значение" >&2; exit 2; }; OUT_DIR="$1" ;;
        --out-dir=*) OUT_DIR="${1#--out-dir=}" ;;
        --jobs) shift; (($#)) || { echo "--jobs требует значение" >&2; exit 2; }; JOBS="$1" ;;
        --jobs=*) JOBS="${1#--jobs=}" ;;
        --keep-stage) KEEP_STAGE=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Неизвестный аргумент: $1 (см. --help)" >&2; exit 2 ;;
    esac
    shift
done

for tool in cmake c++ kpackagetool6 msgfmt python3 tar git; do
    command -v "$tool" >/dev/null 2>&1 || { echo "Не найдено: $tool" >&2; exit 1; }
done

metadata_version() {
    sed -n 's/.*"Version": *"\([^"]*\)".*/\1/p' "$REPO_ROOT/$1/metadata.json" | head -1
}

if [ -z "$TAG" ]; then
    if TAG="$(git -C "$REPO_ROOT" describe --tags --exact-match 2>/dev/null)"; then
        :
    else
        TAG="v$(metadata_version win11clock)"
    fi
fi

ARCH="$(uname -m)"
DISTRO_ID="$(sed -n 's/^ID=//p' /etc/os-release 2>/dev/null | tr -d '"')"
DISTRO_LIKE="$(sed -n 's/^ID_LIKE=//p' /etc/os-release 2>/dev/null | tr -d '"')"
case " $DISTRO_ID $DISTRO_LIKE " in
    *arch*|*cachyos*|*manjaro*|*endeavouros*) DISTRO_TAG="arch" ;;
    *) DISTRO_TAG="${DISTRO_ID:-unknown}" ;;
esac

QT_VERSION="$(qmake6 -query QT_VERSION 2>/dev/null || pkg-config --modversion Qt6Core 2>/dev/null || echo unknown)"
PLASMA_VERSION="$(plasmashell --version 2>/dev/null | awk '{print $NF}' || true)"
PLASMA_VERSION="${PLASMA_VERSION:-unknown}"
COMMIT="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"

BASE_NAME="win11-plasmoids-${TAG}-${ARCH}-${DISTRO_TAG}"
PKG_NAME="win11-plasmoids-${TAG}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/win11-release-XXXXXX")"
cleanup() { if [ "$KEEP_STAGE" != 1 ]; then rm -rf "$WORK"; fi; }
trap cleanup EXIT

PKG_ROOT="$WORK/pkg/$PKG_NAME"
PREBUILT="$PKG_ROOT/prebuilt"
mkdir -p "$PKG_ROOT" "$PREBUILT"

echo "==> Релиз $TAG (commit $COMMIT, Qt $QT_VERSION, Plasma $PLASMA_VERSION)"

# --- 1. Дерево репозитория в архив ------------------------------------------
echo "==> Копирование дерева репозитория"
tar -cf - -C "$REPO_ROOT" \
    --exclude=.git --exclude=.dsh --exclude=dist \
    --exclude=build --exclude='build-*' --exclude='*.plasmoid' \
    --exclude='Screenshot*.png' --exclude='*.log' --exclude='*.bak' \
    --exclude='*.o' --exclude='*.so' --exclude='*.mo' \
    . | tar -xf - -C "$PKG_ROOT"

# --- 2. Сборка C++-плазмоидов ------------------------------------------------
# locale-файлы ki18n кладёт в <build>/locale/<язык>/LC_MESSAGES/<домен>.mo
collect_locale() {
    local build_dir="$1" mo lang
    for mo in "$build_dir"/locale/*/LC_MESSAGES/*.mo; do
        [ -f "$mo" ] || continue
        lang="$(basename "$(dirname "$(dirname "$mo")")")"
        install -Dm 644 "$mo" "$PREBUILT/locale/$lang/LC_MESSAGES/$(basename "$mo")"
        echo "    перевод: $lang/$(basename "$mo")"
    done
}

for app in "${CPP_APPS[@]}"; do
    id="${APP_ID[$app]}"
    build="$WORK/build/$app"
    echo "==> Сборка $app ($id)"
    cmake -S "$REPO_ROOT/$app" -B "$build" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$WORK/prefix-$app" -Wno-dev >/dev/null
    cmake --build "$build" --parallel "$JOBS" >/dev/null
    so="$build/lib/plasma/applets/${id}.so"
    [ -f "$so" ] || so="$(find "$build" -name "${id}.so" -type f -print -quit)"
    [ -n "$so" ] && [ -f "$so" ] || { echo "Не собран ${id}.so" >&2; exit 1; }
    install -Dm 755 "$so" "$PREBUILT/qt6-plugins/plasma/applets/${id}.so"
    echo "    плагин: ${id}.so"
    collect_locale "$build"
done

# --- 3. QML-плагин уведомлений win11clock -----------------------------------
echo "==> Сборка QML-плагина уведомлений win11clock"
NOTIF_SRC="$REPO_ROOT/win11clock/notifications"
NOTIF_BUILD="$WORK/build/win11clock-notifications"
NOTIF_PREFIX="$WORK/prefix-win11clock-notifications"
cmake -S "$NOTIF_SRC" -B "$NOTIF_BUILD" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$NOTIF_PREFIX" -Wno-dev >/dev/null
cmake --build "$NOTIF_BUILD" --parallel "$JOBS" >/dev/null
cmake --install "$NOTIF_BUILD" >/dev/null

NOTIF_QML_DIR="$NOTIF_PREFIX/lib/qt6/qml/org/mops1k/win11clock/notifications"
if [ ! -d "$NOTIF_QML_DIR" ]; then
    NOTIF_QML_DIR="$NOTIF_PREFIX/lib64/qt6/qml/org/mops1k/win11clock/notifications"
fi
[ -d "$NOTIF_QML_DIR" ] || { echo "Не найден установленный QML-модуль уведомлений" >&2; exit 1; }
mkdir -p "$PREBUILT/qt6-qml/org/mops1k/win11clock"
cp -a "$NOTIF_QML_DIR" "$PREBUILT/qt6-qml/org/mops1k/win11clock/notifications"
echo "    QML-модуль: prebuilt/qt6-qml/org/mops1k/win11clock/notifications"

# --- 4. .plasmoid для QML-плазмоидов и их переводы --------------------------
for app in "${QML_APPS[@]}"; do
    id="${APP_ID[$app]}"
    version="$(metadata_version "$app")"
    echo "==> Упаковка $app ($id $version)"
    [ -x "$REPO_ROOT/$app/scripts/package.sh" ] || {
        echo "Нет исполняемого $app/scripts/package.sh" >&2
        exit 1
    }
    (cd "$REPO_ROOT/$app" && ./scripts/package.sh >/dev/null)
    plasmoid="$REPO_ROOT/$app/dist/${id}-${version}.plasmoid"
    [ -f "$plasmoid" ] || { echo "Не собран $plasmoid" >&2; exit 1; }
    install -Dm 644 "$plasmoid" "$PREBUILT/plasmoids/$(basename "$plasmoid")"

    po_found=0
    for po in "$REPO_ROOT/$app"/po/*/*.po; do
        [ -f "$po" ] || continue
        po_found=1
        lang="$(basename "$(dirname "$po")")"
        dest="$PREBUILT/locale/$lang/LC_MESSAGES/plasma_applet_${id}.mo"
        mkdir -p "$(dirname "$dest")"
        msgfmt -o "$dest" "$po"
        echo "    перевод: $lang/plasma_applet_${id}.mo"
    done
    [ "$po_found" = 1 ] || echo "    (переводов нет)"
done

# --- 5. Манифест ------------------------------------------------------------
echo "==> Манифест prebuilt/manifest.json"
python3 - "$PREBUILT" "$TAG" "$COMMIT" "$ARCH" "$DISTRO_ID" "$DISTRO_TAG" \
    "$QT_VERSION" "$PLASMA_VERSION" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" <<'PY'
import hashlib
import json
import os
import sys

prebuilt, tag, commit, arch, distro_id, distro_tag, qt, plasma, built_at = sys.argv[1:10]

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

def mm(version):
    parts = version.split(".")
    return ".".join(parts[:2]) if len(parts) >= 2 else version

plugins, modules, plasmoids, locales = [], [], [], []
for root, _dirs, files in os.walk(prebuilt):
    for name in sorted(files):
        full = os.path.join(root, name)
        rel = os.path.relpath(full, prebuilt)
        if rel == "manifest.json":
            continue
        if rel.startswith("qt6-plugins/"):
            plugins.append({"id": name[:-3], "path": rel, "sha256": sha256(full)})
        elif rel.startswith("qt6-qml/"):
            modules.append({"path": rel, "sha256": sha256(full)})
        elif rel.startswith("plasmoids/"):
            plasmoids.append({"file": name, "path": rel, "sha256": sha256(full)})
        elif rel.startswith("locale/"):
            locales.append({"path": rel, "sha256": sha256(full)})

manifest = {
    "name": "win11-plasmoids",
    "tag": tag,
    "commit": commit,
    "built_at": built_at,
    "build_host": {"arch": arch, "distro_id": distro_id, "distro_tag": distro_tag},
    "requires": {
        "qt6": qt,
        "qt_major_minor": mm(qt),
        "plasma_workspace": plasma,
        "plasma_major_minor": mm(plasma),
    },
    "artifacts": {
        "plugins": plugins,
        "qml_modules": modules,
        "plasmoids": plasmoids,
        "locales": locales,
    },
}

with open(os.path.join(prebuilt, "manifest.json"), "w", encoding="utf-8") as fh:
    json.dump(manifest, fh, ensure_ascii=False, indent=2, sort_keys=True)
    fh.write("\n")

print(f"    плагинов: {len(plugins)}, плазмоидов: {len(plasmoids)}, "
      f"переводов: {len(locales)}, файлов QML-модуля: {len(modules)}")
PY

# --- 6. Архив ---------------------------------------------------------------
mkdir -p "$OUT_DIR"
ARCHIVE="$OUT_DIR/${BASE_NAME}.tar.gz"
rm -f "$ARCHIVE" "$ARCHIVE.sha256"
echo "==> Упаковка $ARCHIVE"
tar --sort=name --owner=0 --group=0 --numeric-owner \
    -czf "$ARCHIVE" -C "$WORK/pkg" "$PKG_NAME"
( cd "$OUT_DIR" && sha256sum "$(basename "$ARCHIVE")" >"$(basename "$ARCHIVE").sha256" )

# Отдельные .plasmoid прикладываются к релизу: QML-плазмоид ставится без
# скриптов через «Добавить виджеты → Установить из файла…».
rm -f "$OUT_DIR"/*.plasmoid
cp -f "$PREBUILT"/plasmoids/*.plasmoid "$OUT_DIR/"

echo
echo "Готово:"
echo "  $ARCHIVE"
echo "  $ARCHIVE.sha256"
echo "  .plasmoid: $(cd "$OUT_DIR" && ls ./*.plasmoid | tr '\n' ' ')"
echo "  размер: $(du -h "$ARCHIVE" | cut -f1)"
echo
echo "Проверка локально:  ./scripts/install.sh --prebuilt-dir <распакованный>/prebuilt --all --no-restart"
echo "Публикация:         gh release create $TAG \"$ARCHIVE\" \"$ARCHIVE.sha256\" \"$OUT_DIR\"/*.plasmoid"
if [ "$KEEP_STAGE" = 1 ]; then
    echo "Временный каталог сборки: $WORK"
else
    WORK=""
fi
exit 0
