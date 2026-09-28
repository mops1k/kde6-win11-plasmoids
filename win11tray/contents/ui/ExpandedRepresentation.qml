/*
    SPDX-FileCopyrightText: 2016 Marco Martin <mart@koyotic.space>
    SPDX-FileCopyrightText: 2020 Nate Graham <nate@kde.org>
    SPDX-FileCopyrightText: 2026 Jeysef

    SPDX-License-Identifier: LGPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid

import "components" as Components

Item {
    id: popup

    // Размер поповера. Как в системном трее: у открытой страницы апплета —
    // квадрат 24x24 gridUnit (в upstream ExpandedRepresentation это
    // Layout.minimumWidth/minimumHeight = Kirigami.Units.gridUnit * 24;
    // значение сверено с установленным плагином org.kde.plasma.systemtray
    // plasma-workspace 6.7.5), внутри страница прокручивается. В режиме сетки
    // скрытых значков — ровно под содержимое (1–5 колонок, столько рядов,
    // сколько нужно).
    readonly property bool quickSettingsMode: systemTrayState.quickSettings && !systemTrayState.activeApplet && systemTrayState.activePage === ""
    readonly property bool pageMode: !quickSettingsMode && (systemTrayState.activePage !== "" || systemTrayState.activeApplet !== null)
    readonly property bool gridMode: !quickSettingsMode && !pageMode
    readonly property real appletPopupSize: Kirigami.Units.gridUnit * 24
    // Сводный поповер быстрых настроек: ширина карточки Win11, высота по
    // содержимому (плитки + слайдеры).
    readonly property real quickSettingsWidth: Kirigami.Units.gridUnit * 20

    implicitWidth: gridMode ? hiddenItemsView.gridContentWidth
                 : quickSettingsMode ? quickSettingsWidth
                 : appletPopupSize
    implicitHeight: gridMode ? hiddenItemsView.gridContentHeight
                  : quickSettingsMode ? Math.max(appletPopupSize, quickSettingsLoader.implicitHeight)
                  : appletPopupSize

    width: implicitWidth
    height: implicitHeight

    Layout.minimumWidth: width
    Layout.maximumWidth: width
    Layout.minimumHeight: height
    Layout.maximumHeight: height

    // Размер окна пересчитывается в main.qml (там виден id dialog): при
    // изменении числа скрытых значков AppletPopup растягивается под сетку.

    property alias hiddenLayout: hiddenItemsView
    property alias plasmoidContainer: container
    property alias quickSettingsLayout: quickSettingsLoader

    readonly property bool themedActive: container.themedActive
    readonly property bool unknownActive: systemTrayState.activeApplet && !popup.themedActive

    // Header — only for unknown (non-themed) applets. Themed pages have their
    // own PageHeader; the action panel is self-contained.
    PlasmaExtras.PlasmoidHeading {
        id: plasmoidHeading
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        visible: popup.unknownActive
        height: trayHeading.height + bottomPadding + container.headingHeight
        Behavior on height {
            NumberAnimation { duration: Kirigami.Units.shortDuration / 2; easing.type: Easing.InOutQuad }
        }
    }

    ColumnLayout {
        id: expandedRepresentation
        anchors.fill: parent
        spacing: plasmoidHeading.visible ? plasmoidHeading.bottomPadding : 0

        // Header content (unknown applets only)
        RowLayout {
            id: trayHeading
            Layout.fillWidth: true
            visible: plasmoidHeading.visible

            PlasmaComponents.ToolButton {
                id: backButton
                visible: systemTrayState.activeApplet && systemTrayState.activeApplet.expanded && (popup.hiddenLayout.itemCount > 0)
                icon.name: mirrored ? "go-previous-symbolic-rtl" : "go-previous-symbolic"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18nc("@action:button", "Go Back")
                KeyNavigation.down: container
                onClicked: if (typeof systemTrayState.activeApplet?.backAction !== "undefined" && systemTrayState.activeApplet.backAction.enabled) {
                    systemTrayState.activeApplet?.backAction.trigger()
                } else {
                    systemTrayState.setActiveApplet(null)
                }
            }

            Kirigami.Heading {
                Layout.fillWidth: true
                leftPadding: 0
                level: 1
                text: systemTrayState.activeApplet ? systemTrayState.activeApplet.plasmoid.title : i18n("Status and Notifications")
                maximumLineCount: 1
                textFormat: Text.PlainText
                elide: Text.ElideRight
            }

            Repeater {
                id: primaryActionButtons
                model: actionsButton.applet ? actionsButton.applet.Plasmoid.contextualActions.filter(a => !a.isSeparator && a.priority === PlasmaCore.Action.HighPriority) : []
                delegate: PlasmaComponents.ToolButton {
                    id: actionButton
                    required property int index
                    required property PlasmaCore.Action modelData
                    property PlasmaCore.Action qAction: modelData
                    visible: qAction && qAction.visible
                    contentItem: Kirigami.Icon {
                        anchors.centerIn: parent
                        active: actionButton.hovered
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        implicitHeight: implicitWidth
                        source: actionButton.qAction ? actionButton.qAction.icon.name : ""
                    }
                    enabled: qAction && qAction.enabled
                    checkable: qAction && qAction.checkable
                    checked: qAction && qAction.checked
                    display: PlasmaComponents.AbstractButton.IconOnly
                    text: qAction ? qAction.text : ""
                    KeyNavigation.down: backButton.KeyNavigation.down
                    KeyNavigation.left: (index > 0) ? primaryActionButtons.itemAt(index - 1) : backButton
                    KeyNavigation.right: (index < primaryActionButtons.count - 1) ? primaryActionButtons.itemAt(index + 1) : actionsButton.visible ? actionsButton : actionsButton.KeyNavigation.right
                    PlasmaComponents.ToolTip { text: actionButton.text }
                    onClicked: if (qAction) qAction.trigger()
                }
            }

            PlasmaComponents.ToolButton {
                id: actionsButton
                visible: visibleActions > 0
                enabled: visibleActions > 1 || (singleAction && singleAction.enabled)
                checked: visibleActions > 1 ? configMenu.status !== PlasmaExtras.Menu.Closed : singleAction && singleAction.checked
                property QtObject applet: systemTrayState.activeApplet || root
                property int visibleActions: actions.length
                property PlasmaCore.Action singleAction: visibleActions === 1 && menuItemFactory.object ? menuItemFactory.object.action : null
                readonly property var actions: applet ? applet.plasmoid.contextualActions.filter(action => {
                    return action.visible && action.priority === PlasmaCore.Action.NormalPriority && action !== applet.plasmoid.internalAction("configure")
                }).reduce((dst, action, i, src) => {
                    if (!action.isSeparator) { const p = src[i - 1]; if (p?.isSeparator && dst.length > 0) dst.push(p); dst.push(action) }
                    return dst
                }, []) : []
                icon.name: "application-menu"
                checkable: visibleActions > 1 || (singleAction && singleAction.checkable)
                contentItem.opacity: visibleActions > 1
                display: PlasmaComponents.AbstractButton.IconOnly
                text: singleAction ? singleAction.text : i18n("More actions")
                Accessible.role: singleAction ? Accessible.Button : Accessible.ButtonMenu
                KeyNavigation.down: backButton.KeyNavigation.down
                KeyNavigation.right: configureButton.visible ? configureButton : configureButton.KeyNavigation.right
                Kirigami.Icon {
                    parent: actionsButton
                    anchors.centerIn: parent
                    active: actionsButton.hovered
                    implicitWidth: Kirigami.Units.iconSizes.smallMedium
                    implicitHeight: implicitWidth
                    source: actionsButton.singleAction !== null ? actionsButton.singleAction.icon.name : ""
                    visible: actionsButton.singleAction
                }
                onToggled: if (visibleActions > 1) { checked ? configMenu.openRelative() : configMenu.close() }
                onClicked: if (singleAction) singleAction.trigger()
                PlasmaComponents.ToolTip { text: actionsButton.text }
                PlasmaExtras.Menu { id: configMenu; visualParent: actionsButton; placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup }
                Instantiator {
                    id: menuItemFactory
                    model: actionsButton.actions
                    delegate: PlasmaExtras.MenuItem { id: menuItem; required property PlasmaCore.Action modelData; action: modelData }
                    onObjectAdded: (index, object) => configMenu.addMenuItem(object)
                    onObjectRemoved: (index, object) => configMenu.removeMenuItem(object)
                }
            }
            PlasmaComponents.ToolButton {
                id: configureButton
                icon.name: "configure"
                visible: actionsButton.applet && actionsButton.applet.plasmoid.internalAction("configure")
                display: PlasmaComponents.AbstractButton.IconOnly
                text: {
                    const a = actionsButton.applet
                    const action = a ? a.plasmoid.internalAction("configure") : null
                    return action ? action.text : ""
                }
                KeyNavigation.down: backButton.KeyNavigation.down
                KeyNavigation.left: actionsButton.visible ? actionsButton : actionsButton.KeyNavigation.left
                KeyNavigation.right: pinButton
                PlasmaComponents.ToolTip { text: parent.visible ? parent.text : "" }
                onClicked: actionsButton.applet.plasmoid.internalAction("configure").trigger()
            }
            PlasmaComponents.ToolButton {
                id: pinButton
                checkable: true
                checked: Plasmoid.configuration.pin
                onToggled: Plasmoid.configuration.pin = checked
                icon.name: "window-pin"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18n("Keep Open")
                KeyNavigation.down: backButton.KeyNavigation.down
                KeyNavigation.left: configureButton.visible ? configureButton : configureButton.KeyNavigation.left
                KeyNavigation.tab: container.currentItem?.nextItemInFocusChain() ?? null
                PlasmaComponents.ToolTip { text: parent.text }
            }
        }

        // Поповер шеврона: сетка скрытых значков (пять в ряд), как в Windows 11.
        ColumnLayout {
            id: actionPanelMode
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: popup.gridMode
            spacing: 0

            HiddenItemsView {
                id: hiddenItemsView
                // Размер сетки явный — не растягиваем её на всё окно.
                Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                Layout.preferredWidth: gridContentWidth
                Layout.preferredHeight: gridContentHeight
                Layout.fillWidth: false
                Layout.fillHeight: false
                visible: root.hiddenLayout.itemCount > 0
                KeyNavigation.up: pinButton
            }
        }

        // Сводный поповер быстрых настроек: плитки Wi-Fi/Bluetooth/… и слайдеры
        // яркости и громкости. Открывается кликом по значку системного ряда или
        // по свободной области ряда; стрелочка у плитки ведёт на страницу
        // модуля (systemTrayState.openPage).
        Loader {
            id: quickSettingsLoader

            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: popup.quickSettingsMode

            sourceComponent: Component {
                ActionPanel {
                    width: popup.quickSettingsWidth
                    onRequestPage: name => systemTrayState.openPage(name)
                }
            }
        }

        // Container for the active applet (themed or unknown) or for a page of
        // one of our modules opened from the quick settings popup.
        PlasmoidPopupsContainer {
            id: container
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: popup.pageMode
            Layout.topMargin: mergeHeadings ? 0 : dialog.topPadding
            KeyNavigation.up: pinButton
            KeyNavigation.backtab: pinButton
            onVisibleChanged: if (visible) forceActiveFocus()
        }
    }

    // Merged PlasmoidHeading footer — only for unknown applets that have one.
    PlasmaExtras.PlasmoidHeading {
        id: plasmoidFooter
        position: PlasmaComponents.ToolBar.Footer
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        visible: popup.unknownActive && container.appletHasFooter
        height: container.footerHeight
        z: -9999
    }

}
