#!/usr/bin/env bash
# Общие функции установки из готового релиза. Подключаются (source) только
# когда задан PREBUILT_DIR — каталог `prebuilt/` из распакованного архива
# релиза (win11-plasmoids-<tag>-<arch>-<distro>.tar.gz).
#
# Содержимое prebuilt/:
#   manifest.json                                  версии сборки, sha256 артефактов
#   qt6-plugins/plasma/applets/<id>.so             C++-апплеты win11tray/win11tasks
#   qt6-qml/org/mops1k/win11clock/notifications/   QML-модуль всплывающих уведомлений
#   plasmoids/<id>-<версия>.plasmoid               KPackage QML-плазмоидов
#   locale/<язык>/LC_MESSAGES/*.mo                 переводы
#
# Использование: PREBUILT_DIR=<dir>; . prebuilt-lib.sh

prebuilt_msg() { echo "==> prebuilt: $*" >&2; }

prebuilt_manifest_path() { printf '%s/manifest.json\n' "$PREBUILT_DIR"; }

# Проверяет, что каталог похож на prebuilt из релиза.
prebuilt_require() {
    [ -n "${PREBUILT_DIR:-}" ] || { echo "PREBUILT_DIR не задан" >&2; return 1; }
    [ -d "$PREBUILT_DIR" ] || { echo "Нет каталога $PREBUILT_DIR" >&2; return 1; }
    [ -f "$(prebuilt_manifest_path)" ] || {
        echo "Нет $(prebuilt_manifest_path) — это не каталог prebuilt из релиза" >&2
        return 1
    }
    command -v python3 >/dev/null 2>&1 || { echo "Для prebuilt нужен python3" >&2; return 1; }
    return 0
}

# prebuilt_field <ключ.через.точку> — значение из манифеста.
prebuilt_field() {
    python3 - "$(prebuilt_manifest_path)" "$1" <<'PY'
import json
import sys

path, key = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as fh:
    data = json.load(fh)
for part in key.split("."):
    if isinstance(data, dict) and part in data:
        data = data[part]
    else:
        sys.exit(1)
if isinstance(data, (dict, list)):
    print(json.dumps(data, ensure_ascii=False))
else:
    print(data)
PY
}

# Путь к .plasmoid QML-плазмоида в prebuilt (версия ищется по маске).
prebuilt_plasmoid_path() {
    local id="$1" path
    for path in "$PREBUILT_DIR"/plasmoids/"$id"-*.plasmoid; do
        [ -f "$path" ] || continue
        printf '%s\n' "$path"
        return 0
    done
    echo "Нет plasmoids/${id}-*.plasmoid в $PREBUILT_DIR" >&2
    return 1
}

# Путь к C++-плагину апплета в prebuilt.
prebuilt_plugin_path() {
    local id="$1"
    local path="$PREBUILT_DIR/qt6-plugins/plasma/applets/${id}.so"
    [ -f "$path" ] || { echo "Нет $path" >&2; return 1; }
    printf '%s\n' "$path"
}

# Локальные версии Qt и Plasma (пусто, если определить не удалось).
prebuilt_local_qt() {
    qmake6 -query QT_VERSION 2>/dev/null || pkg-config --modversion Qt6Core 2>/dev/null || true
}

prebuilt_local_plasma() {
    plasmashell --version 2>/dev/null | awk '{print $NF}' || true
}

# prebuilt_version_ge <a> <b> — истина, если a >= b.
prebuilt_version_ge() {
    python3 - "$1" "$2" <<'PY'
import re
import sys

def key(value):
    return [int(part) for part in re.findall(r"\d+", value.split("-")[0])]

sys.exit(0 if key(sys.argv[1]) >= key(sys.argv[2]) else 1)
PY
}

# Проверяет, что система не старше той, на которой собран релиз.
prebuilt_check_versions() {
    local want_plasma want_qt local_plasma local_qt rc=0
    want_plasma="$(prebuilt_field requires.plasma_major_minor 2>/dev/null || true)"
    want_qt="$(prebuilt_field requires.qt_major_minor 2>/dev/null || true)"
    local_plasma="$(prebuilt_local_plasma)"
    local_qt="$(prebuilt_local_qt)"

    if [ -n "$want_plasma" ] && [ "$want_plasma" != "unknown" ]; then
        if [ -z "$local_plasma" ]; then
            prebuilt_msg "не удалось определить версию Plasma (нужна >= $want_plasma)"
            rc=1
        elif ! prebuilt_version_ge "$local_plasma" "$want_plasma"; then
            prebuilt_msg "Plasma $local_plasma старше $want_plasma, под которую собран релиз"
            rc=1
        fi
    fi
    if [ -n "$want_qt" ] && [ "$want_qt" != "unknown" ]; then
        if [ -z "$local_qt" ]; then
            prebuilt_msg "не удалось определить версию Qt (нужна >= $want_qt)"
            rc=1
        elif ! prebuilt_version_ge "$local_qt" "$want_qt"; then
            prebuilt_msg "Qt $local_qt старше $want_qt, под которую собран релиз"
            rc=1
        fi
    fi
    return "$rc"
}

# prebuilt_check_so <файл> — ищет недостающие разделяемые библиотеки.
prebuilt_check_so() {
    local so="$1" missing
    [ -f "$so" ] || { prebuilt_msg "нет файла $so"; return 1; }
    command -v ldd >/dev/null 2>&1 || return 0
    missing="$(ldd "$so" 2>/dev/null | awk '/not found/ {print $1}' | sort -u | tr '\n' ' ')"
    if [ -n "${missing// /}" ]; then
        prebuilt_msg "у $(basename "$so") не найдены библиотеки: $missing"
        return 1
    fi
    return 0
}

# Проверяет все .so из каталога (QML-модуль уведомлений).
prebuilt_check_dir() {
    local dir="$1" so rc=0
    local -a found=()
    for so in "$dir"/*.so; do
        [ -f "$so" ] || continue
        found+=("$so")
        prebuilt_check_so "$so" || rc=1
    done
    ((${#found[@]})) || { prebuilt_msg "в $dir нет .so"; return 1; }
    return "$rc"
}

# prebuilt_copy_locales <каталог share/locale> <домен>... — копирует .mo из релиза.
prebuilt_copy_locales() {
    local dest_root="$1"; shift
    local domain mo lang count=0
    for domain in "$@"; do
        for mo in "$PREBUILT_DIR"/locale/*/LC_MESSAGES/"$domain".mo; do
            [ -f "$mo" ] || continue
            lang="$(basename "$(dirname "$(dirname "$mo")")")"
            mkdir -p "$dest_root/$lang/LC_MESSAGES"
            install -m 644 "$mo" "$dest_root/$lang/LC_MESSAGES/$domain.mo"
            echo "==> Перевод: $dest_root/$lang/LC_MESSAGES/$domain.mo"
            count=$((count + 1))
        done
    done
    return 0
}
