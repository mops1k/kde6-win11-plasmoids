/*
    SPDX-FileCopyrightText: 2016 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2020 Konrad Materka <materka@gmail.com>
    SPDX-FileCopyrightText: 2020 Nate Graham <nate@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window

import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

// Сетка скрытых значков: пять в ряд, как в Windows 11. Собрана на GridView —
// как панель, — поэтому живая перестановка во время перетаскивания работает:
// соседние плитки разъезжаются, а делегаты не пересоздаются. У Repeater с
// GridLayout порядок приходилось применять только при отпускании: модель
// пересобирала плитки, и перетаскивание обрывалось.
Item {
    id: hiddenTasksView

    // Число колонок в ряду. Число рядов — по числу значков.
    readonly property int maxColumns: 5
    // Плитка ровно по размеру иконки трея, зазор — такой же, как в панели
    // (настройка «Интервал» трея, iconSpacing).
    readonly property int cellSize: root.itemSize
    readonly property int cellSpacing: Kirigami.Units.smallSpacing * Plasmoid.configuration.iconSpacing
    // Шаг сетки: место под иконку плюс интервал. Сама плитка занимает только
    // cellSize и прижимается к левому краю ячейки — поэтому интервал между
    // иконками ровно cellSpacing, а не размазан по ячейке.
    readonly property int cellStep: cellSize + cellSpacing

    readonly property int itemCount: hiddenGrid.count
    readonly property int visibleColumns: Math.max(1, Math.min(maxColumns, itemCount))
    readonly property int rowCount: itemCount > 0 ? Math.ceil(itemCount / visibleColumns) : 0

    // Размер поповера под содержимое, как в Windows 11: ширина — под фактическое
    // число колонок (1–5), высота — под число рядов. Хвостового интервала справа
    // и снизу нет: сетка GridView шире на один cellSpacing, но эта полоса пустая.
    readonly property int gridContentWidth: itemCount > 0 ? visibleColumns * cellSize + (visibleColumns - 1) * cellSpacing : 0
    readonly property int gridContentHeight: itemCount > 0 ? rowCount * cellSize + (rowCount - 1) * cellSpacing : 0

    width: gridContentWidth
    height: gridContentHeight
    implicitWidth: gridContentWidth
    implicitHeight: gridContentHeight

    // Сортировка и обмен с панелью при перетаскивании внутри поповера.
    property string draggedId: ""
    property int lastIndex: -1
    // Последняя позиция курсора в системе сетки, снятая при движении: на
    // отпускании координаты приходят испорченными (плитка уже переставлена).
    property real lastX: 0
    property real lastY: 0

    // Индекс плитки под точкой (координаты — в системе этой сетки). Считаем так
    // же, как в панели: место падения и подсветка должны совпадать.
    function cellIndexAt(x, y) {
        if (itemCount <= 0) {
            return 0;
        }
        const col = Math.max(0, Math.min(visibleColumns, Math.floor((x + cellStep / 2) / cellStep)));
        const row = Math.max(0, Math.floor((y + cellStep / 2) / cellStep));
        return Math.max(0, Math.min(itemCount, row * visibleColumns + col));
    }

    // Настоящие id значков поповера в порядке модели (из C++: строковая роль в
    // QML отдаёт отображаемое имя, а не id).
    function hiddenIds() {
        return Plasmoid.popupItemIds ? Plasmoid.popupItemIds() : [];
    }

    // Курсор вне окна поповера — значит, значок тянут в панель. Сравниваем с
    // прямоугольником окна, а не с размером сетки: сетка занимает лишь часть
    // окна (поля темы), и по её высоте бросок внутри поповера считался выходом.
    // Окно берём через привязанное свойство Window.window: у Item нет своего
    // свойства window.
    function isOutsideWindow(x, y) {
        const win = Window.window;
        if (!win) {
            return false;
        }
        const origin = mapFromItem(win.contentItem, 0, 0);
        return x < origin.x || y < origin.y
            || x > origin.x + win.width || y > origin.y + win.height;
    }

    function itemMovedAt(id, x, y) {
        if (draggedId !== id) {
            draggedId = id;
            // Пока курсор на текущей позиции значка, порядок не трогаем.
            lastIndex = hiddenIds().indexOf(id);
        }
        lastX = x;
        lastY = y;

        ghost.visible = true;
        ghost.x = x - ghost.width / 2;
        ghost.y = y - ghost.height / 2;

        const index = cellIndexAt(x, y);
        const cell = Math.min(index, Math.max(0, itemCount - 1));
        ghostHighlight.visible = true;
        ghostHighlight.x = (cell % visibleColumns) * cellStep;
        ghostHighlight.y = Math.floor(cell / visibleColumns) * cellStep;

        if (index !== lastIndex) {
            lastIndex = index;
            // Живая перестановка: соседние плитки разъезжаются сразу.
            root.popupItemReordered(id, index);
        }
    }

    function itemDroppedAt(id) {
        ghost.visible = false;
        ghostHighlight.visible = false;
        draggedId = "";
        const targetId = id;
        const targetIndex = lastIndex;
        lastIndex = -1;
        if (!targetId) {
            return;
        }
        if (isOutsideWindow(lastX, lastY)) {
            root.popupItemToPanel(targetId);
            return;
        }
        // Порядок уже применён живьём; здесь закрепляем финальный индекс.
        if (targetIndex >= 0) {
            root.popupItemReordered(targetId, targetIndex);
        }
    }

    GridView {
        id: hiddenGrid

        // Ширина ровно в visibleColumns шагов: по ней GridView и определяет
        // число колонок (свойства columns у GridView в Qt 6 больше нет).
        width: hiddenTasksView.visibleColumns * hiddenTasksView.cellStep
        height: hiddenTasksView.rowCount * hiddenTasksView.cellStep

        cellWidth: hiddenTasksView.cellStep
        cellHeight: hiddenTasksView.cellStep
        interactive: false
        flow: GridView.LeftToRight

        model: root.hiddenModel

        delegate: ItemLoader {
            width: hiddenTasksView.cellSize
            height: hiddenTasksView.cellSize
            inHiddenLayout: true
            Accessible.role: Accessible.ListItem
        }
    }

    // «Значок в руке» и подсветка места падения внутри поповера.
    Rectangle {
        id: ghost
        visible: false
        z: 9998
        width: hiddenTasksView.cellSize
        height: hiddenTasksView.cellSize
        radius: Kirigami.Units.smallSpacing * 2
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.22)
        border.width: 1
        border.color: Kirigami.Theme.highlightColor
    }

    Rectangle {
        id: ghostHighlight
        visible: false
        z: 9997
        width: hiddenTasksView.cellSize
        height: hiddenTasksView.cellSize
        radius: Kirigami.Units.smallSpacing * 2
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
        border.width: 1
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.18)
    }
}
