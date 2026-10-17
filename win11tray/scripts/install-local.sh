#!/usr/bin/env bash
# Установка плазмоида org.mops1k.win11tray в ~/.local (без root):
# сборка из исходников или готовый плагин из релиза.
#   --prebuilt-dir <dir>  взять готовый .so из каталога prebuilt/ (без cmake)
#   --no-build    не пересобирать (использовать build/)
#   --no-restart  не перезапускать plasmashell
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ID="org.mops1k.win11tray"
PREFIX="${PREFIX:-$HOME/.local}"
PLUGIN_DIR="$PREFIX/lib/qt6/plugins/plasma/applets"
DROPIN_DIR="$HOME/.config/systemd/user/plasma-plasmashell.service.d"
DROPIN_FILE="$DROPIN_DIR/10-win11tray-plugin-path.conf"
BUILD_DIR="$SRC_DIR/build"
BUILD=1
RESTART=1
PREBUILT_DIR="${PREBUILT_DIR:-}"

while (($#)); do
    case "$1" in
        --prebuilt-dir) shift; (($#)) || { echo "--prebuilt-dir требует каталог" >&2; exit 2; }; PREBUILT_DIR="$1" ;;
        --prebuilt-dir=*) PREBUILT_DIR="${1#--prebuilt-dir=}" ;;
        --no-build) BUILD=0 ;;
        --no-restart) RESTART=0 ;;
        -h|--help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
        *) echo "Неизвестный аргумент: $1" >&2; exit 2 ;;
    esac
    shift
done

if [ -n "$PREBUILT_DIR" ]; then
    # shellcheck source=../../scripts/prebuilt-lib.sh
    . "$SRC_DIR/../scripts/prebuilt-lib.sh"
    prebuilt_require || exit 1
    PLUGIN_SRC="$(prebuilt_plugin_path "$APP_ID")" || exit 1
    echo "==> Готовый плагин из релиза: $PLUGIN_SRC"
else
    if [ "$BUILD" = 1 ]; then
        echo "==> Конфигурация сборки"
        cmake -S "$SRC_DIR" -B "$BUILD_DIR" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX="$PREFIX"
        echo "==> Сборка"
        cmake --build "$BUILD_DIR" --parallel "$(nproc)"
    fi

    PLUGIN_SRC="$BUILD_DIR/lib/plasma/applets/${APP_ID}.so"
    if [ ! -f "$PLUGIN_SRC" ]; then
        PLUGIN_SRC="$(find "$BUILD_DIR" -name "${APP_ID}.so" -type f -print -quit)"
    fi
    if [ -z "$PLUGIN_SRC" ] || [ ! -f "$PLUGIN_SRC" ]; then
        echo "Не найден собранный плагин ${APP_ID}.so в $BUILD_DIR" >&2
        exit 1
    fi
fi

echo "==> Установка $PLUGIN_SRC -> $PLUGIN_DIR"
mkdir -p "$PLUGIN_DIR"
install -m 755 "$PLUGIN_SRC" "$PLUGIN_DIR/${APP_ID}.so"

# Переводы: из релиза (prebuilt/locale) либо из <build>/locale, куда
# ki18n_install(po) компилирует .mo.
if [ -n "$PREBUILT_DIR" ]; then
    prebuilt_copy_locales "$PREFIX/share/locale" "plasma_applet_${APP_ID}"
else
    for mo in "$BUILD_DIR"/locale/*/LC_MESSAGES/*.mo; do
        [ -f "$mo" ] || continue
        lang="$(basename "$(dirname "$(dirname "$mo")")")"
        echo "==> Перевод: $lang/$(basename "$mo")"
        install -Dm 644 "$mo" "$PREFIX/share/locale/$lang/LC_MESSAGES/$(basename "$mo")"
    done
fi

# KPackage с тем же id конфликтует с C++-плагином (пустой поповер) — убираем.
rm -rf "$PREFIX/share/plasma/plasmoids/$APP_ID"

# Qt по умолчанию не смотрит в ~/.local/lib/qt6/plugins — добавляем путь
# через drop-in systemd-юнита plasmashell (без перелогина).
echo "==> Путь плагинов для plasmashell: $DROPIN_FILE"
mkdir -p "$DROPIN_DIR"
cat > "$DROPIN_FILE" <<'EOF'
[Service]
Environment=QT_PLUGIN_PATH=%h/.local/lib/qt6/plugins
EOF

systemctl --user daemon-reload
if [ "$RESTART" = 1 ]; then
    echo "==> Перезапуск plasmashell"
    systemctl --user restart plasma-plasmashell.service
    sleep 2
fi

echo
echo "Готово. Плагин установлен: $PLUGIN_DIR/${APP_ID}.so"
echo "Проверка:  plasmawindowed $APP_ID"
echo "Замена системного трея в панели:  $SRC_DIR/scripts/switch-tray.sh"
