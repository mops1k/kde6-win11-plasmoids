#!/usr/bin/env bash
# Удаление плазмоида org.mops1k.win11clock: KPackage, C++ QML-плагин
# всплывающих уведомлений и systemd drop-in с QML_IMPORT_PATH.
#   --restore  вернуть системные часы из последнего бэкапа appletsrc
set -euo pipefail

APP_ID="org.mops1k.win11clock"
LAYOUT_FILE="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
QML_PLUGIN_DIR="$HOME/.local/lib/qt6/qml/org/mops1k/win11clock/notifications"
DROPIN="$HOME/.config/systemd/user/plasma-plasmashell.service.d/20-win11clock-qml-import.conf"
RESTORE=0

for arg in "$@"; do
    case "$arg" in
        --restore) RESTORE=1 ;;
        -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
        *) echo "Неизвестный аргумент: $arg" >&2; exit 2 ;;
    esac
done

if [ "$RESTORE" = 1 ]; then
    BACKUP="$(ls -1t "$LAYOUT_FILE".win11clock-bak-* 2>/dev/null | head -1 || true)"
    [ -n "$BACKUP" ] || { echo "Бэкап не найден" >&2; exit 1; }
    systemctl --user stop plasma-plasmashell.service
    cp "$BACKUP" "$LAYOUT_FILE"
    systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null || true
    systemctl --user start plasma-plasmashell.service
    echo "==> Панель возвращена из $BACKUP"
fi

if kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -q "^${APP_ID}$"; then
    kpackagetool6 --type Plasma/Applet --remove "$APP_ID"
    echo "==> Удалён ${APP_ID}"
else
    echo "==> ${APP_ID} не установлен"
fi

if [ -d "$QML_PLUGIN_DIR" ]; then
    rm -rf "$QML_PLUGIN_DIR"
    rmdir -p "$HOME/.local/lib/qt6/qml/org/mops1k/win11clock" 2>/dev/null || true
    echo "==> Удалён QML-плагин: $QML_PLUGIN_DIR"
fi

if [ -f "$DROPIN" ]; then
    rm -f "$DROPIN"
    systemctl --user daemon-reload
    echo "==> Удалён drop-in: $DROPIN"
fi

systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null || true
systemctl --user restart plasma-plasmashell.service
echo "Готово."
