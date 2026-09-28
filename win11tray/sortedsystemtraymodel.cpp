/*
    SPDX-FileCopyrightText: 2019 Konrad Materka <materka@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/
#include "sortedsystemtraymodel.h"
#include "debug.h"
#include "systemtraysettings.h"
#include "systemtraymodel.h"
#include <Plasma/Plasma>
#include <QList>
#include <QTimer>
#include <limits>

static const QList<QString> s_categoryOrder = {
    QStringLiteral("UnknownCategory"),
    QStringLiteral("ApplicationStatus"),
    QStringLiteral("Communications"),
    QStringLiteral("SystemServices"),
    QStringLiteral("Hardware"),
};

SortedSystemTrayModel::SortedSystemTrayModel(SortingType sorting, SystemTraySettings *settings, QObject *parent)
    : QSortFilterProxyModel(parent), m_sorting(sorting), m_settings(settings) {
    setSortLocaleAware(true);
    sort(0);
    // При смене предела видимых значков фильтр надо пересчитать: число строк
    // панели и поповера меняется.
    connect(m_settings, &SystemTraySettings::configurationChanged, this, [this]() {
        invalidate();
    });
}

void SortedSystemTrayModel::invalidateSplitCache()
{
    // Данные берутся из источника на лету (isInPanelRow), кэша больше нет;
    // слот нужен только для пересчёта фильтра при изменении состава модели.
    invalidateFilter();
}

bool SortedSystemTrayModel::isInPanelRow(int sourceRow) const
{
    // Позиция значка в панели считается на лету: кэш здесь не годится, потому
    // что QSortFilterProxyModel применяет фильтр раньше, чем приходят наши
    // слоты на сигналы источника, и успевает отфильтровать по устаревшим данным.
    const QAbstractItemModel *source = sourceModel();
    if (!source || !m_settings) {
        return false;
    }
    const int statusRole = static_cast<int>(BaseModel::BaseRole::EffectiveStatus);
    if (source->index(sourceRow, 0).data(statusRole).toInt() != static_cast<int>(Plasma::Types::ActiveStatus)) {
        return false;
    }
    const int limit = m_settings->maxVisibleIcons();
    if (limit == 0 || m_settings->isShowAllItems()) {
        return true;
    }
    int activeIndex = 0;
    for (int row = 0; row < sourceRow; ++row) {
        if (source->index(row, 0).data(statusRole).toInt() == static_cast<int>(Plasma::Types::ActiveStatus)) {
            ++activeIndex;
        }
    }
    return activeIndex < limit;
}

void SortedSystemTrayModel::setSourceModel(QAbstractItemModel *model)
{
    if (sourceModel()) {
        sourceModel()->disconnect(this);
    }
    QSortFilterProxyModel::setSourceModel(model);
    invalidateSplitCache();
    if (!model) {
        return;
    }
    // Кэш разбиения на панель/поповер зависит от состава и статусов строк.
    connect(model, &QAbstractItemModel::dataChanged, this, &SortedSystemTrayModel::invalidateSplitCache);
    // Фильтр панели/поповера зависит от позиции значка, поэтому после вставки
    // строк пересчитываем его целиком (через очередь событий: на момент
    // сигнала модель источника ещё меняется).
    connect(model, &QAbstractItemModel::rowsInserted, this, [this]() {
        QTimer::singleShot(0, this, [this]() { invalidateFilter(); });
    });
    connect(model, &QAbstractItemModel::rowsRemoved, this, &SortedSystemTrayModel::invalidateSplitCache);
    connect(model, &QAbstractItemModel::modelReset, this, &SortedSystemTrayModel::invalidateSplitCache);
    connect(model, &QAbstractItemModel::layoutChanged, this, &SortedSystemTrayModel::invalidateSplitCache);

    invalidateFilter();
}

QHash<int, QByteArray> SortedSystemTrayModel::roleNames() const
{
    QHash<int, QByteArray> roles = sourceModel() ? sourceModel()->roleNames() : QHash<int, QByteArray>();
    if (m_sorting != SortingType::ConfigurationPage) {
        roles.insert(static_cast<int>(SplitRole::InPanel), QByteArrayLiteral("inPanel"));
        roles.insert(static_cast<int>(SplitRole::InPopup), QByteArrayLiteral("inPopup"));
    }
    return roles;
}

QVariant SortedSystemTrayModel::data(const QModelIndex &index, int role) const
{
    const bool splitSorting = m_sorting == SortingType::SystemTray
        || m_sorting == SortingType::Panel
        || m_sorting == SortingType::Popup;
    if (splitSorting && (role == static_cast<int>(SplitRole::InPanel) || role == static_cast<int>(SplitRole::InPopup))) {
        const int row = mapToSource(index).row();
        const bool inPanel = isInPanelRow(row);
        if (role == static_cast<int>(SplitRole::InPanel)) {
            return inPanel;
        }
        const int statusRole = static_cast<int>(BaseModel::BaseRole::EffectiveStatus);
        const bool active = sourceModel()
            && sourceModel()->index(row, 0).data(statusRole).toInt() == static_cast<int>(Plasma::Types::ActiveStatus);
        return active && !inPanel;
    }
    return QSortFilterProxyModel::data(index, role);
}

bool SortedSystemTrayModel::filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const
{
    if (m_sorting != SortingType::Panel && m_sorting != SortingType::Popup) {
        return QSortFilterProxyModel::filterAcceptsRow(sourceRow, sourceParent);
    }
    const bool inPanel = isInPanelRow(sourceRow);
    // В поповер попадают только вытесненные лимитом активные значки; значки,
    // скрытые настройками пользователя (PassiveStatus), не показываются нигде.
    if (m_sorting == SortingType::Panel) {
        return inPanel;
    }
    const int statusRole = static_cast<int>(BaseModel::BaseRole::EffectiveStatus);
    const bool active = sourceModel()
        && sourceModel()->index(sourceRow, 0).data(statusRole).toInt() == static_cast<int>(Plasma::Types::ActiveStatus);
    return active && !inPanel;
}

bool SortedSystemTrayModel::lessThan(const QModelIndex &left, const QModelIndex &right) const {
    switch (m_sorting) {
    case SortingType::ConfigurationPage: return lessThanConfigurationPage(left, right);
    case SortingType::SystemTray:
    case SortingType::Panel:
    case SortingType::Popup: return lessThanSystemTray(left, right);
    }
    return QSortFilterProxyModel::lessThan(left, right);
}

bool SortedSystemTrayModel::lessThanConfigurationPage(const QModelIndex &left, const QModelIndex &right) const {
    int cmp = compareCategoriesAlphabetically(left, right);
    return cmp == 0 ? QSortFilterProxyModel::lessThan(left, right) : cmp < 0;
}

bool SortedSystemTrayModel::lessThanSystemTray(const QModelIndex &left, const QModelIndex &right) const {
    QVariant lid = left.data(static_cast<int>(BaseModel::BaseRole::ItemId));
    QVariant rid = right.data(static_cast<int>(BaseModel::BaseRole::ItemId));

    // Пользовательский порядок (перетаскивание иконок) имеет приоритет над
    // категориями: элементы из itemOrder идут в заданном порядке, остальные —
    // после них в обычном порядке категорий.
    if (m_settings) {
        const QStringList order = m_settings->itemOrder();
        if (!order.isEmpty()) {
            const int li = order.indexOf(lid.toString());
            const int ri = order.indexOf(rid.toString());
            if (li != -1 || ri != -1) {
                const int lpos = li == -1 ? std::numeric_limits<int>::max() : li;
                const int rpos = ri == -1 ? std::numeric_limits<int>::max() : ri;
                if (lpos != rpos) {
                    return lpos < rpos;
                }
            }
        }
    }

    if (rid.toString() == QLatin1String("org.kde.plasma.notifications")) return false;
    if (lid.toString() == QLatin1String("org.kde.plasma.notifications")) return true;
    int cmp = compareCategoriesOrderly(left, right);
    return cmp == 0 ? QSortFilterProxyModel::lessThan(left, right) : cmp < 0;
}

int SortedSystemTrayModel::compareCategoriesAlphabetically(const QModelIndex &left, const QModelIndex &right) const {
    QString lcat = left.data(static_cast<int>(BaseModel::BaseRole::Category)).toString();
    if (lcat.isEmpty()) lcat = QStringLiteral("UnknownCategory");
    QString rcat = right.data(static_cast<int>(BaseModel::BaseRole::Category)).toString();
    if (rcat.isEmpty()) rcat = QStringLiteral("UnknownCategory");
    return QString::localeAwareCompare(lcat, rcat);
}

int SortedSystemTrayModel::compareCategoriesOrderly(const QModelIndex &left, const QModelIndex &right) const {
    QString lcat = left.data(static_cast<int>(BaseModel::BaseRole::Category)).toString();
    if (lcat.isEmpty()) lcat = QStringLiteral("UnknownCategory");
    QString rcat = right.data(static_cast<int>(BaseModel::BaseRole::Category)).toString();
    if (rcat.isEmpty()) rcat = QStringLiteral("UnknownCategory");
    int li = s_categoryOrder.indexOf(lcat); if (li == -1) li = s_categoryOrder.indexOf(QStringLiteral("UnknownCategory"));
    int ri = s_categoryOrder.indexOf(rcat); if (ri == -1) ri = s_categoryOrder.indexOf(QStringLiteral("UnknownCategory"));
    return li - ri;
}

#include "moc_sortedsystemtraymodel.cpp"
