/*
    SPDX-FileCopyrightText: 2018 Kai Uwe Broulik <kde@privat.broulik.de>

    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#include "inputdisabler.h"

#include <QQuickItem>

void InputDisabler::makeTransparentForInput(QQuickItem *item)
{
    if (item) {
        item->setAcceptedMouseButtons(Qt::NoButton);
        item->setAcceptHoverEvents(false);
        item->setAcceptTouchEvents(false);
        item->unsetCursor();
    }
}
