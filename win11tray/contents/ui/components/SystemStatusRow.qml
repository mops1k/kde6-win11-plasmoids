/*
    SPDX-FileCopyrightText: 2026 mops1k
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.plasma.private.battery
import org.kde.plasma.private.brightnesscontrolplugin
import org.kde.plasma.private.volume as Vol

import "../js/funcs.js" as Funcs

// Ряд системных значков в панели, как в Windows 11: сеть, звук, яркость,
// батарея. Клик по значку открывает сводный поповер быстрых настроек —
// страницы модулей открываются стрелочками у плиток внутри него.
Item {
    id: root

    property int iconSize: Kirigami.Units.iconSizes.smallMedium
    property bool showNetwork: true
    property bool showVolume: true
    property bool showBrightness: true
    property bool showBattery: true

    // Отступ от области значков трея: в Windows 11 группа системных значков
    // отделена от значков приложений заметным промежутком, иначе всё
    // сливается в одно. Внутри самого ряда отступ маленький и фиксированный
    // (StatusIcon.iconPadding), настройка «Spacing» трея на ряд не влияет.
    property real leadingGap: Kirigami.Units.largeSpacing * 2

    // Имя значка, по которому кликнули ("network", "volume", "brightness",
    // "battery"), либо пустая строка при клике по свободной области ряда.
    signal iconClicked(string name)
    signal emptyAreaClicked()

    // Внутренняя раскладка не зеркалится: ряд всегда идёт слева направо
    // (сеть, звук, яркость, батарея), а промежуток — всегда со стороны трея.
    // childrenInherit обязателен: без него RowLayout наследует зеркалирование
    // от панели трея и leftMargin превращается в правый — отступ уезжает
    // в конец апплета, к часам, вместо промежутка между треем и рядом.
    LayoutMirroring.enabled: false
    LayoutMirroring.childrenInherit: true

    implicitWidth: leadingGap + row.implicitWidth
    implicitHeight: row.implicitHeight

    PlasmaNM.ConnectionIcon {
        id: connectionIcon
    }
    ScreenBrightnessControl {
        id: brightnessControl
    }

    BatteryControlModel {
        id: batteryControl
    }

    // Свободная область ряда (если между значками есть место) тоже открывает
    // сводный поповер.
    MouseArea {
        anchors.fill: parent
        onClicked: root.emptyAreaClicked()
    }

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.leftMargin: root.leadingGap
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        StatusIcon {
            name: "network"
            visible: root.showNetwork
            iconSize: root.iconSize
            source: connectionIcon.connectionIcon
            onClicked: root.iconClicked(name)
        }

        StatusIcon {
            name: "volume"
            visible: root.showVolume
            iconSize: root.iconSize
            source: Funcs.volIconName(sink ? sink.volume : 0, sink ? sink.muted : true)
            onClicked: root.iconClicked(name)

            readonly property var sink: Vol.PreferredDevice.sink
        }

        StatusIcon {
            name: "brightness"
            visible: root.showBrightness && brightnessControl.isBrightnessAvailable
            iconSize: root.iconSize
            source: "brightness-high-symbolic"
            onClicked: root.iconClicked(name)
        }

        StatusIcon {
            name: "battery"
            visible: root.showBattery && batteryControl.hasBatteries
            iconSize: root.iconSize
            onClicked: root.iconClicked(name)

            BatteryIcon {
                // Батарея чуть меньше остальных значков: её корпус занимает
                // почти всю ширину ячейки, из-за чего она выглядела крупнее.
                anchors.centerIn: parent
                width: Math.round(root.iconSize * 0.8)
                height: width
                percent: batteryControl.percent
                charging: batteryControl.pluggedIn
            }
        }
    }
}
