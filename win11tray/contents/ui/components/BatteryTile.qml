/*
    SPDX-FileCopyrightText: 2026 mops1k
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick

import org.kde.plasma.private.battery

import "../lib" as Lib
import "../js/funcs.js" as Funcs

// Плитка электропитания в сводном поповере быстрых настроек: процент заряда и
// состояние, клик и стрелочка ведут на страницу «Батарея» (профили питания,
// ингибирование сна, здоровье батареи).
Lib.SplitTile {
    id: tile

    BatteryControlModel {
        id: batteryControl
    }

    readonly property bool charging: batteryControl.pluggedIn

    visible: batteryControl.hasBatteries
    label: i18nc("@item:label Quick settings tile opening the power management page", "Power")
    iconSource: Funcs.batteryIconName(batteryControl.percent, charging)
    active: charging
    tooltipText: charging
        ? i18nc("@info:tooltip Quick settings tile, %1 is the battery charge in percent", "Power — charging (%1%)", batteryControl.percent)
        : i18nc("@info:tooltip Quick settings tile, %1 is the battery charge in percent", "Power — %1%", batteryControl.percent)
}
