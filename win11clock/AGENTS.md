# AGENTS.md — проект win11clock

Часы в стиле Windows 11 для панели KDE Plasma 6: время над датой,
поповер с уведомлениями, календарём и режимом «Не беспокоить».
Корень проекта: `/home/deck/vibecoding/plasmoids/win11clock`.

## Что это

KPackage-плазмоид `org.mops1k.win11clock` (`KPackageStructure: Plasma/Applet`),
заменяющий системные часы `org.kde.plasma.digitalclock` в панели. Состоит из
двух частей: KPackage (часы, поповер, история уведомлений) и отдельного
C++ QML-плагина `org.mops1k.win11clock.notifications` (`notifications/`),
который показывает всплывающие уведомления (toast). C++ QML-плагин нельзя
положить внутрь KPackage-архива, поэтому он ставится в
`~/.local/lib/qt6/qml` и подхватывается plasmashell через `QML_IMPORT_PATH`
(systemd drop-in).

KPackage-часть использует установленные системные QML-модули

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
./scripts/package.sh                          # dist/org.mops1k.win11clock-<версия>.plasmoid (KPackage)
./scripts/install-local.sh [--no-build] [--no-restart]
./scripts/switch-clock.sh [--revert] [--no-restart]   # замена digitalclock в appletsrc
./scripts/uninstall-local.sh [--restore]
```

`install-local.sh` собирает C++ QML-плагин
(`cmake -S notifications -B notifications/build -DCMAKE_INSTALL_PREFIX=$HOME/.local`,
нужны `cmake`, `c++`, `wayland-scanner`, `/usr/lib/qt6/qtwaylandscanner`),
ставит его в `~/.local/lib/qt6/qml/org/mops1k/win11clock/notifications`,
создаёт drop-in
`~/.config/systemd/user/plasma-plasmashell.service.d/20-win11clock-qml-import.conf`
(`QML_IMPORT_PATH=%h/.local/lib/qt6/qml`), затем ставит KPackage через
`kpackagetool6` и `.mo`. `uninstall-local.sh` удаляет всё это.

Переводы: у KPackage нет CMake, поэтому `install-local.sh` собирает `.mo`
через `msgfmt` прямо в `~/.local/share/locale/<lang>/LC_MESSAGES/`. Домен один
на оба компонента — `plasma_applet_org.mops1k.win11clock`; в вендоренном коде
используются формы с явным доменом (`i18nd*`).

## Вендоренный код (notifications/)

`notifications/` — форк `applets/notifications` из plasma-workspace 6.7.5
(GPL-2.0+/GPL-3.0+, SPDX-заголовки сохранены). Что изменено относительно
upstream:

- импорты `plasma.applet.org.kde.plasma.notifications` →
  `org.mops1k.win11clock.notifications`;
- `NotificationApplet` не перенесён: `InputDisabler` вынесен в
  `src/inputdisabler.*`, `forceActivateWindow` заменён на
  `NotificationWindow::forceActivate()` (Q_INVOKABLE), `focussedPlasmaDialog`
  и `systemTrayRepresentation` убраны (объезд диалогов плазмы не
  поддерживается — `obstructingDialog` всегда null);
- `Globals.adopt()/forget()` упрощены до прямого присвоения
  `plasmoidItem`/`plasmoid` (нет `ratePlasmoids`), очистка истории —
  `Globals.clearNotificationHistory()`;
- `jobError` приводится к числу (`Number(popup.jobError) || 0`): в Plasma
  6.7.5 роль приходит строкой, а `ModelInterface.jobError` объявлен `int`;
- превью-картинка рендерится через `KQuickAddons.QImageItem`: роль `image`
  из `org.kde.notificationmanager` — это `QImage`, а не URL, поэтому ни
  обычный `Image`, ни `Kirigami.Icon` её не показывают. В вендоренном
  `components/Icon.qml` добавлен `Loader` с `QImageItem` (включается, когда
  `typeof icon === "object"`), в `contents/ui/NotificationItem.qml` превью
  тоже `QImageItem` (высота 8*gridUnit, `PreserveAspectFit`);
- сборка: `qt_add_qml_module` + ручная генерация `qwayland-plasma-shell.h`
  (`wayland-scanner` + `/usr/lib/qt6/qtwaylandscanner`), потому что в системе
  нет пакетов `WaylandScanner`/`Qt6WaylandClient`; RUNPATH плагина —
  `$ORIGIN` (backing-библиотека лежит рядом).

При мажорном обновлении Plasma вендоренный код нужно синхронизировать с
новым `plasma-workspace` вручную.

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
  форматирование времени/даты, «Не беспокоить», «Очистить все»; вызывает
  `Notifications.Globals.adopt(root)`/`forget()`.
- `contents/ui/CompactRepresentation.qml` — время над датой в панели,
  выравнивание блока и строк по настройке «Положение», значок «Не беспокоить»
  (колокольчик + z) справа при `dndEnabled`; отступы содержимого заданы
  явно (`leftPadding`/`rightPadding`, правый больше — 3×smallSpacing).
- `contents/ui/CalendarPopup.qml` — поповер: уведомления, `MonthView`,
  переключатель «Не беспокоить» в шапке, «Очистить все» под шапкой.
  Высота берётся из `Plasmoid.containment.availableScreenRect.height`
  (не `Screen.desktopAvailableHeight`: у откреплённой панели он равен высоте
  экрана), и растягивается через `implicitHeight` + `Layout.minimumHeight` =
  `Layout.preferredHeight` = `Layout.maximumHeight` (AppletPopup читает size
  hints из mainItem; одного `Layout.preferredHeight` недостаточно). Позицию
  окна задаёт KWin по видимой части панели, поэтому при откреплённой панели
  поповер встаёт вплотную к её видимой части — через QML это не сдвинуть
  (`margin` и якорь проверены; свой `AppletPopup` ломает компакт часов).
- `contents/ui/NotificationItem.qml` — делегат уведомления.
- `notifications/` — C++ QML-плагин toast-уведомлений: `CMakeLists.txt`,
  `src/` (C++), `NotificationPopup.qml`, `DraggableDelegate.qml`,
  `delegates/`, `components/`, `global/Globals.qml`, `global/PulseAudio.qml`.
- `contents/config/main.xml`, `contents/ui/config/ConfigGeneral.qml` —
  единственная страница настроек (время/дата, календарь, поповер, шрифт).
- `scripts/` — упаковка, установка, откат, замена часов, `appletsrc-tool.py`
  (замена `digitalclock`, удаление унаследованных `popupWidth/popupHeight`,
  перестановка часов в конец панели через `AppletOrder`).
