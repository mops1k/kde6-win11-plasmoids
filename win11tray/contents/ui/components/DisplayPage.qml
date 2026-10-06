/*
    SPDX-FileCopyrightText: 2026 mops1k
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kcmutils

import "../lib" as Lib
import "../js/displaymodes.js" as DisplayModes

// Страница режимов вывода (аналог «Проецирования» в Windows 11): только
// встроенный экран, повторяющийся, расширить, только второй экран. Состояние
// берётся из `kscreen-doctor -j`, режим применяется одной атомарной командой.
Lib.Page {
    id: page

    title: i18nc("@title Display mode page", "Display")
    contentFillsHeight: false

    property var displayState: null
    property bool applying: false

    readonly property var modes: [
        {
            "mode": "pc",
            "icon": "computer-laptop-symbolic",
            "title": i18nc("@item:label Display mode", "PC screen only"),
            "description": i18nc("@info Display mode description", "Use only the built-in screen")
        },
        {
            "mode": "duplicate",
            "icon": "edit-duplicate-symbolic",
            "title": i18nc("@item:label Display mode", "Duplicate"),
            "description": i18nc("@info Display mode description", "Show the same image on all screens")
        },
        {
            "mode": "extend",
            "icon": "preferences-desktop-display",
            "title": i18nc("@item:label Display mode", "Extend"),
            "description": i18nc("@info Display mode description", "Use the screens as one desktop")
        },
        {
            "mode": "second",
            "icon": "video-television-symbolic",
            "title": i18nc("@item:label Display mode", "Second screen only"),
            "description": i18nc("@info Display mode description", "Use only the external screen")
        }
    ]

    function applyMode(mode) {
        if (page.applying || !page.displayState || page.displayState.mode === mode) {
            return;
        }
        const command = DisplayModes.buildCommand(mode, page.displayState);
        if (command === "") {
            return;
        }
        page.applying = true;
        applySource.run(command);
        // Конфигурация применяется асинхронно — перечитываем состояние дважды.
        refreshTimer.restart();
    }

    Plasma5Support.DataSource {
        id: kscreenSource
        engine: "executable"
        connectedSources: []
        interval: 4000

        onNewData: function (sourceName, data) {
            const parsed = DisplayModes.parseState(data["stdout"] || "");
            if (parsed) {
                page.displayState = parsed;
            }
        }

        function refresh() {
            if (connectedSources.indexOf(DisplayModes.QUERY) === -1) {
                connectSource(DisplayModes.QUERY);
            }
        }
    }

    Plasma5Support.DataSource {
        id: applySource
        engine: "executable"
        connectedSources: []

        onNewData: function (sourceName, data) {
            disconnectSource(sourceName);
            page.applying = false;
            kscreenSource.refresh();
        }

        function run(command) {
            connectSource(command);
        }
    }

    Timer {
        id: refreshTimer
        interval: 1200
        repeat: false
        onTriggered: kscreenSource.refresh()
    }

    Component.onCompleted: kscreenSource.refresh()

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 0

        Repeater {
            model: page.modes

            delegate: Item {
                id: modeRow
                required property var modelData

                readonly property bool selected: page.displayState !== null && page.displayState.mode === modeRow.modelData.mode
                readonly property bool modeAvailable: DisplayModes.available(modeRow.modelData.mode, page.displayState)

                Layout.fillWidth: true
                Layout.preferredHeight: 54

                Rectangle {
                    id: modeBackground
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.topMargin: 1
                    anchors.bottomMargin: 1
                    radius: 4
                    color: modeRow.selected
                        ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.15)
                        : (modeMouse.containsMouse
                            ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
                            : "transparent")

                    Behavior on color {
                        ColorAnimation { duration: Kirigami.Units.shortDuration }
                    }
                }

                MouseArea {
                    id: modeMouse
                    anchors.fill: modeBackground
                    hoverEnabled: true
                    cursorShape: modeRow.modeAvailable && !modeRow.selected ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: page.applyMode(modeRow.modelData.mode)
                }

                RowLayout {
                    anchors.fill: modeBackground
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10
                    opacity: modeRow.modeAvailable ? 1 : 0.4

                    Kirigami.Icon {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        Layout.alignment: Qt.AlignVCenter
                        source: modeRow.modelData.icon
                        color: modeRow.selected ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                        isMask: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            text: modeRow.modelData.title
                            color: Kirigami.Theme.textColor
                            font.pixelSize: 11
                            font.bold: modeRow.selected
                            elide: Text.ElideRight
                        }

                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            text: modeRow.modelData.description
                            color: Kirigami.Theme.textColor
                            opacity: 0.5
                            font.pixelSize: 9
                            elide: Text.ElideRight
                        }
                    }

                    Kirigami.Icon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        Layout.alignment: Qt.AlignVCenter
                        visible: modeRow.selected
                        source: "checkmark-symbolic"
                        color: Kirigami.Theme.highlightColor
                        isMask: true
                    }
                }
            }
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            Layout.topMargin: 8
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            visible: page.displayState === null
            wrapMode: Text.WordWrap
            text: i18nc("@info Display mode page", "Could not read the display configuration.")
            color: Kirigami.Theme.textColor
            opacity: 0.6
            font.pixelSize: 10
        }
    }

    footer: Lib.MoreSettingsLink {
        text: i18nc("@action:button Open the KDE display settings module", "Display settings")
        onClicked: KCMLauncher.openSystemSettings("kcm_kscreen")
    }
}
