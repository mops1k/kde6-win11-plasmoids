# win11battery

Индикатор батареи для KDE Plasma 6 в стиле Android/iOS: процент заряда
нарисован **внутри** иконки батареи, заливка окрашивается по уровню заряда,
при зарядке показывается молния. Меню (поповер по клику) — системное,
от апплета «Питание и батарея»: профили питания, ингибирование сна,
список батарей, оставшееся время.

Апплет: `org.mops1k.win11battery`. Это KPackage (чистый QML): системный QML
апплета `powerdevil` (v6.7.5) скопирован целиком, заменена только компактная
иконка. C++ не собирается — используются уже установленные системные
QML-модули `org.kde.plasma.private.batterymonitor` и
`org.kde.plasma.private.battery` из пакета `powerdevil`.

## Установка

Из архива (рекомендуется):

```bash
./scripts/package.sh                     # соберёт dist/org.mops1k.win11battery-<версия>.plasmoid
kpackagetool6 --type Plasma/Applet --install dist/org.mops1k.win11battery-0.1.0.plasmoid
```

Либо через GUI: «Добавить виджеты…» → «Установить из файла…» → выбрать
`.plasmoid`. Из исходников: `./scripts/install-local.sh`.

```bash
./scripts/install-local.sh [--no-restart]
./scripts/switch-battery.sh             # замена системного апплета батареи в панели
./scripts/switch-battery.sh --revert    # вернуть системный апплет
./scripts/uninstall-local.sh [--restore]
```

## Зависимости

Нужен пакет `powerdevil` (входит в стандартную поставку Plasma 6) — из него
берутся C++ QML-модули `org.kde.plasma.private.batterymonitor`
(`PowerProfilesControl`, `InhibitionControl`) и
`org.kde.plasma.private.battery` (`BatteryControlModel`). В KPackage-архив
C++-плагины положить нельзя: QML-движок не регистрирует их из пакета, поэтому
пакет опирается на системный `powerdevil`.

## Настройки (страница «Внешний вид»)

- **Показывать процент внутри батареи** (`showPercentage`).
- **Молния вместо числа при зарядке**.
- **Размер шрифта** — пункты, `0` = автоматически (в квадратной ячейке панели
  работает как максимум, число ужимается через `Text.Fit`).
- **Цвет заливки по уровню заряда** + три цвета (низкий / средний / высокий)
  и пороги в процентах (по умолчанию 20 и 50).

## Структура

- `metadata.json` — id, лицензия, `X-Plasma-NotificationAreaCategory: Hardware`,
  `X-Plasma-Provides: org.kde.plasma.powermanagement`.
- `contents/ui/BatteryIcon.qml` — своя рисованная иконка (контур, носик,
  заливка по проценту, число внутри, молния).
- `contents/ui/CompactRepresentation.qml` — системное компактное представление
  с нашей иконкой (контракт `MouseArea` сохранён).
- `contents/ui/main.qml`, `PopupDialog.qml`, `BatteryItem.qml`,
  `PowerProfileItem.qml`, `InhibitionItem.qml`, `InhibitionHint.qml` —
  системный QML powerdevil 6.7.5 (LGPL-2.0-or-later), не изменялся.
- `contents/config/main.xml`, `contents/ui/config/ConfigAppearance.qml` —
  настройки.
- `scripts/` — сборка архива, установка, замена апплета в панели.

## Грабли (проверено на Plasma 6.7.5)

1. `X-Plasma-NotificationAreaCategory: "Hardware"` обязателен — иначе трей не
   считает плазмоид элементом трея и возвращает системный апплет.
2. Системный `org.kde.plasma.battery` объявлен `EnabledByDefault`, поэтому
   трей сам возвращает его в `knownItems`/`extraItems`; `appletsrc-tool.py`
   оставляет системный id в `knownItems`, но убирает из `extraItems`.
3. `appletsrc` правится при **остановленном** plasmashell (иначе плазма
   перезаписывает файл своим состоянием и создаёт дубликат апплета).
4. Переустановка пакета (`kpackagetool6 --upgrade`/`--install`) вызывает
   `packageUpdated`, трей пересоздаёт апплет с новым id, настройки старого id
   теряются.
5. Частые рестарты plasmashell упираются в systemd rate limit — перед стартом
   `systemctl --user reset-failed plasma-plasmashell.service`.

## Лицензия

Наш код — GPL-3.0-or-later; скопированный QML powerdevil —
LGPL-2.0-or-later (SPDX-заголовки сохранены).
