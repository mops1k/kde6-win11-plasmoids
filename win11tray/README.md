# Win11 Tray

Плазмоид KDE Plasma 6, заменяющий системный трей и повторяющий вид
системного трея Windows 11: иконки статуса (SNI), выдвижная панель скрытых
иконок, шеврон «^» и quick settings (сеть, Bluetooth, звук, яркость, батарея,
буфер обмена, уведомления, устройства, медиаплеер).

Апплет — C++ (`Plasma::Containment`), потому что только C++-модель умеет
меню SNI, активацию по клику, дочерние плазмоиды и настройки видимости
элементов. Основа — трей из
[KDE-Windows-Modern](https://github.com/Jeysef/KDE-Windows-Modern)
(GPL-3.0), см. `NOTICE.md`.

- id апплета: `org.mops1k.win11tray`
- имя в Plasma: **Win11 Tray**

## Требования

- KDE Plasma 6 (проверено на plasma-workspace 6.7.5, Qt 6.11.2, KF6 6.30)
- для сборки: `cmake`, `extra-cmake-modules`, `gcc`, `qt6-base`,
  `qt6-declarative`, `kpackage`, `kconfig`, `ki18n`, `kcoreaddons`,
  `kwindowsystem`, `kio`, `kiconthemes`, `kitemmodels`, `kservice`,
  `kxmlgui`, `kjobwidgets`, `kcmutils`, `plasma-framework` (libplasma)

## Сборка и установка в ~/.local (без root)

```bash
./scripts/install-local.sh
```

Скрипт собирает Release-версию и кладёт плагин в
`~/.local/lib/qt6/plugins/plasma/applets/org.mops1k.win11tray.so`,
затем перезапускает plasmashell.

Ручной вариант:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$HOME/.local"
cmake --build build --parallel "$(nproc)"
./scripts/install-local.sh --no-build
```

Qt не ищет плагины в `~/.local/lib/qt6/plugins` сам, поэтому установщик
создаёт drop-in systemd-юнита plasmashell —
`~/.config/systemd/user/plasma-plasmashell.service.d/10-win11tray-plugin-path.conf`
со строкой `Environment=QT_PLUGIN_PATH=%h/.local/lib/qt6/plugins`.

QML вкомпилирован в `.so`: отдельный KPackage в
`~/.local/share/plasma/plasmoids/org.mops1k.win11tray` ставить нельзя —
вместо поповера будет пустой тёмный прямоугольник.

## Включение в панель

```bash
./scripts/switch-tray.sh
```

Скрипт делает бэкап `~/.config/plasma-org.kde.plasma.desktop-appletsrc`,
добавляет `org.mops1k.win11tray` в панель и убирает системный
`org.kde.plasma.systemtray`. Альтернатива — вручную: правый клик по панели →
«Настроить панель» → «Добавить виджеты» → **Win11 Tray**, затем удалить
системный «Системный лоток».

## Откат

```bash
./scripts/uninstall-local.sh            # убрать плагин из ~/.local
./scripts/uninstall-local.sh --restore  # вернуть панель к системному трею из бэкапа
```

## Устранение неполадок

- **Апплет не появляется в списке виджетов** — проверьте, что
  `~/.local/lib/qt6/plugins/plasma/applets/org.mops1k.win11tray.so` на месте
  и что plasmashell запущен с `QT_PLUGIN_PATH` (drop-in выше), затем
  `systemctl --user restart plasma-plasmashell.service`.
- **Поповер — пустой тёмный прямоугольник** — установлен KPackage вместо
  C++-плагина: удалите `~/.local/share/plasma/plasmoids/org.mops1k.win11tray`.
- **Трей пропал после обновления Plasma** — плагин собран под конкретную
  версию KF6/Plasma, пересоберите: `./scripts/install-local.sh`.

## Перетаскивание иконок

Как в Windows 11 — иконки трея можно перетаскивать мышью:

- **Закрепить в панели** — перетащите иконку из поповера скрытых значков
  (шеврон «^») в панель.
- **Скрыть в поповер** — перетащите иконку из панели в открытый поповер.
- **Изменить порядок** — перетащите иконку между другими иконками в панели:
  место запоминается и сохраняется, когда приложение снова открывается.

Работает и для иконок приложений (StatusNotifier), и для иконок виджетов
(батарея, раскладка, погода и т. п.). При перетаскивании в панели показывается
индикатор места вставки, в поповере — подсветка области.

Хранение: порядок — настройка `itemOrder`, видимость — `shownItems` и
`hiddenItems` в конфигурации апплета.

## Переводы

Строки интерфейса обёрнуты в `i18n()`/`i18nc()`; шаблон строк —
`po/<домен>.pot`, переводы — `po/<язык>/<домен>.po` (сейчас `po/ru/`).
Домен: `plasma_applet_org.mops1k.win11tray` (= `TRANSLATION_DOMAIN` в `CMakeLists.txt`).

Обновить шаблон после правки строк:

```bash
find contents \( -name '*.qml' -o -name '*.js' \) -print0 | xargs -0 xgettext \
  --from-code=UTF-8 --language=JavaScript \
  --keyword=i18n:1 --keyword=i18nc:1c,2 --keyword=i18np:1,2 --keyword=i18ncp:1c,2,3 \
  --keyword=xi18n:1 --keyword=xi18nc:1c,2 --keyword=xi18np:1,2 --keyword=xi18ncp:1c,2,3 \
  -o po/plasma_applet_org.mops1k.win11tray.pot
msgmerge --update po/ru/plasma_applet_org.mops1k.win11tray.po \
  po/plasma_applet_org.mops1k.win11tray.pot
```

Компиляция и установка `.mo` выполняются автоматически при сборке и установке
(макрос `ki18n_install(po)`): файл попадает в
`~/.local/share/locale/<язык>/LC_MESSAGES/<домен>.mo`.

## Лицензия

GPL-3.0 (см. `LICENSE`). Происхождение кода и список изменений относительно
источника — в `NOTICE.md`.
