/*
    SPDX-FileCopyrightText: 2026 mops1k
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick

import org.kde.plasma.plasma5support as Plasma5Support

import "../lib" as Lib
import "../js/displaymodes.js" as DisplayModes

// Плитка управления мониторами в сводном поповере быстрых настроек: показывает
// текущий режим вывода (аналог плитки «Проецировать» в Windows 11). Клик и
// стрелочка ведут на страницу «Дисплей» с выбором режима.
Lib.SplitTile {
    id: tile

    property string mode: "pc"

    function modeTitle(mode) {
        switch (mode) {
        case "duplicate":
            return i18nc("@item:label Display mode: same image on all screens", "Duplicate")
        case "extend":
            return i18nc("@item:label Display mode: screens form one desktop", "Extend")
        case "second":
            return i18nc("@item:label Display mode: only the external screen", "Second screen only")
        default:
            return i18nc("@item:label Display mode: only the built-in screen", "PC screen only")
        }
    }

    label: i18nc("@item:label Quick settings tile opening the display mode page", "Display")
    iconSource: DisplayModes.modeIcon(tile.mode)
    active: tile.mode === "duplicate" || tile.mode === "extend"
    tooltipText: i18nc("@info:tooltip Quick settings tile, %1 is the current display mode", "Display — %1", tile.modeTitle(tile.mode))

    Plasma5Support.DataSource {
        id: kscreenSource
        engine: "executable"
        connectedSources: []
        interval: 5000

        onNewData: function (sourceName, data) {
            const parsed = DisplayModes.parseState(data["stdout"] || "");
            if (parsed) {
                tile.mode = parsed.mode;
            }
        }

        function refresh() {
            if (connectedSources.indexOf(DisplayModes.QUERY) === -1) {
                connectSource(DisplayModes.QUERY);
            }
        }
    }

    Component.onCompleted: kscreenSource.refresh()
}
