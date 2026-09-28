/*
    SPDX-FileCopyrightText: 2026 mops1k
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Shapes

import org.kde.kirigami as Kirigami

// Рисованная иконка батареи: контур цветом темы, заливка по уровню заряда,
// число процента внутри и молния при зарядке.
Item {
    id: root

    property int percent: 0
    property bool charging: false
    property bool showPercent: true
    property bool useLevelColors: true
    property color colorHigh: "#1e9e4a"
    property color colorMedium: "#c9a227"
    property color colorLow: "#c0392b"
    property int thresholdLow: 20
    property int thresholdMedium: 50
    property bool showChargingBolt: true
    property real fontSizePt: 0

    readonly property int clampedPercent: Math.max(0, Math.min(100, Math.round(percent)))
    readonly property color fillColor: {
        if (!useLevelColors) {
            return Kirigami.Theme.textColor;
        }
        if (clampedPercent <= thresholdLow) {
            return colorLow;
        }
        if (clampedPercent <= thresholdMedium) {
            return colorMedium;
        }
        return colorHigh;
    }
    readonly property bool showBolt: charging && showChargingBolt

    // Корпус батареи — прямоугольник с закруглением, справа носик.
    // Пропорция 1.5 (а не 1.85): корпус выше, поэтому цифра внутри крупнее.
    readonly property real capWidth: Math.max(1.5, height * 0.1)
    readonly property real bodyWidth: Math.min(width - capWidth, height * 1.5)
    readonly property real bodyHeight: Math.min(height, bodyWidth / 1.5)
    readonly property real borderWidth: Math.max(1, Math.round(bodyHeight * 0.1))

    Rectangle {
        id: body

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -root.capWidth / 2
        width: root.bodyWidth
        height: root.bodyHeight
        radius: height * 0.25
        color: "transparent"
        border.width: root.borderWidth
        border.color: Kirigami.Theme.textColor

        Rectangle {
            id: fill

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: root.borderWidth
            width: Math.max(0, (body.width - 2 * root.borderWidth) * root.clampedPercent / 100)
            radius: Math.max(0, body.radius - root.borderWidth)
            color: root.fillColor
        }
    }

    Rectangle {
        id: cap

        anchors.verticalCenter: body.verticalCenter
        anchors.left: body.right
        anchors.leftMargin: Math.max(1, root.capWidth * 0.3)
        width: root.capWidth
        height: body.height * 0.45
        radius: width / 2
        color: Kirigami.Theme.textColor
    }

    Text {
        id: label

        anchors.centerIn: body
        // Число занимает почти весь корпус, а не только внутреннюю область заливки.
        width: body.width - 2
        height: body.height - 2
        visible: root.showPercent && !root.showBolt
        text: root.clampedPercent
        color: Kirigami.Theme.textColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.pointSize: root.fontSizePt > 0 ? root.fontSizePt : Kirigami.Theme.defaultFont.pointSize
        font.bold: true
        // Тонкая обводка цветом фона панели: цифра читается и на цветной заливке.
        style: Text.Outline
        styleColor: Kirigami.Theme.backgroundColor
        // Число должно помещаться в узкой ячейке панели.
        fontSizeMode: Text.Fit
        minimumPointSize: 4
    }

    Shape {
        id: bolt

        anchors.centerIn: body
        width: body.height * 0.6
        height: body.height * 0.84
        visible: root.showBolt
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: Kirigami.Theme.textColor
            strokeColor: "transparent"
            startX: bolt.width * 0.62
            startY: 0
            PathLine { x: bolt.width * 0.1; y: bolt.height * 0.56 }
            PathLine { x: bolt.width * 0.44; y: bolt.height * 0.56 }
            PathLine { x: bolt.width * 0.32; y: bolt.height }
            PathLine { x: bolt.width * 0.9; y: bolt.height * 0.42 }
            PathLine { x: bolt.width * 0.56; y: bolt.height * 0.42 }
            PathLine { x: bolt.width * 0.62; y: 0 }
        }
    }
}
