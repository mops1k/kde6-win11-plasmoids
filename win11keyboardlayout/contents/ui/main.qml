/*
    SPDX-FileCopyrightText: 2026 mops1k
    SPDX-License-Identifier: GPL-3.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasmoid
import org.kde.plasma.workspace.keyboardlayout 1.0 as KB

import "LayoutCodes.js" as LayoutCodes

PlasmoidItem {
    id: root

    readonly property var currentNames: switcher.layoutsList[switcher.layout]
    readonly property string layoutCode: currentNames
        ? LayoutCodes.codeFor(currentNames.shortName, Plasmoid.configuration.uppercase)
        : ""
    readonly property string layoutFullName: currentNames
        ? (currentNames.displayName || currentNames.longName || currentNames.shortName)
        : ""

    toolTipMainText: i18n("Keyboard layout")
    toolTipSubText: layoutFullName

    KB.KeyboardLayout {
        id: switcher
    }

    compactRepresentation: Item {
        id: compact

        Text {
            id: codeLabel

            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: root.layoutCode
            color: Plasmoid.configuration.useCustomColor
                ? Plasmoid.configuration.textColor
                : Kirigami.Theme.textColor
            font.family: Plasmoid.configuration.fontFamily.length > 0
                ? Plasmoid.configuration.fontFamily
                : Kirigami.Theme.defaultFont.family
            font.pointSize: Plasmoid.configuration.fontSizePt > 0
                ? Plasmoid.configuration.fontSizePt
                : Kirigami.Theme.defaultFont.pointSize
            font.bold: Plasmoid.configuration.bold
            font.italic: Plasmoid.configuration.italic
            // Ячейка апплета в трее квадратная, поэтому заданный размер — это
            // максимум: при нехватке места код ужимается, а не исчезает.
            fontSizeMode: Text.Fit
            minimumPointSize: 4
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: switcher.switchToNextLayout()
            onWheel: wheel => {
                if (wheel.angleDelta.y > 0) {
                    switcher.switchToPreviousLayout();
                } else {
                    switcher.switchToNextLayout();
                }
            }
        }
    }

    fullRepresentation: Item {
        implicitWidth: Kirigami.Units.gridUnit * 15
        implicitHeight: layoutsColumn.implicitHeight + Kirigami.Units.largeSpacing * 2

        ColumnLayout {
            id: layoutsColumn

            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: i18n("Keyboard layouts")
                font.bold: true
            }

            Repeater {
                model: switcher.layoutsList

                PlasmaComponents3.ItemDelegate {
                    id: layoutDelegate

                    required property int index
                    required property var modelData

                    Layout.fillWidth: true
                    text: (modelData.displayName || modelData.longName || modelData.shortName)
                        + " — " + LayoutCodes.codeFor(modelData.shortName, Plasmoid.configuration.uppercase)
                    highlighted: switcher.layout === index
                    onClicked: {
                        switcher.layout = index;
                        root.expanded = false;
                    }
                }
            }
        }
    }
}
