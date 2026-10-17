#!/usr/bin/env bash
# Установка плазмоида org.mops1k.win11clock: C++ QML-плагин всплывающих
# уведомлений (notifications/) + KPackage (kpackagetool6) — из исходников
# или готовыми артефактами релиза.
#   --prebuilt-dir <dir>  взять готовый QML-модуль и .plasmoid из prebuilt/ (без cmake)
#   --no-build    не пересобирать C++ QML-плагин
#   --no-restart  не перезапускать plasmashell
set -euo pipefail

APP_ID="org.mops1k.win11clock"
DOMAIN="plasma_applet_${APP_ID}"
SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NOTIF_DIR="$SRC_DIR/notifications"
QML_IMPORT_DIR="$HOME/.local/lib/qt6/qml"
QML_PLUGIN_DIR="$QML_IMPORT_DIR/org/mops1k/win11clock/notifications"
DROPIN_DIR="$HOME/.config/systemd/user/plasma-plasmashell.service.d"
DROPIN="$DROPIN_DIR/20-win11clock-qml-import.conf"
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
fi

# 1. C++ QML-плагин всплывающих уведомлений (окна с ролью notification).
if [ -n "$PREBUILT_DIR" ]; then
    MODULE_SRC="$PREBUILT_DIR/qt6-qml/org/mops1k/win11clock/notifications"
    [ -d "$MODULE_SRC" ] || {
        echo "Нет $MODULE_SRC в каталоге prebuilt" >&2
        exit 1
    }
    prebuilt_check_dir "$MODULE_SRC" || {
        echo "Готовый QML-модуль несовместим с системой — запустите без --prebuilt-dir (сборка из исходников)." >&2
        exit 1
    }
    mkdir -p "$(dirname "$QML_PLUGIN_DIR")"
    rm -rf "$QML_PLUGIN_DIR"
    cp -a "$MODULE_SRC" "$QML_PLUGIN_DIR"
    echo "==> QML-плагин из релиза установлен: $QML_PLUGIN_DIR"
else
    if [ "$BUILD" = 1 ]; then
        for tool in cmake c++ wayland-scanner; do
            command -v "$tool" >/dev/null 2>&1 || { echo "Не найдено: $tool" >&2; exit 1; }
        done
        cmake -S "$NOTIF_DIR" -B "$NOTIF_DIR/build" \
            -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$HOME/.local"
        cmake --build "$NOTIF_DIR/build"
    fi
    cmake --install "$NOTIF_DIR/build"
    echo "==> QML-плагин установлен: $QML_PLUGIN_DIR"
fi

# 2. plasmashell должен видеть ~/.local/lib/qt6/qml (иначе импорт модуля
#    из KPackage-плазмоида не резолвится).
mkdir -p "$DROPIN_DIR"
cat > "$DROPIN" <<'EOF'
[Service]
Environment=QML_IMPORT_PATH=%h/.local/lib/qt6/qml
Environment=QML2_IMPORT_PATH=%h/.local/lib/qt6/qml
EOF
systemctl --user daemon-reload
echo "==> drop-in QML_IMPORT_PATH: $DROPIN"

# 3. KPackage-плазмоид.
if [ -n "$PREBUILT_DIR" ]; then
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

# 4. Переводы: из релиза (prebuilt/locale) либо .mo, собранные вручную
#    (у KPackage нет CMake/ki18n_install).
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
    systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null || true
    systemctl --user restart plasma-plasmashell.service
    echo "==> plasmashell перезапущен"
fi

echo "Готово. Замена системных часов: scripts/switch-clock.sh"
