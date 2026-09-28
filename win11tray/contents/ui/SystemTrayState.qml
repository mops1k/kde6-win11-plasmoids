/*
    SPDX-FileCopyrightText: 2020 Konrad Materka <materka@gmail.com>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

//This object contains state of the SystemTray, mainly related to the 'expanded' state
QtObject {
    id: systemTrayState
    //true if System Tray is 'expanded'. It may be when:
    // - there is an active applet or
    // - 'Status and Notification' with hidden items is shown
    property bool expanded: false
    //set when there is an applet selected
    property Item activeApplet

    // Сводный поповер быстрых настроек (плитки и слайдеры, ActionPanel):
    // открывается кликом по значку системного ряда или по свободной области
    // ряда. Взаимоисключающ с activeApplet и activePage.
    property bool quickSettings: false

    // Имя страницы модуля, открытой из сводного поповера стрелочкой у плитки
    // ("network", "volume", "brightness", "battery", "bluetooth", ...). Пусто —
    // страница не открыта. Показывается напрямую из наших компонентов, без
    // Plasmoid.appletForPluginId.
    property string activePage: ""

    //allow expanded change only when activated at least once
    //this is to suppress expanded state change during Plasma startup
    property bool acceptExpandedChange: false

    // These properties allow us to keep track of where the expanded applet
    // was and is on the panel, allowing PlasmoidPopupContainer.qml to animate
    // depending on their locations.
    property int oldVisualIndex: -1
    property int newVisualIndex: -1

    // Откуда открыта страница модуля: из сводного поповера (тогда «назад»
    // возвращает в плитки) или из значка трея (тогда «назад» закрывает).
    property bool pageFromQuickSettings: false

    // Время последнего закрытия сводного поповера: нужно, чтобы повторный клик
    // по значку не открывал поповер заново (клик по панели сам деактивирует
    // окно поповера ещё до обработки клика).
    property double quickSettingsClosedAt: 0

    // Сводный поповер быстрых настроек: клик по значку системного ряда или по
    // свободной области ряда.
    function openQuickSettings() {
        activeApplet = null
        activePage = ""
        pageFromQuickSettings = false
        quickSettings = true
        expanded = true
    }

    // Клик по значку системного ряда: открыть сводный поповер, а при повторном
    // клике — закрыть.
    function toggleQuickSettings() {
        if (quickSettings || (Date.now() - quickSettingsClosedAt) < 400) {
            quickSettings = false
            activePage = ""
            pageFromQuickSettings = false
            expanded = false
            quickSettingsClosedAt = 0
            return
        }
        openQuickSettings()
    }

    // Страница модуля из сводного поповера (стрелочка у плитки).
    function openPage(name) {
        if (!name) {
            return
        }
        pageFromQuickSettings = quickSettings
        quickSettings = false
        activeApplet = null
        activePage = name
        expanded = true
    }

    // «Назад» со страницы модуля.
    function pageBack() {
        activePage = ""
        if (pageFromQuickSettings) {
            pageFromQuickSettings = false
            quickSettings = true
            return
        }
        if (activeApplet) {
            setActiveApplet(null)
            return
        }
        expanded = false
    }

    function setActiveApplet(applet, visualIndex) {

        // Активация значка трея вытесняет наши режимы поповера.
        if (applet) {
            quickSettings = false
            activePage = ""
            pageFromQuickSettings = false
        }

        // Applets which prefer to always show their full
        // representation will always be expanded, there's
        // no need to activate them.
        if (applet && applet.preferredRepresentation == applet.fullRepresentation) return;

        if (visualIndex === undefined) {
            oldVisualIndex = -1
            newVisualIndex = -1
        } else {
            oldVisualIndex = (activeApplet && activeApplet.status === PlasmaCore.Types.PassiveStatus) ? 9999 : newVisualIndex
            newVisualIndex = visualIndex
        }

        const oldApplet = activeApplet
        if (applet && !applet.preferredRepresentation) {
            applet.expanded = true;
        }
        if (!applet || !applet.preferredRepresentation) {
            activeApplet = applet;
        }

        if (oldApplet && oldApplet !== applet) {
            oldApplet.expanded = false
        }

        if (applet && !applet.preferredRepresentation) {
            expanded = true
        }
    }

    onExpandedChanged: {
        if (expanded) {
            Plasmoid.status = PlasmaCore.Types.RequiresAttentionStatus
        } else {
            Plasmoid.status = PlasmaCore.Types.PassiveStatus;
            if (quickSettings) {
                quickSettingsClosedAt = Date.now()
            }
            quickSettings = false
            activePage = ""
            pageFromQuickSettings = false
            if (activeApplet) {
                // if not expanded we don't have an active applet anymore
                activeApplet.expanded = false
                activeApplet = null
            }
        }
        acceptExpandedChange = false
        root.expanded = expanded
    }

    //listen on SystemTray AppletInterface signals
    readonly property Connections plasmoidConnections: Connections {
        target: Plasmoid
        //emitted when activation is requested, for example by using a global keyboard shortcut
        function onActivated() {
            systemTrayState.acceptExpandedChange = true
        }
    }

    readonly property Connections rootConnections: Connections {
        function onExpandedChanged() {
            if (systemTrayState.acceptExpandedChange) {
                systemTrayState.expanded = root.expanded
            } else {
                root.expanded = systemTrayState.expanded
            }
        }
    }

    readonly property Connections activeAppletConnections: Connections {
        target: systemTrayState.activeApplet

        function onExpandedChanged() {
            if (systemTrayState.activeApplet && !systemTrayState.activeApplet.expanded) {
                systemTrayState.expanded = false
            }
        }
    }
}
