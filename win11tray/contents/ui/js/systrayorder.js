/*
    SPDX-FileCopyrightText: 2026 mops1k

    SPDX-License-Identifier: GPL-3.0-or-later

    Управление порядком иконок трея (поведение как в Windows 11: иконку можно
    перетащить в панель, в поповер скрытых значков или на другое место в панели).

    Порядок хранится одним списком itemOrder и записывается в явном виде:
    сначала значки панели (в порядке модели), затем значки поповера, затем все
    остальные известные id. Такой список однозначно воспроизводит разбиение:
    панель — первые maxVisibleIcons активных значков, поповер — следующие.
    Привязки-«якоря» по индексам не используются: раньше позиция считалась через
    order.indexOf(сосед), и при несовпадении id значок улетал в конец списка.

    Все функции принимают объект конфигурации апплета (Plasmoid.configuration),
    чтобы файл не зависел от контекста QML. id — настоящие идентификаторы
    (pluginId для апплетов, SNI Id для значков приложений), не отображаемые имена.
*/

// Полный порядок: панель, поповер, затем остальные известные id. Прежний
// itemOrder добавляем в конец, чтобы не потерять порядок скрытых настройками
// значков (они сейчас не видны и в моделях не присутствуют).
function compose(config, panelIds, popupIds, allIds) {
    const order = [];
    const push = id => {
        if (id && order.indexOf(id) === -1) {
            order.push(id);
        }
    };
    panelIds.forEach(push);
    popupIds.forEach(push);
    (allIds || []).forEach(push);
    ((config && config.itemOrder) || []).forEach(push);
    return order;
}

// Перестановка внутри панели: insertIndex — место среди значков панели
// (0..panelIds.length, считая без перетаскиваемого).
function reorderPanel(config, panelIds, popupIds, allIds, itemId, insertIndex) {
    if (!config || !itemId) {
        return [];
    }
    const panel = panelIds.filter(id => id !== itemId);
    const position = Math.max(0, Math.min(panel.length, insertIndex));
    panel.splice(position, 0, itemId);
    config.itemOrder = compose(config, panel, popupIds.filter(id => id !== itemId), allIds);
    return panel;
}

// Перестановка внутри поповера.
function reorderPopup(config, panelIds, popupIds, allIds, itemId, insertIndex) {
    if (!config || !itemId) {
        return [];
    }
    const popup = popupIds.filter(id => id !== itemId);
    const position = Math.max(0, Math.min(popup.length, insertIndex));
    popup.splice(position, 0, itemId);
    config.itemOrder = compose(config, panelIds.filter(id => id !== itemId), popup, allIds);
    return popup;
}

// Значок уходит из панели в поповер — в конец поповера. Вызывающий обязан
// уменьшить предел видимых значков: панель станет на один значок короче.
function toPopup(config, panelIds, popupIds, allIds, itemId) {
    if (!config || !itemId) {
        return [];
    }
    const panel = panelIds.filter(id => id !== itemId);
    const popup = popupIds.filter(id => id !== itemId);
    popup.push(itemId);
    config.itemOrder = compose(config, panel, popup, allIds);
    return popup;
}

// Значок возвращается из поповера в панель — в конец панели. Вызывающий обязан
// увеличить предел видимых значков: панель станет на один значок длиннее.
function toPanel(config, panelIds, popupIds, allIds, itemId) {
    if (!config || !itemId) {
        return [];
    }
    const panel = panelIds.filter(id => id !== itemId);
    const popup = popupIds.filter(id => id !== itemId);
    panel.push(itemId);
    config.itemOrder = compose(config, panel, popup, allIds);
    return panel;
}
