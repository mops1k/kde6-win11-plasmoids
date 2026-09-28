/*
    SPDX-FileCopyrightText: 2019 Konrad Materka <materka@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/
#pragma once
#include <QHash>
#include <QPointer>
#include <QSortFilterProxyModel>
#include <QVariant>

class SystemTraySettings;

class SortedSystemTrayModel : public QSortFilterProxyModel {
    Q_OBJECT
public:
    // Panel и Popup — модели с теми же ролями и сортировкой, но отфильтрованные:
    // панель получает первые maxVisibleIcons активных значков, поповер — всё
    // остальное (пассивные и вытесненные активные).
    enum class SortingType { ConfigurationPage, SystemTray, Panel, Popup };
    // Разбиение на панель и поповер (поведение Windows 11): в панель попадает не
    // больше SystemTraySettings::maxVisibleIcons активных элементов, остальные
    // активные вместе с пассивными уходят в поповер скрытых значков.
    enum class SplitRole { InPanel = Qt::UserRole + 1000, InPopup = Qt::UserRole + 1001 };

    explicit SortedSystemTrayModel(SortingType sorting, SystemTraySettings *settings = nullptr, QObject *parent = nullptr);

    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;
    void setSourceModel(QAbstractItemModel *sourceModel) override;
protected:
    bool lessThan(const QModelIndex &source_left, const QModelIndex &source_right) const override;
    bool filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const override;
private:
    bool lessThanConfigurationPage(const QModelIndex &left, const QModelIndex &right) const;
    bool lessThanSystemTray(const QModelIndex &left, const QModelIndex &right) const;
    int compareCategoriesAlphabetically(const QModelIndex &left, const QModelIndex &right) const;
    int compareCategoriesOrderly(const QModelIndex &left, const QModelIndex &right) const;
    bool isInPanelRow(int sourceRow) const;
    void invalidateSplitCache();
    SortingType m_sorting;
    QPointer<SystemTraySettings> m_settings;

};
