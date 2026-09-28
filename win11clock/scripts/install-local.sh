#!/usr/bin/env bash
# Установка плазмоида org.mops1k.win11clock: C++ QML-плагин всплывающих
# уведомлений (notifications/) + KPackage (kpackagetool6).
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

for arg in "$@"; do
    case "$arg" in
        --no-build) BUILD=0 ;;
        --no-restart) RESTART=0 ;;
        -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
        *) echo "Неизвестный аргумент: $arg" >&2; exit 2 ;;
    esac
done

# 1. C++ QML-плагин всплывающих уведомлений (окна с ролью notification).
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
if kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -q "^${APP_ID}$"; then
    kpackagetool6 --type Plasma/Applet --upgrade "$SRC_DIR"
    echo "==> Обновлён ${APP_ID}"
else
    kpackagetool6 --type Plasma/Applet --install "$SRC_DIR"
    echo "==> Установлен ${APP_ID}"
fi

# 4. Переводы: .mo собираются вручную (у KPackage нет CMake/ki18n_install).
for po in "$SRC_DIR"/po/*/*.po; do
    [ -f "$po" ] || continue
    lang="$(basename "$(dirname "$po")")"
    dest="$HOME/.local/share/locale/$lang/LC_MESSAGES"
    mkdir -p "$dest"
    msgfmt -o "$dest/$DOMAIN.mo" "$po"
    echo "==> Перевод: $dest/$DOMAIN.mo"
done

if [ "$RESTART" = 1 ]; then
    systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null || true
    systemctl --user restart plasma-plasmashell.service
    echo "==> plasmashell перезапущен"
fi

echo "Готово. Замена системных часов: scripts/switch-clock.sh"
