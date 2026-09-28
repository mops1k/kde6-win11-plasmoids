#!/usr/bin/env bash
# Установка плазмоидов Win11 из монорепо.
# Без аргументов — интерактивный выбор: whiptail-чекбоксы, при их отсутствии
# или без TTY — текстовое нумерованное меню.
#
#   --list                показать плазмоиды и выйти
#   --all                 установить все
#   --only <a,b|a b>      установить только перечисленные (можно повторять)
#   --no-build            не пересобирать C++-плазмоиды (использовать build/)
#   --no-restart          не перезапускать plasmashell
#   -h, --help            эта справка
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"

PLUGIN_ORDER=(win11tray win11tasks win11battery win11clock win11keyboardlayout)

declare -A PLUGIN_APP=(
    [win11tray]="org.mops1k.win11tray"
    [win11tasks]="org.mops1k.win11tasks"
    [win11battery]="org.mops1k.win11battery"
    [win11clock]="org.mops1k.win11clock"
    [win11keyboardlayout]="org.mops1k.win11keyboardlayout"
)
declare -A PLUGIN_KIND=(
    [win11tray]="C++"
    [win11tasks]="C++"
    [win11battery]="QML"
    [win11clock]="QML"
    [win11keyboardlayout]="QML"
)
declare -A PLUGIN_DESC=(
    [win11tray]="Трей: замена системного трея, поповер быстрых настроек"
    [win11tasks]="Таскбар icons-only с Win11-тултипами и превью"
    [win11battery]="Батарея с процентом внутри, системное меню питания"
    [win11clock]="Часы над датой, уведомления, календарь, «Не беспокоить»"
    [win11keyboardlayout]="Раскладка РУС/ENG с настройками шрифта"
)

BUILD=1
RESTART=1
MODE=""          # list | all | only | interactive
ONLY=()

usage() { sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; }

fail() { echo "Ошибка: $*" >&2; exit 2; }

list_plugins() {
    printf '%-22s %-6s %-32s %s\n' "КАТАЛОГ" "ТИП" "ID АППЛЕТА" "ОПИСАНИЕ"
    local p
    for p in "${PLUGIN_ORDER[@]}"; do
        printf '%-22s %-6s %-32s %s\n' "$p" "${PLUGIN_KIND[$p]}" "${PLUGIN_APP[$p]}" "${PLUGIN_DESC[$p]}"
    done
}

