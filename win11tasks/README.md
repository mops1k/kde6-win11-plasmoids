# Win11 Tasks

Плазмоид KDE Plasma 6 — таскбар в стиле Windows 11: только иконки, подсветка
запущенных приложений, всплывающие подсказки с превью окон и кнопкой закрытия.

C++-апплет (`Plasma::Applet`) на базе `org.kde.plasma.taskmanager` из
plasma-desktop, взятый из набора
[KDE-Windows-Modern](https://github.com/Jeysef/KDE-Windows-Modern)
(GPL-3.0), см. `NOTICE.md`.

- id апплета: `org.mops1k.win11tasks`
- имя в Plasma: **Win11 Tasks**

## Требования

- KDE Plasma 6 (проверено на plasma-workspace 6.7.5, Qt 6.11.2, KF6 6.30)
- для сборки: `cmake`, `extra-cmake-modules`, `gcc`, `qt6-base`,
  `qt6-declarative`, `qt6-5compat`, `kpackage`, `kconfig`, `ki18n`, `kio`,
  `kservice`, `kwindowsystem`, `kxmlgui`, `knotifications`,
  `plasma-activities`, `plasma-activities-stats`, `libksysguard`,
  `libplasma`, `plasma-workspace`

## Сборка и установка в ~/.local (без root)

```bash
./scripts/install-local.sh
```

Скрипт собирает Release-версию и кладёт плагин в
`~/.local/lib/qt6/plugins/plasma/applets/org.mops1k.win11tasks.so`,
затем перезапускает plasmashell.

Qt не ищет плагины в `~/.local/lib/qt6/plugins` сам, поэтому нужен
`QT_PLUGIN_PATH` — скрипт создаёт drop-in systemd-юнита plasmashell
(`~/.config/systemd/user/plasma-plasmashell.service.d/11-win11tasks-plugin-path.conf`),
если такого пути ещё нет (например, его уже задал `win11tray`).

QML вкомпилирован в `.so`: отдельный KPackage в
`~/.local/share/plasma/plasmoids/org.mops1k.win11tasks` ставить нельзя.

## Включение в панель

```bash
./scripts/switch-tasks.sh
```

Скрипт делает бэкап `~/.config/plasma-org.kde.plasma.desktop-appletsrc`,
меняет `plugin=org.kde.plasma.icontasks` на `org.mops1k.win11tasks`
(конфигурация контейнера — лаунчеры, группировка, размер иконок —
сохраняется) и перезапускает plasmashell.

## Настройка

Правый клик по таскбару → «Настроить Win11 Tasks», вкладка «Внешний вид»:

- **Position of task icons** — `Left` или `Centered`: положение иконок задач
  на панели. По умолчанию `Centered` — иконки по центру экрана, как в
  Windows 11. Сам виджет при этом занимает всю панель (`fill`).
- показ превью окон при наведении, индикаторы звука, отступы между иконками,
  максимальная ширина задачи, многострочный режим.

## Откат

```bash
./scripts/uninstall-local.sh            # убрать плагин из ~/.local
./scripts/switch-tasks.sh --revert      # вернуть системный таскбар из бэкапа
```

## Устранение неполадок

- **Апплет не появляется в списке виджетов** — проверьте, что
  `~/.local/lib/qt6/plugins/plasma/applets/org.mops1k.win11tasks.so` на месте
  и что plasmashell запущен с `QT_PLUGIN_PATH`; перезапустите
  `systemctl --user restart plasma-plasmashell.service`.
- **Таскбар пустой или не стилизован** — установлен KPackage вместо
  C++-плагина: удалите `~/.local/share/plasma/plasmoids/org.mops1k.win11tasks`.
- **Пропал после обновления Plasma** — пересоберите: `./scripts/install-local.sh`.

## Переводы

Строки интерфейса обёрнуты в `i18n()`/`i18nc()` (QML) и `i18n()` (C++); шаблон
строк — `po/<домен>.pot`, переводы — `po/<язык>/<домен>.po` (сейчас `po/ru/`).
Домен: `plasma_applet_org.mops1k.win11tasks` (= `TRANSLATION_DOMAIN` в `CMakeLists.txt`).

Обновить шаблон после правки строк:

```bash
find contents \( -name '*.qml' -o -name '*.js' \) -print0 | xargs -0 xgettext \
  --from-code=UTF-8 --language=JavaScript \
  --keyword=i18n:1 --keyword=i18nc:1c,2 --keyword=i18np:1,2 --keyword=i18ncp:1c,2,3 \
  -o po/plasma_applet_org.mops1k.win11tasks.pot
xgettext --from-code=UTF-8 --language=C++ \
  --keyword=i18n:1 --keyword=i18nc:1c,2 --keyword=i18np:1,2 --keyword=i18ncp:1c,2,3 \
  -j -o po/plasma_applet_org.mops1k.win11tasks.pot *.cpp *.h
msgmerge --update po/ru/plasma_applet_org.mops1k.win11tasks.po \
  po/plasma_applet_org.mops1k.win11tasks.pot
```

Компиляция и установка `.mo` выполняются автоматически при сборке и установке
(макрос `ki18n_install(po)`): файл попадает в
`~/.local/share/locale/<язык>/LC_MESSAGES/<домен>.mo`.

## Лицензия

GPL-3.0 (см. `LICENSE`). Происхождение кода и список изменений относительно
источника — в `NOTICE.md`.
