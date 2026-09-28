#!/usr/bin/env bash
# Установка QML-плазмоида org.mops1k.win11keyboardlayout в ~/.local.
#   --no-restart  не перезапускать plasmashell
set -euo pipefail

APP_ID="org.mops1k.win11keyboardlayout"
SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESTART=1

for arg in "$@"; do
    case "$arg" in
        --no-restart) RESTART=0 ;;
        -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
        *) echo "Неизвестный аргумент: $arg" >&2; exit 2 ;;
    esac
done

if kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -q "^${APP_ID}$"; then
    kpackagetool6 --type Plasma/Applet --upgrade "$SRC_DIR"
    echo "==> Обновлён ${APP_ID}"
else
    kpackagetool6 --type Plasma/Applet --install "$SRC_DIR"
    echo "==> Установлен ${APP_ID}"
fi

if [ "$RESTART" = 1 ]; then
    systemctl --user restart plasma-plasmashell.service
    echo "==> plasmashell перезапущен"
fi

echo "Готово. Замена системного апплета: scripts/switch-widget.sh"
