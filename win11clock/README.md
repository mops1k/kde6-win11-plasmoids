# Win11 Clock — часы в стиле Windows 11 для KDE Plasma 6

KPackage-плазмоид `org.mops1k.win11clock`: время над датой в панели и поповер
с уведомлениями, календарём и режимом «Не беспокоить» — как блок часов в
панели задач Windows 11. Заменяет системные часы
`org.kde.plasma.digitalclock`. Используются системные QML-модули Plasma
(`org.kde.plasma.clock`, `org.kde.plasma.workspace.calendar`,
`org.kde.notificationmanager`) и собственный C++ QML-плагин
`org.mops1k.win11clock.notifications` — он показывает всплывающие
уведомления (toast) в позиции, настроенной в KCM.

## Установка

```bash
./scripts/install-local.sh          # C++ QML-плагин + kpackagetool6 + .mo + рестарт plasmashell
./scripts/install-local.sh --no-build --no-restart
./scripts/switch-clock.sh           # заменить digitalclock на win11clock в панели (с бэкапом)
./scripts/switch-clock.sh --revert  # вернуть системные часы
./scripts/uninstall-local.sh --restore
```

Установка требует `cmake`, `c++`, `wayland-scanner` и (в системе)
`/usr/lib/qt6/qtwaylandscanner`; скрипт собирает плагин, ставит его в
`~/.local/lib/qt6/qml/org/mops1k/win11clock/notifications` и создаёт drop-in
`~/.config/systemd/user/plasma-plasmashell.service.d/20-win11clock-qml-import.conf`
с `QML_IMPORT_PATH` (без него plasmashell не видит внешний QML-модуль).

Для установки из архива (только KPackage-часть; C++ плагин ставится
`install-local.sh`):

```bash
./scripts/package.sh
kpackagetool6 --type Plasma/Applet --install dist/org.mops1k.win11clock-0.1.0.plasmoid
```

## Настройки

Одна страница «Общие»:

- время — 24-часовой формат, секунды, полужирное начертание;
- дата — показ даты и дня недели, формат (короткий/ISO/длинный/свой);
- положение блока в апплете — справа (как в Windows 11), по центру, слева;
- шрифт — семейство, размер времени и даты (0 = автоматически), свой цвет;
- календарь — номера недель;
- поповер — лимит уведомлений, хранение истории (закрытые и истёкшие),
  низкий приоритет, задания (передача файлов, загрузки) и переключатель
  «Не беспокоить».

## Список уведомлений

Работает как в системном апплете, но с историей: закрытые и истёкшие
уведомления остаются в списке, пока их не уберут крестиком или кнопкой
«Очистить все». Поддерживаются:

- действия уведомления (`actionNames`/`actionLabels` → `invokeAction`),
  кнопка действия по умолчанию, «Подробности» (`configure`), поле ответа
  (`reply`);
- задания с прогресс-баром и процентом (`jobState`, `percentage`),
  кнопки «Пауза»/«Продолжить» и «Отмена» (`suspendJob`/`resumeJob`/`killJob`);
- превью-картинка (`image`): роль приходит как `QImage`, показывается через
  `KQuickAddons.QImageItem` — крупно в списке истории и как иконка в попапе;
  иконка приложения;
- HTML-разметка в заголовке и тексте, ссылки открываются во внешнем браузере.

## Всплывающие уведомления

Их показывает вендоренный код апплета уведомлений plasma-workspace 6.7.5
(`notifications/`, GPL-2.0+/GPL-3.0+): окно `NotificationWindow`
(`PlasmaQuick::PlasmaWindow` с ролью `role_notification`), делегаты
`NotificationPopup`/`DelegatePopup`, синглтон `Globals` с моделью попапов и
позиционированием. Поведение как у системного апплета уведомлений:

- позиция берётся из KCM «Уведомления» → «Всплывающие уведомления»
  (`[Notifications] PopupPosition` в `~/.config/plasmanotifyrc`): все семь
  вариантов, включая «Рядом с иконкой уведомлений» (относительно часов);
- таймаут уведомления (`-t` у `notify-send`): попап скрывается по истечении,
  таймер останавливается при наведении и при взаимодействии;
- режим «Не беспокоить»: обычные попапы подавляются, критичные показываются
  (`ShowPopupsInDndMode`/`CriticalPopupsInDoNotDisturbMode` в KCM), звук
  уведомлений глушится;
- задания, миниатюры, drag-and-drop файлов, inline-ответы, кнопки действий;
- глобальные шорткаты апплета уведомлений (переключение DND, очистка истории).

## Структура

- `contents/ui/main.qml` — `PlasmoidItem`: `Clock`, модель уведомлений
  (режим истории), форматирование времени и даты, «Не беспокоить»,
  «Очистить все»; отдаёт себя синглтону `Globals` (`adopt`/`forget`).
- `contents/ui/CompactRepresentation.qml` — время над датой в панели,
  выравнивание по настройке «Положение»; при включённом «Не беспокоить»
  справа от часов появляется значок-колокольчик с буквой z (как в Windows 11).
- `contents/ui/CalendarPopup.qml` — поповер: уведомления, `MonthView`,
  переключатель «Не беспокоить» в шапке.
- `contents/ui/NotificationItem.qml` — делегат уведомления: styled text,
  превью, прогресс задания, кнопки действий.
- `notifications/` — C++ QML-плагин всплывающих уведомлений (форк
  `applets/notifications` из plasma-workspace 6.7.5): `src/` (C++),
  `NotificationPopup.qml`, `delegates/`, `components/`, `global/Globals.qml`.
- `scripts/` — упаковка, установка, откат, замена часов, `appletsrc-tool.py`.

Лицензия: GPL-3.0-or-later.
