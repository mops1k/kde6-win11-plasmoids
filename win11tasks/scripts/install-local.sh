#!/usr/bin/env bash
# Сборка и установка плазмоида org.mops1k.win11tasks в ~/.local (без root).
#   --no-build    не пересобирать (использовать build/)
#   --no-restart  не перезапускать plasmashell
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ID="org.mops1k.win11tasks"
PREFIX="${PREFIX:-$HOME/.local}"
PLUGIN_DIR="$PREFIX/lib/qt6/plugins/plasma/applets"
DROPIN_DIR="$HOME/.config/systemd/user/plasma-plasmashell.service.d"
DROPIN_FILE="$DROPIN_DIR/11-win11tasks-plugin-path.conf"
BUILD_DIR="$SRC_DIR/build"
BUILD=1
RESTART=1

for arg in "$@"; do
    case "$arg" in
        --no-build) BUILD=0 ;;
        --no-restart) RESTART=0 ;;
        -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
        *) echo "Неизвестный аргумент: $arg" >&2; exit 2 ;;
    esac
done

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

echo "==> Установка $PLUGIN_SRC -> $PLUGIN_DIR"
mkdir -p "$PLUGIN_DIR"
install -m 755 "$PLUGIN_SRC" "$PLUGIN_DIR/${APP_ID}.so"

# Переводы: ki18n_install(po) компилирует .mo в <build>/locale/<язык>/LC_MESSAGES,
# отсюда копируем их в пользовательский share/locale.
for mo in "$BUILD_DIR"/locale/*/LC_MESSAGES/*.mo; do
    [ -f "$mo" ] || continue
    lang="$(basename "$(dirname "$(dirname "$mo")")")"
    echo "==> Перевод: $lang/$(basename "$mo")"
    install -Dm 644 "$mo" "$PREFIX/share/locale/$lang/LC_MESSAGES/$(basename "$mo")"
done

# KPackage с тем же id конфликтует с C++-плагином — убираем.
rm -rf "$PREFIX/share/plasma/plasmoids/$APP_ID"

# Qt по умолчанию не смотрит в ~/.local/lib/qt6/plugins: путь добавляется
# drop-in'ом plasmashell. Если такой drop-in уже есть (например, от win11tray),
# второй не создаём.
if ! grep -rqs "QT_PLUGIN_PATH" "$DROPIN_DIR" 2>/dev/null; then
    echo "==> Путь плагинов для plasmashell: $DROPIN_FILE"
    mkdir -p "$DROPIN_DIR"
    cat > "$DROPIN_FILE" <<'EOF'
[Service]
Environment=QT_PLUGIN_PATH=%h/.local/lib/qt6/plugins
EOF
    systemctl --user daemon-reload
else
    echo "==> QT_PLUGIN_PATH уже задан drop-in'ом в $DROPIN_DIR"
fi

if [ "$RESTART" = 1 ]; then
    echo "==> Перезапуск plasmashell"
    systemctl --user restart plasma-plasmashell.service
    sleep 2
fi

echo
echo "Готово. Плагин установлен: $PLUGIN_DIR/${APP_ID}.so"
echo "Замена системного таскбара в панели:  $SRC_DIR/scripts/switch-tasks.sh"
