/*
    SPDX-FileCopyrightText: 2011 Marco Martin <mart@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg
import org.kde.plasma.core as PlasmaCore

KSvg.FrameSvgItem {
    id: currentItemHighLight

    property int location

    property bool animationEnabled: true
    property var highlightedItem: null

    // Пределы размера подсветки (обычно — размер иконки). Нужны потому, что
    // к ширине делегата добавляются отступы контейнера, а делегат уже шире
    // иконки на настройку интервала между иконками: при малом интервале фон
    // выделения наезжал на соседние иконки. -1 — без предела.
    property real maxHighlightWidth: -1
    property real maxHighlightHeight: -1

    property var containerMargins: {
        let item = currentItemHighLight;
        while (item.parent) {
            item = item.parent;
            if (item.isAppletContainer) {
                return item.getMargins;
            }
        }
        return undefined;
    }

    z: -1 // always draw behind icons

    imagePath: "widgets/tabbar"
    prefix: {
        let prefix;
        switch (location) {
        case PlasmaCore.Types.LeftEdge:
            prefix = "west-active-tab";
            break;
        case PlasmaCore.Types.TopEdge:
            prefix = "north-active-tab";
            break;
        case PlasmaCore.Types.RightEdge:
            prefix = "east-active-tab";
            break;
        default:
            prefix = "south-active-tab";
        }
        if (!hasElementPrefix(prefix)) {
            prefix = "active-tab";
        }
        return prefix;
    }

    // update when System Tray is expanded - applet activated or hidden icons shown
    Connections {
        target: systemTrayState

        function onActiveAppletChanged() {
            Qt.callLater(currentItemHighLight.updateHighlightedItem);
        }

        function onExpandedChanged() {
            Qt.callLater(currentItemHighLight.updateHighlightedItem);
        }
    }

    // update when applet changes parent (e.g. moves from active to hidden icons)
    Connections {
        target: systemTrayState.activeApplet

        function onParentChanged() {
            Qt.callLater(updateHighlightedItem);
        }
    }

    // update when System Tray size changes
    Connections {
        target: parent

        function onWidthChanged() {
            Qt.callLater(updateHighlightedItem);
        }

        function onHeightChanged() {
            Qt.callLater(updateHighlightedItem);
        }
    }

    // update when scale of newly added tray item changes (check 'add' animation in GridView in main.qml)
    Connections {
        target: !!currentItemHighLight.highlightedItem && currentItemHighLight.highlightedItem.parent ? currentItemHighLight.highlightedItem.parent : null

        function onScaleChanged() {
            Qt.callLater(currentItemHighLight.updateHighlightedItem);
        }
    }

    function updateHighlightedItem() {
        if (systemTrayState.expanded) {
            if (systemTrayState.activeApplet && systemTrayState.activeApplet.parent && systemTrayState.activeApplet.parent.inVisibleLayout) {
                changeHighlightedItem(systemTrayState.activeApplet.parent.container, /*forceEdgeHighlight*/false);
            } else { // 'Show hidden items' popup
                changeHighlightedItem(parent, /*forceEdgeHighlight*/true);
            }
        } else {
            highlightedItem = null;
        }
        currentItemHighLight.opacity = systemTrayState.expanded ? 1 : 0
    }

    function changeHighlightedItem(nextItem, forceEdgeHighlight) {
        // do not animate the first appearance
        // or when the property value of a highlighted item changes
        if (!highlightedItem || (highlightedItem === nextItem)) {
            animationEnabled = false;
        }

        const p = parent.mapFromItem(nextItem, 0, 0);
        if (containerMargins && (parent.oneRowOrColumn || forceEdgeHighlight)) {
            x = p.x - containerMargins('left', /*returnAllMargins*/true);
            y = p.y - containerMargins('top', /*returnAllMargins*/true);
            width = nextItem.width + containerMargins('left', /*returnAllMargins*/true) + containerMargins('right', /*returnAllMargins*/true);
            height = nextItem.height + containerMargins('bottom', /*returnAllMargins*/true) + containerMargins('top', /*returnAllMargins*/true);
        } else {
            x = p.x;
            y = p.y;
            width = nextItem.width;
            height = nextItem.height;
        }

        // Подсветка не должна выходить за иконку и наезжать на соседние:
        // ограничиваем размер и центрируем её по элементу. Для edge-highlight
        // (подсветка всей области поповера) ограничение не применяется.
        if (!forceEdgeHighlight) {
            if (maxHighlightWidth > 0 && width > maxHighlightWidth) {
                const centerX = p.x + nextItem.width / 2;
                width = maxHighlightWidth;
                x = Math.round(centerX - width / 2);
            }
            if (maxHighlightHeight > 0 && height > maxHighlightHeight) {
                const centerY = p.y + nextItem.height / 2;
                height = maxHighlightHeight;
                y = Math.round(centerY - height / 2);
            }
        }

        highlightedItem = nextItem;
        animationEnabled = true;
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Kirigami.Units.shortDuration
            easing.type: systemTrayState.expanded ? Easing.OutCubic : Easing.InCubic
        }
    }
    // Позиция и размер подсветки меняются мгновенно: при быстром переключении
    // между элементами анимация «догоняла» и подсветка выглядела съехавшей
    // и разного размера.
}
