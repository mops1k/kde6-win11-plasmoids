/*
    SPDX-FileCopyrightText: 2026 mops1k
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick

import org.kde.kirigami as Kirigami

// Значок системного ряда в панели: иконка темы с подсветкой при наведении,
// как у значков Windows 11. Содержимое можно подменить через default property
// (так в ряд ставится рисованная иконка батареи). Тултип не показывается:
// подсказки у системных значков панели Windows 11 не появляются.
Item {
    id: root

    property string name
    property string source
    property int iconSize: Kirigami.Units.iconSizes.smallMedium
    // Маленький фиксированный отступ вокруг значка: он не берётся из
    // настройки «Spacing» трея, чтобы значки статусной строки стояли плотно.
    property int iconPadding: Math.max(1, Math.round(Kirigami.Units.smallSpacing / 2))

    default property alias content: holder.data

    signal clicked

    implicitWidth: iconSize + 2 * iconPadding
    implicitHeight: implicitWidth

    Kirigami.Icon {
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        visible: root.source !== ""
        source: root.source
        isMask: true
        color: Kirigami.Theme.textColor
    }

    // Место для своего содержимого (например BatteryIcon).
    Item {
        id: holder
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
