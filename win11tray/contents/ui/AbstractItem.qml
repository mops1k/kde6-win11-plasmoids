/*
    SPDX-FileCopyrightText: 2016 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2020 Konrad Materka <materka@gmail.com>
    SPDX-FileCopyrightText: 2020 Nate Graham <nate@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmaCore.ToolTipArea {
    id: abstractItem

    required property int index
    required property var model
    required property int status
    required property int effectiveStatus

    required property string itemId
    /*required*/ property alias text: label.text

    // subclasses need to bind these tooltip properties
    required mainText
    required subText
    required textFormat

    readonly property alias iconContainer: iconContainer
    // Признак плитки поповера задаёт делегат (HiddenItemsView). Раньше он
    // выводился только из effectiveStatus, но после появления лимита панели
    // (maxVisibleIcons) в поповере лежат и активные значки.
    property bool inHiddenLayout: false
    readonly property bool inPopupLayout: inHiddenLayout || effectiveStatus === PlasmaCore.Types.PassiveStatus
    readonly property bool inVisibleLayout: !inPopupLayout

    property bool effectivePressed: false
    // Значок, который тянут, приглушается: его «копия» едет за мышкой.
    property bool dimmed: false
    opacity: dimmed ? 0.3 : 1
    Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }

    // Порядок наложения MouseArea относительно содержимого делегата.
    // Для иконок приложений (SNI) в панели MouseArea остаётся под содержимым,
    // а делегаты-плазмоиды переопределяют это на 1 (см. PlasmoidItem.qml),
    // иначе апплет перехватывает события и перетаскивание не начинается.
    property int mouseAreaZ: abstractItem.inPopupLayout ? 1 : 0

    // Keep these in sync with HiddenItems.qml
    readonly property int margins: Kirigami.Units.smallSpacing
    readonly property int maxTextLines: 2

    // input agnostic way to trigger the main action
    signal activated(var pos)

    // proxy signals for MouseArea
    signal clicked(var mouse)
    signal pressed(var mouse)
    signal wheel(var wheel)
    signal contextMenu(var mouse)

    PulseAnimation {
        targetItem: iconContainer
        running: (abstractItem.status === PlasmaCore.Types.NeedsAttentionStatus
                || abstractItem.status === PlasmaCore.Types.RequiresAttentionStatus)
            && Kirigami.Units.longDuration > 0
    }

    // Источник Drag and Drop: mime-тип application/x-mops1k-systray-item со
    // значением itemId. Принимают панель (закрепить/переставить) и поповер
    // скрытых значков (скрыть) — см. main.qml и ExpandedRepresentation.qml.
    // «Значок в руке» рисуется в main.qml (dragGhost) и двигается по координатам
    // мыши: Qt-Drag здесь элемент не перемещал, значок оставался на месте.
    Item {
        id: dragProxy
    }

    MouseArea {
        id: mouseArea
        propagateComposedEvents: true
        // This needs to be above applets when it's in the grid hidden area
        // so that it can receive hover events while the mouse is over an applet,
        // but below them on regular systray, so collapsing works
        z: abstractItem.mouseAreaZ
        anchors.fill: abstractItem
        hoverEnabled: true

        // Перетаскивание иконки внутри трея: считаем сами по mouse-событиям.
        // Qt-DnD здесь не срабатывал — drop не подтверждался, значок оставался
        // на месте, а индикатор уезжал за пределы трея.
        property real pressX: 0
        property real pressY: 0
        property bool dragging: false
        readonly property int dragThreshold: 8
        // id значка фиксируем на нажатии: во время перетаскивания модель
        // переставляется, делегаты переиспользуются, и itemId делегата к
        // моменту броска мог уже указывать на другой значок.
        property string dragItemId: ""

        // Necessary to make the whole delegate area forward all mouse events
        acceptedButtons: Qt.AllButtons
        onClicked: mouse => { abstractItem.clicked(mouse) }
        onPressed: mouse => {
            pressX = mouse.x;
            pressY = mouse.y;
            dragging = false;
            dragItemId = abstractItem.itemId;
            abstractItem.hideImmediately()
            abstractItem.pressed(mouse)
        }
        onPositionChanged: mouse => {
            if (!pressed || mouse.button === Qt.RightButton) {
                return;
            }
            // Порог считаем по расстоянию в двух осях: по одной X перетаскивание
            // в поповере с одним рядом плиток вообще не начиналось.
            const dx = mouse.x - pressX;
            const dy = mouse.y - pressY;
            if (!dragging && Math.sqrt(dx * dx + dy * dy) >= dragThreshold) {
                dragging = true;
            }
            if (dragging && dragItemId) {
                abstractItem.dimmed = true;
                if (abstractItem.inPopupLayout) {
                    // Координаты — в системе сетки скрытых значков. Раньше здесь
                    // были координаты окна поповера: индекс плитки и проверка
                    // «курсор вне поповера» считались по ним и всегда врали.
                    const p = mapToItem(root.hiddenLayout, mouse.x, mouse.y);
                    root.popupItemDragMoved(dragItemId, p.x, p.y);
                } else {
                    const pos = root.mapFromItem(mouseArea, mouse.x, mouse.y);
                    root.itemDragMoved(dragItemId, pos.x, pos.y);
                }
            }
        }
        // Завершение перетаскивания. Когда курсор уходит за пределы окна, Qt
        // теряет grab и присылает onCanceled вместо onReleased — поэтому
        // завершение обрабатывается в обоих случаях. Координаты отпускания не
        // передаём: к этому моменту делегат уже переставлен, и mapFromItem
        // возвращает мусор (в логе было rootX=-1027 при курсоре внутри трея) —
        // панель и поповер используют последнюю позицию, снятую при движении.
        function finishDrag() {
            if (dragging && dragItemId) {
                if (abstractItem.inPopupLayout) {
                    root.popupItemDragReleased(dragItemId);
                } else {
                    root.itemDragReleased(dragItemId);
                }
            }
            dragging = false;
            dragItemId = "";
            abstractItem.dimmed = false;
        }

        onReleased: finishDrag()
        onCanceled: finishDrag()
        onPressAndHold: mouse => {
            if (mouse.button === Qt.LeftButton) {
                abstractItem.contextMenu(mouse)
            }
        }
        onWheel: wheel => {
            abstractItem.wheel(wheel);
            //Don't accept the event in order to make the scrolling by mouse wheel working
            //for the parent scrollview this icon is in.
            wheel.accepted = false;
        }
    }

    // Плитка поповера: собственного фона нет — значок лежит на фоне окна,
    // подсветка появляется только при наведении, как в Windows 11.
    Rectangle {
        visible: abstractItem.inPopupLayout
        anchors.fill: parent
        radius: Kirigami.Units.smallSpacing * 2
        color: {
            if (mouseArea.containsPress)
                return Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12);
            if (mouseArea.containsMouse)
                return Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08);
            return "transparent";
        }
        Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
        z: -1
    }

    ColumnLayout {
        anchors.fill: abstractItem
        spacing: 0

        FocusScope {
            id: iconContainer
            scale: (abstractItem.effectivePressed || mouseArea.containsPress) ? 0.8 : 1
            opacity: dragProxy.Drag.active ? 0.4 : 1
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }

            activeFocusOnTab: !abstractItem.inPopupLayout
            focus: true // Required in HiddenItemsView so keyboard events can be forwarded to this item
            Accessible.name: abstractItem.text
            Accessible.description: abstractItem.subText
            Accessible.role: Accessible.Button
            Accessible.onPressAction: abstractItem.activated(Plasmoid.popupPosition(iconContainer, iconContainer.width/2, iconContainer.height/2));

            Behavior on scale {
                ScaleAnimator {
                    duration: Kirigami.Units.longDuration
                    easing.type: (abstractItem.effectivePressed || mouseArea.containsPress) ? Easing.OutCubic : Easing.InCubic
                }
            }

            Keys.onPressed: event => {
                switch (event.key) {
                    case Qt.Key_Space:
                    case Qt.Key_Enter:
                    case Qt.Key_Return:
                    case Qt.Key_Select:
                        abstractItem.activated(Qt.point(width/2, height/2));
                        break;
                    case Qt.Key_Menu:
                        abstractItem.contextMenu(null);
                        event.accepted = true;
                        break;
                }
            }

            property alias container: abstractItem
            property alias inVisibleLayout: abstractItem.inVisibleLayout
            readonly property int size: root.itemSize

            // Как в Windows 11: и в панели, и в плитке поповера иконка по центру.
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            implicitWidth: root.vertical && abstractItem.inVisibleLayout ? abstractItem.width : size
            implicitHeight: !root.vertical && abstractItem.inVisibleLayout ? abstractItem.height : size
        }

        PlasmaComponents3.Label {
            id: label

            Layout.fillWidth: true
            maximumLineCount: abstractItem.maxTextLines

            // В плитках поповера подписи нет — только иконка, как в Windows 11.
            visible: false

            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignBottom
            elide: Text.ElideRight
            textFormat: Text.PlainText
            wrapMode: Text.Wrap

            font.pixelSize: 10
        }
    }
}
