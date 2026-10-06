/*
    SPDX-FileCopyrightText: 2026 mops1k
    SPDX-License-Identifier: GPL-3.0-or-later

    Режимы вывода мониторов (аналог «Проецирования» в Windows 11) поверх
    kscreen-doctor. Здесь только логика: разбор `kscreen-doctor -j` и сборка
    атомарной команды применения режима. Тексты и иконки — в QML.
*/
.pragma library

// KScreen::Output::Type::Panel (см. kscreen output.h и поле "type" в JSON).
const PANEL_TYPE = 7
const QUERY = "kscreen-doctor -j"

// Логический размер выхода: физические пиксели, делённые на масштаб
// (kscreen-doctor -j отдаёт size и scale, geometry в JSON нет).
function logicalWidth(output) {
    const scale = output.scale > 0 ? output.scale : 1
    return Math.round(output.size.width / scale)
}

// Состояние выходов: main — основной экран (встроенная панель, иначе выход с
// наименьшим priority), others — все остальные подключённые, mode — текущий
// режим вывода.
function parseState(text) {
    let doc
    try {
        doc = JSON.parse(text)
    } catch (e) {
        return null
    }
    if (!doc || !Array.isArray(doc.outputs)) {
        return null
    }

    const connected = doc.outputs.filter(o => o.connected)
    if (connected.length === 0) {
        return null
    }

    let main = connected.find(o => o.type === PANEL_TYPE) || null
    if (!main) {
        main = connected.slice().sort((a, b) => (a.priority || 0) - (b.priority || 0))[0]
    }
    const others = connected.filter(o => o !== main)
    const enabledExternals = others.filter(o => o.enabled)

    let mode = "pc"
    if (main.enabled && enabledExternals.length > 0) {
        const mirrored = enabledExternals.every(o => o.replicationSource === main.id)
        mode = mirrored ? "duplicate" : "extend"
    } else if (!main.enabled && others.some(o => o.enabled)) {
        mode = "second"
    }

    return {
        main: main,
        others: others,
        mode: mode,
        // Зеркалирование/расширение имеют смысл только при встроенном экране:
        // на десктопе с одними внешними выходами остаются «только первый»,
        // «расширить» и «только второй».
        hasSecond: others.length > 0,
        isPanel: main.type === PANEL_TYPE
    }
}

// Иконка режима (Breeze, символические — плитка и страница красят их сами).
function modeIcon(mode) {
    switch (mode) {
    case "duplicate":
        return "edit-duplicate-symbolic"
    case "extend":
        return "preferences-desktop-display"
    case "second":
        return "video-television-symbolic"
    default:
        return "computer-laptop-symbolic"
    }
}

function available(mode, state) {
    if (!state) {
        return false
    }
    if (mode === "pc") {
        return true
    }
    if (!state.hasSecond) {
        return false
    }
    if (mode === "duplicate") {
        return state.isPanel
    }
    return true
}

// Атомарная команда kscreen-doctor для перехода в режим.
function buildCommand(mode, state) {
    if (!state || !state.main || !available(mode, state)) {
        return ""
    }

    const main = state.main
    const others = state.others
    const args = []
    const out = o => "output." + o.name

    switch (mode) {
    case "pc":
        args.push(out(main) + ".enable")
        args.push(out(main) + ".mirror.none")
        others.forEach(o => args.push(out(o) + ".disable"))
        break

    case "duplicate":
        args.push(out(main) + ".enable")
        args.push(out(main) + ".mirror.none")
        others.forEach(o => {
            args.push(out(o) + ".enable")
            args.push(out(o) + ".mirror." + main.name)
        })
        break

    case "extend": {
        args.push(out(main) + ".enable")
        args.push(out(main) + ".mirror.none")
        args.push(out(main) + ".position.0,0")
        let x = logicalWidth(main)
        others.forEach(o => {
            args.push(out(o) + ".enable")
            args.push(out(o) + ".mirror.none")
            args.push(out(o) + ".position." + x + ",0")
            x += logicalWidth(o)
        })
        break
    }

    case "second":
        args.push(out(main) + ".disable")
        others.forEach((o, i) => {
            args.push(out(o) + ".enable")
            args.push(out(o) + ".mirror.none")
            if (i === 0) {
                args.push(out(o) + ".position.0,0")
            }
        })
        break

    default:
        return ""
    }

    return "kscreen-doctor " + args.join(" ")
}
