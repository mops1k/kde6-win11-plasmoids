/*
    SPDX-FileCopyrightText: 2015 Marco Martin <mart@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <QAbstractItemModel>
#include <QPointer>

#include <KConfigWatcher>

#include <Plasma/Containment>

class QQuickItem;

namespace Plasma
{
}
class PlasmoidRegistry;
class PlasmoidModel;
class SystemTraySettings;
class StatusNotifierModel;
class SystemTrayModel;
class SortedSystemTrayModel;
class KJob;

class SystemTray : public Plasma::Containment
{
    Q_OBJECT
    Q_PROPERTY(QAbstractItemModel *systemTrayModel READ sortedSystemTrayModel CONSTANT)
    Q_PROPERTY(QAbstractItemModel *configSystemTrayModel READ configSystemTrayModel CONSTANT)
    // Готовые модели с разбиением значков: панель (не больше maxVisibleIcons
    // активных) и поповер скрытых значков (остальные).
    Q_PROPERTY(QAbstractItemModel *panelSystemTrayModel READ panelSystemTrayModel CONSTANT)
    Q_PROPERTY(QAbstractItemModel *popupSystemTrayModel READ popupSystemTrayModel CONSTANT)

public:
    SystemTray(QObject *parent, const KPluginMetaData &data, const QVariantList &args);
    ~SystemTray() override;

    void init() override;

    void restoreContents(KConfigGroup &group) override;

    QAbstractItemModel *sortedSystemTrayModel();

    QAbstractItemModel *configSystemTrayModel();

    QAbstractItemModel *panelSystemTrayModel();

    QAbstractItemModel *popupSystemTrayModel();

    Q_INVOKABLE void showPlasmoidMenu(QQuickItem *appletInterface, int x, int y);
    Q_INVOKABLE QPointF popupPosition(QQuickItem *visualParent, int x, int y);
    Q_INVOKABLE bool isSystemTrayApplet(const QString &appletId);
    Q_INVOKABLE QQuickItem *appletForPluginId(const QString &pluginId);
    Q_INVOKABLE void stackItemBefore(QQuickItem *newItem, QQuickItem *beforeItem);
    Q_INVOKABLE void stackItemAfter(QQuickItem *newItem, QQuickItem *afterItem);
    Q_INVOKABLE void activate(const QString &service, QPoint pos, QQuickItem *statusNotifierIcon);
    Q_INVOKABLE void secondaryActivate(const QString &service, QPoint pos);
    Q_INVOKABLE void openContextMenu(const QString &service, QPoint pos, QQuickItem *statusNotifierIcon);
    Q_INVOKABLE void scroll(const QString &service, int delta, const QString &direction);

    // Пользовательский порядок иконок трея (запоминается при перетаскивании).
    Q_INVOKABLE QStringList itemOrder() const;
    Q_INVOKABLE void setItemOrder(const QStringList &order);

    // Предел иконок в панели: всё, что не влезло, живёт в поповере шеврона.
    Q_INVOKABLE int maxVisibleIcons() const;
    Q_INVOKABLE void setMaxVisibleIcons(int count);

    // Идентификаторы значков в порядке моделей. Нужны QML для перетаскивания:
    // в QML роль по имени-строке не резолвится (model.data(index, "itemId")
    // отдаёт Qt::DisplayRole, то есть отображаемое имя), поэтому id берём здесь
    // по числовой роли.
    Q_INVOKABLE QStringList panelItemIds();
    Q_INVOKABLE QStringList popupItemIds();

private Q_SLOTS:
    void onEnabledAppletsChanged();
    void startApplet(const QString &pluginId);
    void stopApplet(const QString &pluginId);

private:
    void migrateFromSystrayContainer();
    SystemTrayModel *systemTrayModel();
    void initSettingsAndRegistry();

    KConfigWatcher::Ptr m_configWatcher;
    bool m_xwaylandClientsScale = true;

    QPointer<SystemTraySettings> m_settings;
    QPointer<PlasmoidRegistry> m_plasmoidRegistry;

    PlasmoidModel *m_plasmoidModel = nullptr;
    StatusNotifierModel *m_statusNotifierModel = nullptr;
    SystemTrayModel *m_systemTrayModel = nullptr;
    SortedSystemTrayModel *m_sortedSystemTrayModel = nullptr;
    SortedSystemTrayModel *m_configSystemTrayModel = nullptr;
    SortedSystemTrayModel *m_panelSystemTrayModel = nullptr;
    SortedSystemTrayModel *m_popupSystemTrayModel = nullptr;

    QHash<QString /*plugin id*/, int /*config group*/> m_configGroupIds;
};
