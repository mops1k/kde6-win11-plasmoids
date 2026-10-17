#!/usr/bin/env bash
# Установка QML-плазмоида org.mops1k.win11keyboardlayout в ~/.local:
# из исходников каталога или готовым .plasmoid из релиза.
#   --prebuilt-dir <dir>  взять готовый .plasmoid из каталога prebuilt/ (без msgfmt)
#   --no-restart  не перезапускать plasmashell
set -euo pipefail

APP_ID="org.mops1k.win11keyboardlayout"
DOMAIN="plasma_applet_${APP_ID}"
SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESTART=1
PREBUILT_DIR="${PREBUILT_DIR:-}"

while (($#)); do
    case "$1" in
        --prebuilt-dir) shift; (($#)) || { echo "--prebuilt-dir требует каталог" >&2; exit 2; }; PREBUILT_DIR="$1" ;;
        --prebuilt-dir=*) PREBUILT_DIR="${1#--prebuilt-dir=}" ;;
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
    PACKAGE_SRC="$(prebuilt_plasmoid_path "$APP_ID")" || exit 1
    echo "==> Готовый пакет из релиза: $PACKAGE_SRC"
else
    PACKAGE_SRC="$SRC_DIR"
fi

if kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -q "^${APP_ID}$"; then
    kpackagetool6 --type Plasma/Applet --upgrade "$PACKAGE_SRC"
    echo "==> Обновлён ${APP_ID}"
else
    kpackagetool6 --type Plasma/Applet --install "$PACKAGE_SRC"
    echo "==> Установлен ${APP_ID}"
fi

# Переводы: из релиза (prebuilt/locale) либо .mo, собранные вручную из po/
# (у KPackage нет CMake/ki18n_install).
if [ -n "$PREBUILT_DIR" ]; then
    prebuilt_copy_locales "$HOME/.local/share/locale" "$DOMAIN"
else
    for po in "$SRC_DIR"/po/*/*.po; do
        [ -f "$po" ] || continue
        lang="$(basename "$(dirname "$po")")"
        dest="$HOME/.local/share/locale/$lang/LC_MESSAGES"
        mkdir -p "$dest"
        msgfmt -o "$dest/$DOMAIN.mo" "$po"
        echo "==> Перевод: $dest/$DOMAIN.mo"
    done
fi

if [ "$RESTART" = 1 ]; then
    systemctl --user restart plasma-plasmashell.service
    echo "==> plasmashell перезапущен"
fi

echo "Готово. Замена системного апплета: scripts/switch-widget.sh"
