#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 mops1k
# SPDX-License-Identifier: GPL-3.0-or-later
#
# panel-floating.sh — режим «плавающей» панели Plasma 6.
#
# В Plasma 6 панель может открепляться от края экрана, когда её ничто не
# перекрывает (на рабочем столе), и прилипать обратно при развёрнутых окнах.
# Из-за этого поповеры панельных апплетов встают вплотную к видимой части
# панели и заезжают на апплет. Скрипт прикрепляет панель к краям экрана
# (off) или возвращает авто-открепление (on).
#
# Состояние хранится в ~/.config/plasma-org.kde.plasma.desktop-appletsrc,
# группа [PlasmaViews][Panel <id>], ключ floating (0/1) — PanelView::setFloating()
# пишет и читает его оттуда (plasma-workspace shell/panelview.cpp).

set -euo pipefail

SERVICE="org.kde.plasmashell"
PATH_OBJ="/PlasmaShell"
IFACE="org.kde.PlasmaShell"
APPLETSRC="${HOME}/.config/plasma-org.kde.plasma.desktop-appletsrc"

PANEL="all"
PERSIST=1
DRY_RUN=0
COMMAND=""

usage() {
    cat <<'EOF'
Использование: panel-floating.sh [команда] [опции]

Команды:
  status   показать режим панелей (по умолчанию)
  off      прикрепить панель к краям экрана (floating=false)
  on       вернуть авто-открепление на рабочем столе (floating=true)
  toggle   переключить текущий режим

Опции:
  --panel <id|all>  какую панель менять (по умолчанию all)
  --no-persist      только применить сейчас, не писать в appletsrc
  --dry-run         показать, что будет сделано, и выйти
  -h, --help        эта справка

Без --no-persist настройка сохраняется в appletsrc: plasmashell на время
останавливается, ключ floating пишется в [PlasmaViews][Panel <id>], затем
plasmashell запускается снова (файл конфига копируется в .bak).
EOF
}

