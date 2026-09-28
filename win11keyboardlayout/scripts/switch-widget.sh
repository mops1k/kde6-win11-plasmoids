#!/usr/bin/env bash
# Замена системного апплета раскладки (org.kde.plasma.keyboardlayout) на
# org.mops1k.win11keyboardlayout в панели Plasma.
# Правку appletsrc делает scripts/appletsrc-tool.py (см. комментарий в нём:
# системный апплет EnabledByDefault, поэтому его id должен остаться в
# knownItems, но уйти из extraItems). Бэкап appletsrc делается здесь.
#   --revert  вернуть системный апплет из последнего бэкапа
set -euo pipefail

APP_ID="org.mops1k.win11keyboardlayout"
SYS_APP="org.kde.plasma.keyboardlayout"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAYOUT_FILE="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
REVERT=0

for arg in "$@"; do
    case "$arg" in
        --revert) REVERT=1 ;;
        -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
        *) echo "Неизвестный аргумент: $arg" >&2; exit 2 ;;
    esac
done

[ -f "$LAYOUT_FILE" ] || { echo "Нет $LAYOUT_FILE" >&2; exit 1; }

# Правка appletsrc делается при остановленном plasmashell: иначе он при выходе
# перезаписывает файл своим состоянием из памяти.
with_plasma_stopped() {
    systemctl --user stop plasma-plasmashell.service
    "$@"
    systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null || true
    systemctl --user start plasma-plasmashell.service
}

if [ "$REVERT" = 1 ]; then
    BACKUP="$(ls -1t "$LAYOUT_FILE".win11keyboardlayout-bak-* 2>/dev/null | head -1 || true)"
    [ -n "$BACKUP" ] || { echo "Бэкап не найден" >&2; exit 1; }
    with_plasma_stopped cp "$BACKUP" "$LAYOUT_FILE"
    echo "==> Системный апплет раскладки возвращён из $BACKUP"
    exit 0
fi

if ! kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -q "^${APP_ID}$"; then
    echo "Плазмоид не установлен. Сначала: scripts/install-local.sh" >&2
    exit 1
fi

BACKUP="$LAYOUT_FILE.win11keyboardlayout-bak-$(date +%Y%m%d-%H%M%S)"
cp "$LAYOUT_FILE" "$BACKUP"
echo "==> Бэкап: $BACKUP"

with_plasma_stopped python3 "$SCRIPT_DIR/appletsrc-tool.py" --apply "$LAYOUT_FILE"
echo "Готово. Откат: $0 --revert"