# Приводит токены (номера или имена) к именам каталогов; дубликаты убирает.
normalize_selection() {
    local -A seen=()
    local tok idx i
    for tok in "$@"; do
        [ -n "$tok" ] || continue
        if [[ "$tok" =~ ^[0-9]+$ ]]; then
            idx="$tok"
            if (( idx < 1 || idx > ${#PLUGIN_ORDER[@]} )); then
                echo "Ошибка: нет плазмоида с номером $idx (1..${#PLUGIN_ORDER[@]})" >&2
                return 1
            fi
            tok="${PLUGIN_ORDER[idx-1]}"
        fi
        if [ -z "${PLUGIN_APP[$tok]:-}" ]; then
            echo "Ошибка: неизвестный плазмоид: $tok" >&2
            return 1
        fi
        if [ -z "${seen[$tok]:-}" ]; then
            seen[$tok]=1
            echo "$tok"
        fi
    done
}

ask_interactive() {
    local selection=""
    if command -v whiptail >/dev/null 2>&1 && [ -r /dev/tty ] && [ -w /dev/tty ] \
        && [ -n "${TERM:-}" ] && [ "$TERM" != "dumb" ]; then
        local -a items=()
        local p
        for p in "${PLUGIN_ORDER[@]}"; do
            items+=("$p" "${PLUGIN_KIND[$p]}: ${PLUGIN_DESC[$p]}" "OFF")
        done
        if selection="$(whiptail --title "Плазмоиды Win11" \
            --checklist "Выберите плазмоиды для установки (Space — отметить):" \
            22 78 7 "${items[@]}" 3>&1 1>&2 2>&3)"; then
            selection="$(printf '%s' "$selection" | tr -d '"')"
            normalize_selection $selection
            return 0
        fi
        echo "whiptail не сработал (TERM=$TERM) — текстовое меню." >&2
    fi

    [ -r /dev/tty ] || fail "нет интерактивного терминала: используйте --all или --only <список>"
    {
        echo "Доступные плазмоиды:"
        local p i=1
        for p in "${PLUGIN_ORDER[@]}"; do
            printf '  %d) %-22s [%s] %s\n' "$i" "$p" "${PLUGIN_KIND[$p]}" "${PLUGIN_DESC[$p]}"
            i=$((i + 1))
        done
    } >&2
    local answer
    printf 'Введите номера через запятую (например 1,3), «all» — все, «q» — выход: ' >&2
    read -r answer < /dev/tty || return 1
    case "$answer" in
        q|Q|"") return 1 ;;
        all|ALL|"*") normalize_selection "${PLUGIN_ORDER[@]}"; return 0 ;;
    esac
    answer="${answer//,/ }"
    normalize_selection $answer
}

# Проверка внешних утилит для выбранных плазмоидов.
check_deps() {
    local -a need=()
    local p
    for p in "$@"; do
        case "${PLUGIN_KIND[$p]}" in
            C++) need+=(cmake c++) ;;
            QML) need+=(kpackagetool6 msgfmt) ;;
        esac
    done
    local -A uniq=()
    local t missing=()
    for t in "${need[@]}"; do
        [ -n "${uniq[$t]:-}" ] && continue
        uniq[$t]=1
        command -v "$t" >/dev/null 2>&1 || missing+=("$t")
    done
    if ((${#missing[@]})); then
        echo "Не найдены утилиты: ${missing[*]}" >&2
        echo "Установите их (pacman) и повторите." >&2
        exit 1
    fi
}

install_one() {
    local p="$1"
    local dir="$REPO_ROOT/$p"
    local script="$dir/scripts/install-local.sh"
    [ -d "$dir" ] || fail "нет каталога $dir"
    [ -x "$script" ] || fail "нет исполняемого скрипта $script"

    local -a args=(--no-restart)
    if [ "${PLUGIN_KIND[$p]}" = "C++" ] && [ "$BUILD" = 0 ]; then
        args+=(--no-build)
    fi

    echo
    echo "==> ${p} (${PLUGIN_KIND[$p]}, ${PLUGIN_APP[$p]})"
    if PREFIX="$PREFIX" "$script" "${args[@]}"; then
        echo "==> ${p}: установлен"
        return 0
    fi
    echo "==> ${p}: ОШИБКА установки" >&2
    return 1
}

# --- разбор аргументов -------------------------------------------------------
while (($#)); do
    case "$1" in
        --list) MODE="list" ;;
        --all) MODE="all" ;;
        --only)
            shift
            (($#)) || fail "--only требует список плазмоидов"
            MODE="only"
            IFS=', ' read -r -a _parts <<<"$1"
            ONLY+=("${_parts[@]}")
            ;;
        --only=*)
            MODE="only"
            IFS=', ' read -r -a _parts <<<"${1#--only=}"
            ONLY+=("${_parts[@]}")
            ;;
        --no-build) BUILD=0 ;;
        --no-restart) RESTART=0 ;;
        -h|--help) usage; exit 0 ;;
        *) fail "неизвестный аргумент: $1 (см. --help)" ;;
    esac
    shift
done

if [ "$MODE" = "list" ]; then
    list_plugins
    exit 0
fi

declare -a SELECTED=()
sel_out=""
case "$MODE" in
    all) SELECTED=("${PLUGIN_ORDER[@]}") ;;
    only)
        sel_out="$(normalize_selection "${ONLY[@]}")" || exit 2
        mapfile -t SELECTED <<<"$sel_out"
        ;;
    "")
        sel_out="$(ask_interactive)" || { echo "Отменено."; exit 0; }
        mapfile -t SELECTED <<<"$sel_out"
        ;;
esac

((${#SELECTED[@]})) || { echo "Ничего не выбрано."; exit 0; }

echo "К установке: ${SELECTED[*]}"
check_deps "${SELECTED[@]}"

ok=0; bad=0
for p in "${SELECTED[@]}"; do
    if install_one "$p"; then ok=$((ok + 1)); else bad=$((bad + 1)); fi
done

if [ "$RESTART" = 1 ] && [ "$ok" -gt 0 ]; then
    echo
    echo "==> Перезапуск plasmashell"
    systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null || true
    systemctl --user restart plasma-plasmashell.service
    sleep 2
fi

echo
echo "Итог: установлено $ok, ошибок $bad"
[ "$bad" = 0 ] || exit 1
