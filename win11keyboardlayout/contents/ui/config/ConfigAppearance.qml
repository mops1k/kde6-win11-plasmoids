/*
    SPDX-FileCopyrightText: 2026 mops1k
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Dialogs

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: root

    property alias cfg_fontSizePt: sizeSpin.value
    property alias cfg_bold: boldCheck.checked
    property alias cfg_italic: italicCheck.checked
    property alias cfg_uppercase: uppercaseCheck.checked
    property alias cfg_useCustomColor: customColorCheck.checked
    property string cfg_fontFamily: Plasmoid.configuration.fontFamily
    property color cfg_textColor: Plasmoid.configuration.textColor

    Kirigami.FormLayout {
        anchors.fill: parent

        PlasmaComponents3.ComboBox {
            id: familyCombo

            Kirigami.FormData.label: i18n("Font family:")

            readonly property var families: [""].concat(Qt.fontFamilies())
            model: families
            currentIndex: Math.max(0, families.indexOf(root.cfg_fontFamily))
            onActivated: root.cfg_fontFamily = families[currentIndex]
            displayText: currentIndex === 0 ? i18n("Default (from Plasma theme)") : currentText
        }

        PlasmaComponents3.SpinBox {
            id: sizeSpin

            Kirigami.FormData.label: i18n("Font size:")
            from: 0
            to: 96
            stepSize: 1
            editable: true
            textFromValue: (value, locale) => value === 0 ? i18n("From theme") : value + " pt"
            valueFromText: (text, locale) => parseInt(text) || 0
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        PlasmaComponents3.CheckBox {
            id: boldCheck
            text: i18n("Bold")
        }

        PlasmaComponents3.CheckBox {
            id: italicCheck
            text: i18n("Italic")
        }

        PlasmaComponents3.CheckBox {
            id: uppercaseCheck
            text: i18n("Upper case code (РУС, ENG)")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        PlasmaComponents3.CheckBox {
            id: customColorCheck
            text: i18n("Custom text color")
        }

        Row {
            Kirigami.FormData.label: i18n("Text color:")
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                width: Kirigami.Units.gridUnit * 2
                height: Kirigami.Units.gridUnit
                color: root.cfg_textColor
                border.width: 1
                border.color: Kirigami.Theme.disabledTextColor
            }

            PlasmaComponents3.Button {
                text: i18n("Choose…")
                enabled: root.cfg_useCustomColor
                onClicked: colorDialog.open()
            }
        }
    }

    ColorDialog {
        id: colorDialog
        title: i18n("Text color")
        selectedColor: root.cfg_textColor
        onAccepted: root.cfg_textColor = selectedColor
    }
}
