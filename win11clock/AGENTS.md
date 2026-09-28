# AGENTS.md — проект win11clock

Часы в стиле Windows 11 для панели KDE Plasma 6: время над датой,
поповер с уведомлениями, календарём и режимом «Не беспокоить».
Корень проекта: `/home/deck/vibecoding/plasmoids/win11clock`.

## Что это

KPackage-плазмоид `org.mops1k.win11clock` (`KPackageStructure: Plasma/Applet`),
заменяющий системные часы `org.kde.plasma.digitalclock` в панели. C++ не
собирается: используются установленные системные QML-модули

- `org.kde.plasma.clock` — `Clock` (dateTime, trackSeconds, timeZone);
- `org.kde.plasma.workspace.calendar` — `MonthView` (заголовок месяца,
  навигация, сетка) и `EventPluginsManager`;
- `org.kde.notificationmanager` — `Notifications` (модель, роли summary/body/
  applicationName/created/…, методы expire/close/invokeAction/
  invokeDefaultAction/configure/suspendJob/resumeJob/killJob/reply/clear),
  `Settings` (notificationsInhibitedUntil, revokeApplicationInhibitions, save)
  и singleton `Server` (valid, inhibited).

Список уведомлений работает как история системного апплета: `showExpired` и
`showDismissed` включаются настройкой «Хранить закрытые и истёкшие», задания
(`showJobs`) включены по умолчанию, низкий приоритет показывается. Системный
blacklist истории не применяется: в нём есть `@other`, из-за которого
уведомления приложений без .desktop-файла пропадали из списка.

Роли берутся по именам (`required property list<string> actionNames` и т.п.):
числовые enum-константы в `data(index, …)` дают неверный результат. Тело
уведомления приходит HTML-документом (`<?xml …?><html>…</html>`) и
нормализуется в делегате. `jobError` — код ошибки: `0` означает «ошибки нет»
и не показывается.

`Notifications.Globals` из системного апплета уведомлений недоступен (это
модуль плагина), поэтому «Не беспокоить» реализован напрямую: включение —
`Settings.notificationsInhibitedUntil` = сегодня + 1 год, выключение —
сброс свойства, `revokeApplicationInhibitions()`, `save()`.

## Установка и упаковка

```bash
./scripts/package.sh                     # dist/org.mops1k.win11clock-<версия>.plasmoid
./scripts/install-local.sh [--no-restart] # kpackagetool6 + .mo для po/*/*.po
./scripts/switch-clock.sh [--revert]     # замена digitalclock в appletsrc
./scripts/uninstall-local.sh [--restore]
```

Переводы: у KPackage нет CMake, поэтому `install-local.sh` собирает `.mo`
через `msgfmt` прямо в `~/.local/share/locale/<lang>/LC_MESSAGES/`.

## Правила проекта

- Язык общения, комментариев в документации и сообщений задач — русский;
  сообщения коммитов — английский.
- Коммиты и push — только по прямой просьбе пользователя.
- Правка `~/.config/plasma-org.kde.plasma.desktop-appletsrc` — только с
  бэкапом и при остановленном plasmashell (скрипты делают это сами).
- Перед правкой существующего файла — прочитать его.
- Новая настройка попадает сразу в `contents/config/main.xml` и на страницу
  `contents/ui/config/ConfigGeneral.qml` (свойство `cfg_<entry>`).
- Страница настроек одна: KCM ставит на каждую страницу все `cfg_*` ключи,
  и вторая страница без этих свойств даёт шум «Setting initial properties
  failed».
- После установки агент проверяет журнал, визуальную проверку делает
  пользователь (скриншот агент снимает только по прямой просьбе).
- Уведомления приходят с HTML-разметкой — `summary` и `body` рендерятся как
  `Text.StyledText`, ссылки открываются через `Qt.openUrlExternally`.
- Выравнивание часов считается вручную (`x`/`y` у `Item`-обёртки, строки —
  через `Layout.alignment`): `AnchorChanges` и `x`/`y` у `ColumnLayout`
  эффекта не дают.

## Структура

- `metadata.json` — id, имя, лицензия, `X-Plasma-MainScript: ui/main.qml`.
- `contents/ui/main.qml` — `PlasmoidItem`: `Clock`, модели уведомлений,
  форматирование времени/даты, «Не беспокоить», «Очистить все».
- `contents/ui/CompactRepresentation.qml` — время над датой в панели,
  выравнивание блока и строк по настройке «Положение».
- `contents/ui/CalendarPopup.qml` — поповер: уведомления, `MonthView`,
  переключатель «Не беспокоить» в шапке, «Очистить все» под шапкой.
- `contents/ui/NotificationItem.qml` — делегат уведомления.
- `contents/config/main.xml`, `contents/ui/config/ConfigGeneral.qml` —
  единственная страница настроек (время/дата, календарь, поповер, шрифт).
- `scripts/` — упаковка, установка, откат, замена часов, `appletsrc-tool.py`
  (замена `digitalclock`, удаление унаследованных `popupWidth/popupHeight`,
  перестановка часов в конец панели через `AppletOrder`).
