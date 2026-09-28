#!/usr/bin/env bash
# Удаление плазмоида org.mops1k.win11tasks из ~/.local.
#   --restore  восстановить панель из последнего бэкапа appletsrc
set -euo pipefail

APP_ID="org.mops1k.win11tasks"
PREFIX="${PREFIX:-$HOME/.local}"
PLUGIN_FILE="$PREFIX/lib/qt6/plugins/plasma/applets/${APP_ID}.so"
DROPIN_FILE="$HOME/.config/systemd/user/plasma-plasmashell.service.d/11-win11tasks-plugin-path.conf"
LAYOUT_FILE="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
RESTORE=0

for arg in "$@"; do
    case "$arg" in
        --restore) RESTORE=1 ;;
        -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
        *) echo "Неизвестный аргумент: $arg" >&2; exit 2 ;;
    esac
done

if [ "$RESTORE" = 1 ]; then
    BACKUP="$(ls -1t "$LAYOUT_FILE".win11tasks-bak-* 2>/dev/null | head -1 || true)"
    if [ -z "$BACKUP" ]; then
        echo "Бэкап appletsrc не найден — восстанавливать нечего." >&2
        exit 1
    fi
    cp "$BACKUP" "$LAYOUT_FILE"
    echo "==> Панель восстановлена из $BACKUP"
fi

echo "==> Удаление $PLUGIN_FILE"
rm -f "$PLUGIN_FILE"
rm -rf "$PREFIX/share/plasma/plasmoids/$APP_ID"

# Свой drop-in убираем только если он наш; общий drop-in (например, от win11tray)
# не трогаем — он нужен другим локальным плагинам.
if [ -f "$DROPIN_FILE" ]; then
    echo "==> Удаление drop-in $DROPIN_FILE"
    rm -f "$DROPIN_FILE"
    rmdir "$(dirname "$DROPIN_FILE")" 2>/dev/null || true
    systemctl --user daemon-reload
fi

systemctl --user restart plasma-plasmashell.service
echo "Готово."