die() { printf 'panel-floating: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

plasma_eval() {
    qdbus6 "${SERVICE}" "${PATH_OBJ}" "${IFACE}.evaluateScript" "$1"
}

# Выражение для фильтра панелей внутри JS.
panel_filter_js() {
    if [[ "${PANEL}" == "all" ]]; then
        printf 'true'
    else
        printf 'ps[i].id == %s' "${PANEL}"
    fi
}

# Список id панелей, разделённый переводом строки.
panel_ids() {
    plasma_eval 'var ps = panels(); var out = []; for (var i = 0; i < ps.length; i++) { out.push(ps[i].id); } print(out.join("\n"));'
}

cmd_status() {
    local out
    out=$(plasma_eval 'var ps = panels(); var out = []; for (var i = 0; i < ps.length; i++) { out.push(ps[i].id + " " + (ps[i].floating ? "floating" : "attached")); } print(out.join("\n"));')
    [[ -n "${out}" ]] || die "не удалось получить список панелей (plasmashell запущен?)"
    while read -r id state; do
        [[ -n "${id}" ]] || continue
        if [[ "${PANEL}" != "all" && "${id}" != "${PANEL}" ]]; then
            continue
        fi
        if [[ "${state}" == "floating" ]]; then
            printf 'панель %s: откреплена (floating)\n' "${id}"
        else
            printf 'панель %s: прикреплена к краю экрана\n' "${id}"
        fi
    done <<<"${out}"
}

# Текущее состояние панелей в виде «id state».
panel_state() {
    plasma_eval 'var ps = panels(); var out = []; for (var i = 0; i < ps.length; i++) { out.push(ps[i].id + " " + (ps[i].floating ? "floating" : "attached")); } print(out.join("\n"));'
}

# Применяет значение (0/1) или инвертирует его (toggle) через D-Bus.
apply_live() {
    local mode="$1" assign
    if [[ "${mode}" == "toggle" ]]; then
        assign='ps[i].floating = !ps[i].floating'
    else
        assign="ps[i].floating = ${mode}"
    fi
    local js
    js="var ps = panels(); var out = []; for (var i = 0; i < ps.length; i++) { if ($(panel_filter_js)) { var was = ps[i].floating; ${assign}; out.push(ps[i].id + \" \" + (was ? \"floating\" : \"attached\") + \" -> \" + (ps[i].floating ? \"floating\" : \"attached\")); } } print(out.join(\"\n\"));"
    local out
    out=$(plasma_eval "${js}")
    [[ -n "${out}" ]] || die "не удалось изменить режим панели"
    while read -r id change; do
        [[ -n "${id}" ]] || continue
        printf 'панель %s: %s\n' "${id}" "${change}"
    done <<<"${out}"
}

# Пишет ключ floating в appletsrc при остановленном plasmashell.
persist() {
    local mode="$1"
    [[ -f "${APPLETSRC}" ]] || die "не найден ${APPLETSRC}"
    have kwriteconfig6 || die "нужен kwriteconfig6"
    local ids
    ids=$(panel_ids)
    [[ -n "${ids}" ]] || die "не удалось получить список панелей"

    local backup
    backup="${APPLETSRC}.panel-floating-bak-$(date +%Y%m%d-%H%M%S)"
    cp -a "${APPLETSRC}" "${backup}"
    printf 'бэкап конфига: %s\n' "${backup}"

    systemctl --user stop plasma-plasmashell.service || true
    local id
    while read -r id; do
        [[ -n "${id}" ]] || continue
        if [[ "${PANEL}" != "all" && "${id}" != "${PANEL}" ]]; then
            continue
        fi
        kwriteconfig6 --file "${APPLETSRC}" --group PlasmaViews --group "Panel ${id}" --key floating "${mode}"
        printf 'записано: [PlasmaViews][Panel %s] floating=%s\n' "${id}" "${mode}"
    done <<<"${ids}"

    systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null || true
    systemctl --user start plasma-plasmashell.service
    printf 'plasmashell перезапущен\n'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        status|off|on|toggle)
            COMMAND="$1"
            shift
            ;;
        --panel)
            [[ $# -ge 2 ]] || die "для --panel нужен id панели или all"
            PANEL="$2"
            shift 2
            ;;
        --panel=*)
            PANEL="${1#*=}"
            shift
            ;;
        --no-persist)
            PERSIST=0
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "неизвестный аргумент: $1 (см. --help)"
            ;;
    esac
done

[[ -n "${COMMAND}" ]] || COMMAND="status"

have qdbus6 || die "нужен qdbus6"

if [[ "${DRY_RUN}" -eq 1 ]]; then
    printf 'команда: %s, панель: %s, persist: %s\n' "${COMMAND}" "${PANEL}" "${PERSIST}"
    exit 0
fi

case "${COMMAND}" in
    status)
        cmd_status
        ;;
    off|on)
        [[ "${COMMAND}" == "off" ]] && mode=0 || mode=1
        apply_live "${mode}"
        if [[ "${PERSIST}" -eq 1 ]]; then
            persist "${mode}"
            cmd_status
        fi
        ;;
    toggle)
        apply_live toggle
        if [[ "${PERSIST}" -eq 1 ]]; then
            # После применения читаем фактическое состояние и фиксируем его.
            local_state=$(panel_state)
            mode=""
            while read -r id state; do
                [[ -n "${id}" ]] || continue
                if [[ "${PANEL}" != "all" && "${id}" != "${PANEL}" ]]; then
                    continue
                fi
                if [[ "${state}" == "floating" ]]; then
                    mode=1
                else
                    mode=0
                fi
                break
            done <<<"${local_state}"
            [[ -n "${mode}" ]] || die "не удалось определить состояние панели"
            persist "${mode}"
            cmd_status
        fi
        ;;
esac
