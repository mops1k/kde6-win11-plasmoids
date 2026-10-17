/*
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#ifndef FLOATINGTOOLTIPDIALOG_H
#define FLOATINGTOOLTIPDIALOG_H

#include <PlasmaQuick/PopupPlasmaWindow>

#include <QPointer>
#include <QQuickWindow>
#include <QTimer>
#include <QVariant>

class QQmlComponent;
class QQmlEngine;
class QQuickItem;

class FloatingToolTipDialog : public PlasmaQuick::PopupPlasmaWindow
{
    Q_OBJECT

public:
    explicit FloatingToolTipDialog();
    ~FloatingToolTipDialog() override;

    QQuickItem *loadDefaultItem();

    void dismiss();
    void keepalive();

    bool interactive();
    void setInteractive(bool interactive);

    int hideTimeout() const;
    void setHideTimeout(int timeout);

    QObject *owner() const;
    void setOwner(QObject *owner);

protected:
    void showEvent(QShowEvent *event) override;
    void hideEvent(QHideEvent *event) override;
    bool event(QEvent *e) override;

private Q_SLOTS:
    void valueChanged(const QVariant &value);

private:
    void updateSize();
    // Помечает окно тултипа ролью plasma-shell tooltip: без неё KWin считает
    // тултип обычным окном, и эффект HighlightWindow («Скрывать другие окна
    // при наведении на превью») гасит его вместе с остальными окнами.
    void applyToolTipRole();

    QPointer<QQuickItem> m_lastMainItem;
    // Plasma 6.8 убрал PlasmaQuick::SharedQmlEngine — движок и компонент
    // для запасного DefaultToolTip держим здесь сами.
    QPointer<QQuickItem> m_defaultItem;
    QQmlEngine *m_qmlEngine;
    QQmlComponent *m_qmlComponent;
    QTimer m_hideTimer;
    int m_hideTimeout;
    bool m_interactive;
    QObject *m_owner;
};

#endif
