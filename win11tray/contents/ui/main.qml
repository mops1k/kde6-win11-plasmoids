/*
    SPDX-FileCopyrightText: 2011 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2020 Konrad Materka <materka@gmail.com>
    SPDX-FileCopyrightText: 2026 Nathaniel Krebs <areyoufeelingitnowmrkrebs@gmail.com>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window

import org.kde.draganddrop as DnD
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import org.kde.ksvg as KSvg
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

import "js/systrayorder.js" as SystrayOrder
import "components" as Components

ContainmentItem {
    id: root

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool reverseLayout: Plasmoid.configuration.reverseIconOrder

    Layout.minimumWidth: vertical ? Kirigami.Units.iconSizes.small : mainLayout.implicitWidth + Kirigami.Units.smallSpacing
    Layout.minimumHeight: vertical ? mainLayout.implicitHeight + Kirigami.Units.smallSpacing : Kirigami.Units.iconSizes.small

    LayoutMirroring.enabled: !vertical && ((Application.layoutDirection === Qt.RightToLeft) !== reverseLayout)
    LayoutMirroring.childrenInherit: true

    readonly property alias systemTrayState: systemTrayState
    readonly property alias itemSize: tasksGrid.itemSize
    readonly property alias visibleLayout: tasksGrid
    readonly property alias hiddenLayout: expandedRepresentation.hiddenLayout

    // Тот же флаг, что и у LayoutMirroring.enabled ниже: при нём визуальный
    // порядок значков обратен порядку модели.
    readonly property bool mirrorIcons: !vertical && ((Application.layoutDirection === Qt.RightToLeft) !== reverseLayout)
    readonly property bool oneRowOrColumn: tasksGrid.rowsOrColumns === 1

    // Визуальный порядок элементов трея слева направо: шеврон, значки SNI, ряд
    // системных значков. При зеркальной раскладке колонки GridLayout
    // отображаются в обратном порядке, поэтому индексы переворачиваем — иначе
    // ряд уезжает влево от шеврона.
    function columnFor(visualIndex) {
        return mirrorIcons ? (2 - visualIndex) : visualIndex;
    }

    // Ряд системных значков нужен, только если включён хотя бы один значок.
    readonly property bool showStatusRow: Plasmoid.configuration.showStatusNetwork
        || Plasmoid.configuration.showStatusVolume
        || Plasmoid.configuration.showStatusBrightness
        || Plasmoid.configuration.showStatusBattery

    // Разбиение на панель и поповер делает C++ (SortedSystemTrayModel::Panel и
    // ::Popup) с учётом настройки «Максимум иконок в панели»: в панель попадает
    // не больше лимита активных значков, в поповер — пассивные и вытесненные.
    readonly property var activeModel: Plasmoid.panelSystemTrayModel
    readonly property var hiddenModel: Plasmoid.popupSystemTrayModel

    // Геометрия для прижатия поповера к правому краю экрана. Позицию окна панели
    // берём у самого окна (win.x) и переводим апплет в его систему через
    // mapToItem к contentItem — это отображение внутри одного окна, без
    // неоднозначностей; правый край экрана — Screen.virtualX + Screen.width.
    readonly property point windowScenePos: {
        const win = Window.window;
        return win ? root.mapToItem(win.contentItem, 0, 0) : Qt.point(0, 0);
    }
    readonly property real appletGlobalX: {
        const win = Window.window;
        return win ? win.x + root.windowScenePos.x : 0;
    }
    readonly property real screenRightX: Screen.virtualX + Screen.width
    // Ширина окна поповера: пока окно не показано, dialog.width равен нулю,
    // поэтому до этого берём ширину содержимого.
    readonly property real popupWindowWidth: dialog.width > 0 ? dialog.width : expandedRepresentation.width

    // --- Перетаскивание иконок (поведение как в Windows 11) ------------------
    // Бросил иконку в панель — закреплена в панели; бросил в поповер скрытых
    // значков — скрыта; бросил между иконками панели — место запоминается и
    // сохраняется, когда приложение снова открывается.

    // Все известные id (панель + поповер) в порядке моделей. Берём их из C++
    // по числовой роли: в QML model.data(index, "itemId") строку роли превращает
    // в Qt::DisplayRole и отдаёт отображаемое имя («Громкость» вместо
    // org.kde.plasma.volume), из-за чего записанный порядок не совпадал с тем,
    // по чему сортирует C++, и перестановки не применялись.
    function visibleItemIds() {
        return Plasmoid.panelItemIds ? Plasmoid.panelItemIds() : [];
    }

    function hiddenItemIds() {
        return Plasmoid.popupItemIds ? Plasmoid.popupItemIds() : [];
    }

    function knownItemIds() {
        return visibleItemIds().concat(hiddenItemIds());
    }

    // Индекс вставки по координате x в системе tasksGrid. Считаем по размеру
    // ячейки: во время перетаскивания itemAtIndex отдаёт ещё не размещённые
    // делегаты (x = 0, ширина 0), из-за чего индекс всегда был последним.
    function insertionIndexAt(gridX) {
        const count = tasksGrid.count;
        if (count <= 0) {
            return 0;
        }
        const cellW = Math.max(1, tasksGrid.cellWidth);
        // floor, а не round: округление вверх сдвигало место вставки на значок
        // вправо, и значок «переезжал через одну».
        return Math.max(0, Math.min(count, Math.floor((gridX + cellW / 2) / cellW)));
    }

    // При зеркальном порядке значков (панель «слева направо») визуальный левый
    // край панели — это правый край в порядке модели, поэтому координату мыши
    // переворачиваем относительно ширины самой сетки значков.
    function trayX(itemX) {
        return mirrorIcons ? tasksGrid.width - itemX : itemX;
    }

    // --- Перетаскивание значков трея (своё, по mouse-событиям) ---------------
    // Qt-DnD не подтверждал drop: значок оставался на месте, а индикатор
    // уезжал за пределы трея.
    property string draggedItemId: ""

    // Предпросмотр места падения: пока значок тянут, порядок применяется сразу,
    // поэтому остальные значки раздвигаются, а плитка показывает, куда он
    // встанет. Последний применённый индекс не повторяем.
    property int lastAppliedIndex: -1

    // Последняя позиция курсора в системе координат апплета, снятая при
    // движении: на отпускании координаты приходят испорченными (делегат уже
    // переставлен живой перестановкой и mapFromItem даёт мусор).
    property real lastDragX: 0
    property real lastDragY: 0

    function itemDragMoved(itemId, x, y) {
        draggedItemId = itemId;
        lastDragX = x;
        lastDragY = y;

        // «Значок в руке» едет за мышью.
        dragGhost.visible = true;
        dragGhost.x = x - dragGhost.width / 2;
        dragGhost.y = y - dragGhost.height / 2;

        const localX = tasksGrid.mapFromItem(dropIndicator.parent, x, 0).x;
        const gridX = trayX(localX);
        const index = insertionIndexAt(gridX);
        dropIndicator.visible = true;
        dropIndicator.updatePosition(gridX);
        if (index !== lastAppliedIndex) {
            lastAppliedIndex = index;
            moveItemTo(itemId, index);
        }
    }

    // Курсор вышел за панель со стороны поповера. Сравниваем с краем панели по
    // той оси, где стоит поповер: панель снизу — выше верхнего края, панель
    // сверху — ниже нижнего и т.д.
    function dragOutsidePanel(x, y) {
        if (vertical) {
            return Plasmoid.location === PlasmaCore.Types.LeftEdge ? x < -4 : x > root.width + 4;
        }
        return Plasmoid.location === PlasmaCore.Types.TopEdge ? y > root.height + 4 : y < -4;
    }

    // Лимит значков в панели следует за действиями пользователя: закрепили
    // значок из поповера — лимит вырос, скрыли в поповер — уменьшился.
    // 0 — «без ограничения»: тогда поповер пуст и менять нечего.
    function bumpVisibleLimit(added) {
        const current = Math.max(0, Plasmoid.maxVisibleIcons ? Plasmoid.maxVisibleIcons() : Plasmoid.configuration.maxVisibleIcons);
        if (current === 0) {
            return;
        }
        const next = Math.max(1, current + added);
        if (Plasmoid.setMaxVisibleIcons) {
            Plasmoid.setMaxVisibleIcons(next);
        } else {
            Plasmoid.configuration.maxVisibleIcons = next;
        }
    }

    // Значок уходит в поповер: переносим его в конец списка поповера и только
    // потом уменьшаем лимит — панель укорачивается ровно на этот значок.
    function sendItemToPopup(itemId) {
        if (!itemId) {
            return;
        }
        SystrayOrder.toPopup(Plasmoid.configuration, visibleItemIds(), hiddenItemIds(), knownItemIds(), itemId);
        bumpVisibleLimit(-1);
        systemTrayState.expanded = true;
    }

    function itemDragReleased(itemId) {
        dropIndicator.visible = false;
        dragGhost.visible = false;
        draggedItemId = "";
        lastAppliedIndex = -1;
        if (!itemId) {
            return;
        }

        const x = lastDragX;
        const y = lastDragY;

        if (dragOutsidePanel(x, y)) {
            sendItemToPopup(itemId);
            return;
        }

        // Обычная сортировка внутри панели: место уже применено живьём, здесь
        // закрепляем финальный индекс.
        moveItemTo(itemId, insertionIndexAt(trayX(tasksGrid.mapFromItem(dropIndicator.parent, x, 0).x)));
    }

    // Перетаскивание значка внутри окна поповера. Координаты приходят в системе
    // сетки скрытых значков (см. AbstractItem.qml).
    function popupItemDragMoved(itemId, x, y) {
        hiddenLayout.itemMovedAt(itemId, x, y);
    }

    function popupItemDragReleased(itemId) {
        // id, который реально тянут, а не тот, что оказался под курсором:
        // id фиксируется при нажатии и сбрасывается при отпускании.
        const realId = draggedItemId || itemId;
        draggedItemId = "";
        hiddenLayout.itemDroppedAt(realId);
    }

    // Перестановка значка внутри поповера: порядок применяется сразу, поэтому
    // соседние плитки разъезжаются прямо во время перетаскивания.
    function popupItemReordered(itemId, index) {
        SystrayOrder.reorderPopup(Plasmoid.configuration, visibleItemIds(), hiddenItemIds(), knownItemIds(), itemId, index);
    }

    // Бросок значка из поповера в панель: переносим его в конец порядка панели
    // и увеличиваем лимит — так в панель вернётся именно тот значок, который
    // тянули. Если это был последний скрытый значок, поповер закрываем.
    function popupItemToPanel(itemId) {
        if (!itemId) {
            return;
        }
        const wasLast = root.hiddenLayout.itemCount <= 1;
        SystrayOrder.toPanel(Plasmoid.configuration, visibleItemIds(), hiddenItemIds(), knownItemIds(), itemId);
        bumpVisibleLimit(1);
        if (wasLast) {
            systemTrayState.expanded = false;
        }
    }

    function moveItemTo(itemId, insertIndex) {
        if (!itemId) {
            return;
        }
        SystrayOrder.reorderPanel(Plasmoid.configuration, visibleItemIds(), hiddenItemIds(), knownItemIds(), itemId, insertIndex);
    }

    Component.onCompleted: {
        // We need all the plasmoiditems to be there for correct working of shortcuts.
        // Instantiators create the plasmoiditems: ensure this is done after
        // this containmentitem actually  exists so they can be immediately parented properly
        // set active and not the model, as this will cause an assert deep in Qt
        activeInstantiator.active = true;
        hiddenInstantiator.active = true;
    }

    Connections {
        target: Plasmoid
        function onActivated() {
            systemTrayState.expanded = !systemTrayState.expanded;
        }
    }

    // Разбиение на панель и поповер делает C++ (SortedSystemTrayModel::Panel и
    // ::Popup) с учётом настройки «Максимум иконок в панели»: в панель попадает
    // не больше лимита активных значков, в поповер — вытесненные лимитом.

    Instantiator {
        id: hiddenInstantiator
        // It's important that those are inactive at creation time
        // to not create plasmoiditems too soon
        active: false
        model: hiddenModel
        delegate: Connections {
            required property QtObject applet
            required property int row
            target: applet
            function onExpandedChanged(expanded: bool) {
                if (expanded) {
                    systemTrayState.setActiveApplet(applet, row)
                }
            }
        }
    }

    Instantiator {
        id: activeInstantiator
        active: false
        model:activeModel
        delegate: Connections {
            required property QtObject applet
            required property int row
            target: applet
            function onExpandedChanged(expanded: bool) {
                if (expanded) {
                    systemTrayState.setActiveApplet(applet, row)
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent

        onWheel: wheel => {
            // Don't propagate unhandled wheel events
            wheel.accepted = true;
        }

        SystemTrayState {
            id: systemTrayState
        }

        CurrentItemHighLight {
            location: Plasmoid.location
            parent: root
            // Предел подсветки — вся ячейка иконки (включая интервал между
            // иконками): иначе при малом интервале фон выделения наезжает
            // на соседние иконки, а по размеру одной иконки выглядит узко.
            maxHighlightWidth: root.vertical ? -1 : tasksGrid.cellWidth
            maxHighlightHeight: root.vertical ? tasksGrid.cellHeight : -1
        }

        DnD.DropArea {
            anchors.fill: parent

            preventStealing: true

            /** Extracts the name of the system tray applet in the drag data if present
            * otherwise returns null*/
            function systemTrayAppletName(event) {
                if (event.mimeData.formats.indexOf("text/x-plasmoidservicename") < 0) {
                    return null;
                }
                const plasmoidId = event.mimeData.getDataAsByteArray("text/x-plasmoidservicename");

                if (!Plasmoid.isSystemTrayApplet(plasmoidId)) {
                    return null;
                }
                return plasmoidId;
            }

            onDragEnter: event => {
                if (draggedSystrayItem(event)) {
                    dropIndicator.visible = true;
                    return;
                }
                if (!systemTrayAppletName(event)) {
                    event.ignore();
                }
            }

            onDragMove: event => {
                if (!draggedSystrayItem(event)) {
                    return;
                }
                dropIndicator.visible = true;
                dropIndicator.updatePosition(tasksGrid.mapFromItem(parent, event.x, event.y).x);
            }

            onDragLeave: dropIndicator.visible = false

            onDrop: event => {
                const itemId = draggedSystrayItem(event);
                if (itemId) {
                    dropIndicator.visible = false;
                    root.moveItemTo(itemId, root.insertionIndexAt(tasksGrid.mapFromItem(parent, event.x, event.y).x));
                    return;
                }

                const plasmoidId = systemTrayAppletName(event);
                if (!plasmoidId) {
                    event.ignore();
                    return;
                }

                if (Plasmoid.configuration.extraItems.indexOf(plasmoidId) < 0) {
                    const extraItems = Plasmoid.configuration.extraItems;
                    extraItems.push(plasmoidId);
                    Plasmoid.configuration.extraItems = extraItems;
                }
            }

            /** Идентификатор перетаскиваемой иконки трея (наш mime-тип) или null. */
            function draggedSystrayItem(event) {
                if (event.mimeData.formats.indexOf("application/x-mops1k-systray-item") < 0) {
                    return null;
                }
                const itemId = event.mimeData.getDataAsByteArray("application/x-mops1k-systray-item");
                return itemId ? String(itemId) : null;
            }
        }

        // Якорь поповера: невидимая точка 1x1 у правого края экрана на высоте
        // шеврона. AppletPopup выравнивает окно по центру visualParent, поэтому
        // центр якоря ставим на половину ширины окна левее правого края экрана —
        // правый край поповера совпадает с правым краем экрана.
        Item {
            id: popupAnchor

            width: 1
            height: 1
            opacity: 0
            x: root.screenRightX - root.appletGlobalX - root.popupWindowWidth / 2
            y: expander.mapToItem(root, 0, 0).y
        }

        // Плитка-подсветка места, куда встанет перетаскиваемая иконка: такая же
        // подсветка, как при наведении на значок в трее.
        Rectangle {
            id: dropIndicator

            visible: false
            z: 999
            width: tasksGrid.cellWidth
            height: tasksGrid.cellHeight
            radius: Kirigami.Units.smallSpacing * 2
            y: Math.round((root.height - height) / 2)
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
            border.width: 1
            border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.18)

            // На вход — координата в порядке модели (уже перевёрнутая на
            // itemDragMoved). Наружу индикатор ставим в визуальную координату:
            // при обратном порядке значков панели они противоположны, иначе
            // палочка уезжала не туда, куда тянули.
            function updatePosition(gridX) {
                // Индекс вставки может быть на единицу больше последней ячейки
                // (бросок в самый конец) — тогда подсвечиваем последнюю ячейку,
                // иначе индикатор уезжает за пределы трея.
                const last = Math.max(0, tasksGrid.count - 1);
                const index = Math.max(0, Math.min(last, root.insertionIndexAt(gridX)));
                const logicalX = index * tasksGrid.cellWidth;
                const visualX = root.mirrorIcons ? tasksGrid.width - logicalX - tasksGrid.cellWidth : logicalX;
                dropIndicator.x = tasksGrid.mapToItem(parent, visualX, 0).x;
            }
        }


        // Значок в руке: едет за мышкой, пока тянут.
        Rectangle {
            id: dragGhost

            visible: false
            z: 9998
            width: tasksGrid.cellWidth
            height: tasksGrid.cellHeight
            radius: Kirigami.Units.smallSpacing * 2
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.22)
            border.width: 1
            border.color: Kirigami.Theme.highlightColor
        }

        //Main Layout
        GridLayout {
            id: mainLayout

            rowSpacing: 0
            columnSpacing: 0
            anchors.fill: parent

            flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight

            GridView {
                id: tasksGrid

                Layout.row: root.vertical && root.reverseLayout ? 1 : 0 // Explicitly define grid coordinates
                Layout.column: root.columnFor(1)                        // to prevent overlapping

                Layout.alignment: Qt.AlignCenter

                interactive: false //disable features we don't need
                flow: root.vertical ? GridView.LeftToRight : GridView.TopToBottom

                // Tell the grid to populate bottom-to-top when flipped on a vertical panel
                verticalLayoutDirection: (root.vertical && root.reverseLayout) ? GridView.BottomToTop : GridView.TopToBottom

                // The icon size to display when not using the auto-scaling setting
                readonly property int smallIconSize: Kirigami.Units.iconSizes.smallMedium

                // Режим размера значков: 0 — по высоте панели, 1 — маленький
                // (smallMedium), 2 — свой размер в пикселях (iconSizeCustom).
                readonly property int sizeMode: Plasmoid.configuration.iconSizeMode
                // «По высоте панели» и «свой размер» рисуют один ряд значков,
                // многострочная раскладка остаётся только у «маленького».
                readonly property bool singleRow: sizeMode !== 1

                readonly property int gridThickness: root.vertical ? root.width : root.height
                // Should change to 2 rows/columns on a 56px panel (in standard DPI)
                readonly property int rowsOrColumns: singleRow ? 1 : Math.max(1, Math.min(count, Math.floor(gridThickness / (smallIconSize + Kirigami.Units.smallSpacing))))

                // Add margins only if the panel is larger than a small icon (to avoid large gaps between tiny icons)
                readonly property int cellSpacing: Kirigami.Units.smallSpacing * Plasmoid.configuration.iconSpacing
                readonly property int smallSizeCellLength: gridThickness < smallIconSize ? smallIconSize : smallIconSize + cellSpacing

                cellHeight: {
                    if (root.vertical) {
                        return singleRow ? itemSize + (gridThickness < itemSize ? 0 : cellSpacing) : smallSizeCellLength
                    } else {
                        return singleRow ? root.height : Math.floor(root.height / rowsOrColumns)
                    }
                }
                cellWidth: {
                    if (root.vertical) {
                        return singleRow ? root.width : Math.floor(root.width / rowsOrColumns)
                    } else {
                        return singleRow ? itemSize + (gridThickness < itemSize ? 0 : cellSpacing) : smallSizeCellLength
                    }
                }

                //depending on the form factor, we are calculating only one dimension, second is always the same as root/parent
                implicitHeight: root.vertical ? cellHeight * Math.ceil(count / rowsOrColumns) : root.height
                implicitWidth: !root.vertical ? cellWidth * Math.ceil(count / rowsOrColumns) : root.width

                readonly property int itemSize: {
                    switch (sizeMode) {
                    case 2: // свой размер в пикселях
                        return Math.max(8, Plasmoid.configuration.iconSizeCustom);
                    case 1: // маленький
                        return smallIconSize;
                    default: // по высоте панели
                        return Kirigami.Units.iconSizes.roundedIconSize(Math.min(Math.min(root.width, root.height) / rowsOrColumns, Kirigami.Units.iconSizes.enormous));
                    }
                }

                model: activeModel

                delegate: ItemLoader {
                    id: delegate

                    width: tasksGrid.cellWidth
                    height: tasksGrid.cellHeight

                    // We need to recalculate the stacking order of the z values due to how keyboard navigation works
                    // the tab order depends exclusively from this, so we redo it as the position in the list
                    // ensuring tab navigation focuses the expected items
                    Component.onCompleted: {
                        let item = tasksGrid.itemAtIndex(index - 1);
                        if (item) {
                            Plasmoid.stackItemBefore(delegate, item)
                        } else {
                            item = tasksGrid.itemAtIndex(index + 1);
                        }
                        if (item) {
                            Plasmoid.stackItemAfter(delegate, item)
                        }
                    }
                }
            }

            ExpanderArrow {
                id: expander

                Layout.row: root.vertical && !root.reverseLayout ? 1 : 0 // Explicitly define grid coordinates
                Layout.column: root.columnFor(0)                         // to prevent overlapping

                Layout.fillWidth: vertical
                Layout.fillHeight: !vertical
                Layout.alignment: vertical ? Qt.AlignVCenter : Qt.AlignHCenter
                iconSize: tasksGrid.itemSize
                visible: root.hiddenLayout.itemCount > 0
            }

            // Ряд системных значков (сеть, звук, яркость, батарея). Клик по
            // значку или по свободной области ряда открывает сводный поповер
            // быстрых настроек, как в Windows 11.
            Components.SystemStatusRow {
                id: systemStatusRow

                Layout.row: 0
                Layout.column: root.columnFor(2)
                Layout.alignment: Qt.AlignCenter
                iconSize: tasksGrid.itemSize
                visible: root.showStatusRow

                showNetwork: Plasmoid.configuration.showStatusNetwork
                showVolume: Plasmoid.configuration.showStatusVolume
                showBrightness: Plasmoid.configuration.showStatusBrightness
                showBattery: Plasmoid.configuration.showStatusBattery
                leadingGap: Plasmoid.configuration.statusGap

                onIconClicked: systemTrayState.toggleQuickSettings()
                onEmptyAreaClicked: systemTrayState.toggleQuickSettings()
                // Пункт «Микшер громкости» контекстного меню значка звука.
                onRequestPage: name => systemTrayState.openPage(name)
            }
        }

        Timer {
            id: expandedSync
            interval: 100
            onTriggered: systemTrayState.expanded = dialog.visible;
        }

        //Main popup
        PlasmaCore.AppletPopup {
            id: dialog
            objectName: "popupWindow"
            // Поповер скрытых значков — по центру шеврона, как в референсе
            // Windows 11; страница апплета (звук, сеть, батарея) — у правого
            // края экрана (см. popupAnchor).
            visualParent: expandedRepresentation.gridMode ? expander : popupAnchor

            popupDirection: switch (Plasmoid.location) {
                case PlasmaCore.Types.TopEdge:
                    return Qt.BottomEdge
                case PlasmaCore.Types.LeftEdge:
                    return Qt.RightEdge
                case PlasmaCore.Types.RightEdge:
                    return Qt.LeftEdge
                default:
                    return Qt.TopEdge
            }
            // Зазор между поповером и панелью: в upstream здесь 0, и поповер
            // выглядел «прилипшим» к панели, а в референсе Windows 11 это
            // отдельная карточка с отступом.
            margin: (Plasmoid.containmentDisplayHints & PlasmaCore.Types.ContainmentPrefersFloatingApplets) ? Kirigami.Units.largeSpacing : Kirigami.Units.smallSpacing * 2

            Behavior on margin {
                NumberAnimation {
                    // Since the panel animation won't be perfectly in sync,
                    // using a duration larger than the panel animation results
                    // in a better-looking animation.
                    duration: Kirigami.Units.veryLongDuration
                    easing.type: Easing.OutCubic
                }
            }

            floating: Plasmoid.location == PlasmaCore.Desktop

            // Скруглённые углы оставляем со стороны панели: поповер отделён от неё
            // зазором (margin), как в референсе. Раньше здесь было ещё и
            // AtPanelEdges, из-за чего сторона, обращённая к панели, шла без
            // скруглений и поповер выглядел «прилипшим».
            removeBorderStrategy: PlasmaCore.AppletPopup.AtScreenEdges


            hideOnWindowDeactivate: !Plasmoid.configuration.pin
            visible: systemTrayState.expanded
            appletInterface: root

            backgroundHints: (Plasmoid.containmentDisplayHints & PlasmaCore.Types.ContainmentPrefersOpaqueBackground) ? PlasmaCore.AppletPopup.SolidBackground : PlasmaCore.AppletPopup.StandardBackground

            onVisibleChanged: {
                if (!visible) {
                    expandedSync.restart();
                } else {
                    dialog.requestActivate();
                    if (expandedRepresentation.plasmoidContainer.visible) {
                        expandedRepresentation.plasmoidContainer.forceActiveFocus();
                    } else if (expandedRepresentation.hiddenLayout.visible) {
                        expandedRepresentation.hiddenLayout.forceActiveFocus();
                    } else if (expandedRepresentation.quickSettingsMode) {
                        expandedRepresentation.quickSettingsLayout.forceActiveFocus();
                    }
                }
            }
            mainItem: ExpandedRepresentation {
                id: expandedRepresentation

                Keys.onEscapePressed: event => {
                    systemTrayState.expanded = false
                }

                // Being there forces the items to fully load, and they will be reparented in the stack one by one, this item is *never* visible
                // it's important this item is parented to the popup, otherwise the full representation will be reparented every time the popup opens or closes
                Item {
                    id: preloadedStorage
                    visible: false
                }

                // Draws a line between the applet dialog and the panel
                KSvg.SvgItem {
                    id: separator
                    // Only draw for popups of panel applets, not desktop applets
                    visible: [PlasmaCore.Types.TopEdge, PlasmaCore.Types.LeftEdge, PlasmaCore.Types.RightEdge, PlasmaCore.Types.BottomEdge]
                        .includes(Plasmoid.location) && !dialog.margin
                    anchors {
                        topMargin: -dialog.topPadding
                        leftMargin: -dialog.leftPadding
                        rightMargin: -dialog.rightPadding
                        bottomMargin: -dialog.bottomPadding
                    }
                    z: 999 /* Draw the line on top of the applet */
                    elementId: (Plasmoid.location === PlasmaCore.Types.TopEdge || Plasmoid.location === PlasmaCore.Types.BottomEdge) ? "horizontal-line" : "vertical-line"
                    imagePath: "widgets/line"
                    // QTBUG-120464: Use AnchorChanges instead of bindings as it's officially supported: https://doc.qt.io/qt-6/qtquick-positioning-anchors.html#changing-anchors
                    states: [
                        State {
                            when: Plasmoid.location === PlasmaCore.Types.TopEdge
                            AnchorChanges {
                                target: separator
                                anchors {
                                    top: separator.parent.top
                                    left: separator.parent.left
                                    right: separator.parent.right
                                }
                            }
                            PropertyChanges {
                                separator.height: 1
                            }
                        },
                        State {
                            when: Plasmoid.location === PlasmaCore.Types.LeftEdge
                            AnchorChanges {
                                target: separator
                                anchors {
                                    left: separator.parent.left
                                    top: separator.parent.top
                                    bottom: separator.parent.bottom
                                }
                            }
                            PropertyChanges {
                                separator.width: 1
                            }
                        },
                        State {
                            when: Plasmoid.location === PlasmaCore.Types.RightEdge
                            AnchorChanges {
                                target: separator
                                anchors {
                                    top: separator.parent.top
                                    right: separator.parent.right
                                    bottom: separator.parent.bottom
                                }
                            }
                            PropertyChanges {
                                separator.width: 1
                            }
                        },
                        State {
                            when: Plasmoid.location === PlasmaCore.Types.BottomEdge
                            AnchorChanges {
                                target: separator
                                anchors {
                                    left: separator.parent.left
                                    right: separator.parent.right
                                    bottom: separator.parent.bottom
                                }
                            }
                            PropertyChanges {
                                separator.height: 1
                            }
                        }
                    ]
                }

                LayoutMirroring.enabled: Application.layoutDirection === Qt.RightToLeft
                LayoutMirroring.childrenInherit: true
            }
        }
    }
}
