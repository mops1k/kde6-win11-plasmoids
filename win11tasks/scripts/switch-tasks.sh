#!/usr/bin/env bash
# Замена системного таскбара на org.mops1k.win11tasks в панели Plasma.
# Делает бэкап appletsrc и меняет plugin= у существующего апплета icontasks,
# сохраняя его id, позицию и настройки (лаунчеры, группировку и т.д.).
#   --revert  вернуть системный таскбар из последнего бэкапа
#   --no-restart  не перезапускать plasmashell (панель перезапускает
#                 вызывающий скрипт)
set -euo pipefail

APP_ID="org.mops1k.win11tasks"
SYS_APPLET="org.kde.plasma.icontasks"
LAYOUT_FILE="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
PLUGIN_FILE="$HOME/.local/lib/qt6/plugins/plasma/applets/${APP_ID}.so"
REVERT=0
NO_RESTART=0

for arg in "$@"; do
    case "$arg" in
        --revert) REVERT=1 ;;
        --no-restart) NO_RESTART=1 ;;
        -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
        *) echo "Неизвестный аргумент: $arg" >&2; exit 2 ;;
    esac
done

[ -f "$LAYOUT_FILE" ] || { echo "Нет $LAYOUT_FILE" >&2; exit 1; }

if [ "$REVERT" = 1 ]; then
    BACKUP="$(ls -1t "$LAYOUT_FILE".win11tasks-bak-* 2>/dev/null | head -1 || true)"
    [ -n "$BACKUP" ] || { echo "Бэкап не найден" >&2; exit 1; }
    cp "$BACKUP" "$LAYOUT_FILE"
    echo "==> Системный таскбар возвращён из $BACKUP"
    if [ "$NO_RESTART" = 0 ]; then
        systemctl --user restart plasma-plasmashell.service
    fi
    exit 0
fi

[ -f "$PLUGIN_FILE" ] || {
    echo "Плагин не установлен ($PLUGIN_FILE). Сначала: scripts/install-local.sh" >&2
    exit 1
}

BACKUP="$LAYOUT_FILE.win11tasks-bak-$(date +%Y%m%d-%H%M%S)"
cp "$LAYOUT_FILE" "$BACKUP"
echo "==> Бэкап: $BACKUP"

if ! grep -q "^plugin=${SYS_APPLET}$" "$LAYOUT_FILE"; then
    if grep -q "^plugin=${APP_ID}$" "$LAYOUT_FILE"; then
        echo "Таскбар уже заменён — ничего не делаю."
        exit 0
    fi
    echo "В панели нет апплета ${SYS_APPLET}; добавьте Win11 Tasks вручную через настройку панели." >&2
    exit 1
fi

sed -i "s|^plugin=${SYS_APPLET}$|plugin=${APP_ID}|" "$LAYOUT_FILE"
echo "==> ${SYS_APPLET} -> ${APP_ID}"
if [ "$NO_RESTART" = 0 ]; then
    systemctl --user restart plasma-plasmashell.service
fi
echo "Готово. Откат: $0 --revert"
