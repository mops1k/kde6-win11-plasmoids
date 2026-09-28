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

    property alias cfg_showPercentage: showPercentCheck.checked
    property alias cfg_useLevelColors: useLevelColorsCheck.checked
    property alias cfg_thresholdLow: thresholdLowSpin.value
    property alias cfg_thresholdMedium: thresholdMediumSpin.value
    property alias cfg_showChargingBolt: showChargingBoltCheck.checked
    property alias cfg_fontSizePt: fontSizeSpin.value
    property color cfg_colorHigh: Plasmoid.configuration.colorHigh
    property color cfg_colorMedium: Plasmoid.configuration.colorMedium
    property color cfg_colorLow: Plasmoid.configuration.colorLow

    Kirigami.FormLayout {
        anchors.fill: parent

        PlasmaComponents3.CheckBox {
            id: showPercentCheck
            text: i18n("Show the charge percentage inside the battery")
        }

        PlasmaComponents3.CheckBox {
            id: showChargingBoltCheck
            text: i18n("Show a lightning bolt instead of the number while charging")
        }

        PlasmaComponents3.SpinBox {
            id: fontSizeSpin

            Kirigami.FormData.label: i18n("Font size:")
            from: 0
            to: 96
            stepSize: 1
            editable: true
            textFromValue: (value, locale) => value === 0 ? i18n("Automatic") : value + " pt"
            valueFromText: (text, locale) => parseInt(text) || 0
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        PlasmaComponents3.CheckBox {
            id: useLevelColorsCheck
            text: i18n("Color the fill by the charge level")
        }

        PlasmaComponents3.SpinBox {
            id: thresholdLowSpin

            Kirigami.FormData.label: i18n("Low threshold:")
            enabled: useLevelColorsCheck.checked
            from: 0
            to: thresholdMediumSpin.value
            stepSize: 5
            editable: true
            textFromValue: (value, locale) => i18nc("@item:valuesuffix charge percentage", "%1%%", value)
            valueFromText: (text, locale) => parseInt(text) || 0
        }

        PlasmaComponents3.SpinBox {
            id: thresholdMediumSpin

            Kirigami.FormData.label: i18n("Medium threshold:")
            enabled: useLevelColorsCheck.checked
            from: thresholdLowSpin.value
            to: 100
            stepSize: 5
            editable: true
            textFromValue: (value, locale) => i18nc("@item:valuesuffix charge percentage", "%1%%", value)
            valueFromText: (text, locale) => parseInt(text) || 0
        }

        Row {
            Kirigami.FormData.label: i18n("Low color:")
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                width: Kirigami.Units.gridUnit * 2
                height: Kirigami.Units.gridUnit
                color: root.cfg_colorLow
                border.width: 1
                border.color: Kirigami.Theme.disabledTextColor
            }

            PlasmaComponents3.Button {
                text: i18n("Choose…")
                enabled: useLevelColorsCheck.checked
                onClicked: lowColorDialog.open()
            }
        }

        Row {
            Kirigami.FormData.label: i18n("Medium color:")
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                width: Kirigami.Units.gridUnit * 2
                height: Kirigami.Units.gridUnit
                color: root.cfg_colorMedium
                border.width: 1
                border.color: Kirigami.Theme.disabledTextColor
            }

            PlasmaComponents3.Button {
                text: i18n("Choose…")
                enabled: useLevelColorsCheck.checked
                onClicked: mediumColorDialog.open()
            }
        }

        Row {
            Kirigami.FormData.label: i18n("High color:")
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                width: Kirigami.Units.gridUnit * 2
                height: Kirigami.Units.gridUnit
                color: root.cfg_colorHigh
                border.width: 1
                border.color: Kirigami.Theme.disabledTextColor
            }

            PlasmaComponents3.Button {
                text: i18n("Choose…")
                enabled: useLevelColorsCheck.checked
                onClicked: highColorDialog.open()
            }
        }
    }

    ColorDialog {
        id: lowColorDialog
        title: i18n("Low charge color")
        selectedColor: root.cfg_colorLow
        onAccepted: root.cfg_colorLow = selectedColor
    }

    ColorDialog {
        id: mediumColorDialog
        title: i18n("Medium charge color")
        selectedColor: root.cfg_colorMedium
        onAccepted: root.cfg_colorMedium = selectedColor
    }

    ColorDialog {
        id: highColorDialog
        title: i18n("High charge color")
        selectedColor: root.cfg_colorHigh
        onAccepted: root.cfg_colorHigh = selectedColor
    }
}
