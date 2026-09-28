#!/usr/bin/env bash
# Замена системного трея на org.mops1k.win11tray в панели Plasma.
# Делает бэкап appletsrc и меняет plugin= у существующего апплета трея,
# сохраняя его id, позицию и дочерние апплеты.
#   --revert  вернуть системный трей из последнего бэкапа
set -euo pipefail

APP_ID="org.mops1k.win11tray"
SYS_TRAY="org.kde.plasma.systemtray"
LAYOUT_FILE="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
PLUGIN_FILE="$HOME/.local/lib/qt6/plugins/plasma/applets/${APP_ID}.so"
REVERT=0

for arg in "$@"; do
    case "$arg" in
        --revert) REVERT=1 ;;
        -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
        *) echo "Неизвестный аргумент: $arg" >&2; exit 2 ;;
    esac
done

[ -f "$LAYOUT_FILE" ] || { echo "Нет $LAYOUT_FILE" >&2; exit 1; }

if [ "$REVERT" = 1 ]; then
    BACKUP="$(ls -1t "$LAYOUT_FILE".win11tray-bak-* 2>/dev/null | head -1 || true)"
    [ -n "$BACKUP" ] || { echo "Бэкап не найден" >&2; exit 1; }
    cp "$BACKUP" "$LAYOUT_FILE"
    echo "==> Системный трей возвращён из $BACKUP"
    systemctl --user restart plasma-plasmashell.service
    exit 0
fi

[ -f "$PLUGIN_FILE" ] || {
    echo "Плагин не установлен ($PLUGIN_FILE). Сначала: scripts/install-local.sh" >&2
    exit 1
}

BACKUP="$LAYOUT_FILE.win11tray-bak-$(date +%Y%m%d-%H%M%S)"
cp "$LAYOUT_FILE" "$BACKUP"
echo "==> Бэкап: $BACKUP"

if ! grep -q "^plugin=${SYS_TRAY}$" "$LAYOUT_FILE"; then
    if grep -q "^plugin=${APP_ID}$" "$LAYOUT_FILE"; then
        echo "Трей уже заменён — ничего не делаю."
        exit 0
    fi
    echo "В панели нет апплета ${SYS_TRAY}; добавьте Win11 Tray вручную через настройку панели." >&2
    exit 1
fi

sed -i "s|^plugin=${SYS_TRAY}$|plugin=${APP_ID}|" "$LAYOUT_FILE"
echo "==> ${SYS_TRAY} -> ${APP_ID}"
systemctl --user restart plasma-plasmashell.service
echo "Готово. Откат: $0 --revert"
