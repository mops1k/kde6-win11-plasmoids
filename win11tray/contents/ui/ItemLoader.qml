/*
    SPDX-FileCopyrightText: 2020 Konrad Materka <materka@gmail.com>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick

Loader {
    required property int index
    required property int effectiveStatus
    required property var model

    // Правда, когда делегат лежит в поповере скрытых значков. Раньше признак
    // выводился только из effectiveStatus, но после появления лимита панели
    // (maxVisibleIcons) в поповер попадают и активные значки — они тоже должны
    // рисоваться плиткой.
    property bool inHiddenLayout: false

    z: x + 1 // always be above what it's on top of, even for x==0

    // Идентификатор элемента трея — нужен для перетаскивания (закрепить,
    // скрыть, переставить): панель и поповер собирают по нему порядок иконок.
    readonly property string itemId: model && model.itemId !== undefined ? String(model.itemId) : ""

    readonly property url __url: {
        if (model.itemType === "Plasmoid" && model.hasApplet) {
            return Qt.resolvedUrl("PlasmoidItem.qml")
        } else if (model.itemType === "StatusNotifier") {
            return Qt.resolvedUrl("StatusNotifierItem.qml")
        }
        else if (model.itemType === "BackgroundApp") {
            return Qt.resolvedUrl("BackgroundAppItem.qml")
        }
        console.warn("SystemTray ItemLoader: Invalid state, cannot determine source!")
        return ""
    }

    // Avoid relying on context properties using initialProperties with bindings.
    // See https://bugreports.qt.io/browse/QTBUG-125070
    on__UrlChanged: {
        setSource(__url, {
            index: Qt.binding(() => index),
            status: Qt.binding(() => (model && model.status !== undefined) ? model.status : 0),
            effectiveStatus: Qt.binding(() => effectiveStatus),
            model: Qt.binding(() => model),
            inHiddenLayout: Qt.binding(() => inHiddenLayout),
        });
    }
}
