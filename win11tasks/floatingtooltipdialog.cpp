/*
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "floatingtooltipdialog.h"

#include <QDebug>
#include <QFile>
#include <QPlatformSurfaceEvent>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>

#include <KWindowSystem>

FloatingToolTipDialog::FloatingToolTipDialog()
    : PopupPlasmaWindow(QStringLiteral("widgets/tooltip"))
    , m_qmlEngine(nullptr)
    , m_qmlComponent(nullptr)
    , m_hideTimeout(-1)
    , m_interactive(false)
    , m_owner(nullptr)
{
    Qt::WindowFlags flags = Qt::WindowDoesNotAcceptFocus | Qt::WindowStaysOnTopHint;
    if (KWindowSystem::isPlatformX11()) {
        flags |= Qt::ToolTip | Qt::BypassWindowManagerHint;
    } else {
        flags |= Qt::FramelessWindowHint;
    }
    setFlags(flags);

    m_hideTimer.setSingleShot(true);
    connect(&m_hideTimer, &QTimer::timeout, this, [this]() {
        setVisible(false);
    });

    connect(this, &PlasmaQuick::PlasmaWindow::mainItemChanged, this, [this]() {
        if (m_lastMainItem) {
            disconnect(m_lastMainItem, &QQuickItem::implicitWidthChanged, this, &FloatingToolTipDialog::updateSize);
            disconnect(m_lastMainItem, &QQuickItem::implicitHeightChanged, this, &FloatingToolTipDialog::updateSize);
        }
        m_lastMainItem = mainItem();

        if (!m_lastMainItem) {
            return;
        }
        connect(m_lastMainItem, &QQuickItem::implicitWidthChanged, this, &FloatingToolTipDialog::updateSize);
        connect(m_lastMainItem, &QQuickItem::implicitHeightChanged, this, &FloatingToolTipDialog::updateSize);
        updateSize();
    });
}

FloatingToolTipDialog::~FloatingToolTipDialog()
{
    // Объект создан нами (CppOwnership), движок его не удалит.
    delete m_defaultItem;
}

void FloatingToolTipDialog::updateSize()
{
    QScreen *s = screen();
    if (!s) {
        return;
    }
    QSize popupSize = QSize(mainItem()->implicitWidth(), mainItem()->implicitHeight());
    popupSize = popupSize.grownBy(padding());
    popupSize = popupSize.boundedTo(s->geometry().size());
    if (!popupSize.isEmpty()) {
        resize(popupSize);
    }
}

QQuickItem *FloatingToolTipDialog::loadDefaultItem()
{
    // Plasma 6.8 удалила PlasmaQuick::SharedQmlEngine, поэтому движок и
    // компонент держим сами; грузим тот же тип org.kde.plasma.core/DefaultToolTip.
    // Используются только давние API Qt (loadFromModule есть с Qt 6.5),
    // так что код одинаково собирается и на Plasma 6.7, и на 6.8.
    if (!m_qmlEngine) {
        m_qmlEngine = new QQmlEngine(this);
        m_qmlComponent = new QQmlComponent(m_qmlEngine, this);
        m_qmlComponent->loadFromModule(QStringLiteral("org.kde.plasma.core"), QStringLiteral("DefaultToolTip"));
        if (m_qmlComponent->isError()) {
            qWarning() << "FloatingToolTipDialog: не удалось загрузить org.kde.plasma.core/DefaultToolTip:" << m_qmlComponent->errors();
            return nullptr;
        }
    }

    if (!m_defaultItem) {
        if (QObject *object = m_qmlComponent->create()) {
            if (auto *item = qobject_cast<QQuickItem *>(object)) {
                QQmlEngine::setObjectOwnership(item, QQmlEngine::CppOwnership);
                m_defaultItem = item;
            } else {
                delete object;
            }
        }
    }

    return m_defaultItem;
}

void FloatingToolTipDialog::showEvent(QShowEvent *event)
{
    keepalive();
    PlasmaQuick::PopupPlasmaWindow::showEvent(event);
}

void FloatingToolTipDialog::hideEvent(QHideEvent *event)
{
    m_hideTimer.stop();
    PlasmaQuick::PopupPlasmaWindow::hideEvent(event);
}

bool FloatingToolTipDialog::event(QEvent *e)
{
    if (e->type() == QEvent::Enter) {
        if (m_interactive) {
            m_hideTimer.stop();
        }
    } else if (e->type() == QEvent::Leave) {
        dismiss();
    }

    return PopupPlasmaWindow::event(e);
}

QObject *FloatingToolTipDialog::owner() const
{
    return m_owner;
}

void FloatingToolTipDialog::setOwner(QObject *owner)
{
    m_owner = owner;
}

void FloatingToolTipDialog::dismiss()
{
    m_hideTimer.start(200);
}

void FloatingToolTipDialog::keepalive()
{
    if (m_hideTimeout > 0) {
        m_hideTimer.start(m_hideTimeout);
    } else {
        m_hideTimer.stop();
    }
}

bool FloatingToolTipDialog::interactive()
{
    return m_interactive;
}

void FloatingToolTipDialog::setInteractive(bool interactive)
{
    m_interactive = interactive;
}

void FloatingToolTipDialog::valueChanged(const QVariant &value)
{
    setPosition(value.toPoint());
}

void FloatingToolTipDialog::setHideTimeout(int timeout)
{
    m_hideTimeout = timeout;
}

int FloatingToolTipDialog::hideTimeout() const
{
    return m_hideTimeout;
}
