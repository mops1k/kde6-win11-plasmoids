# AGENTS.md — проект win11battery

Индикатор батареи с процентом внутри иконки для панели KDE Plasma 6.
Корень проекта: `/home/deck/vibecoding/plasmoids/win11battery`.

## Что это

KPackage-плазмоид `org.mops1k.win11battery` (`KPackageStructure:
Plasma/Applet`), заменяющий системный `org.kde.plasma.battery` в трее
win11tray. Системный QML апплета `powerdevil` (v6.7.5) скопирован целиком
(меню/поповер системные), изменена только компактная иконка — процент внутри
батареи. C++ не собирается: используются установленные системные QML-модули
`org.kde.plasma.private.batterymonitor` и `org.kde.plasma.private.battery`
(пакет `powerdevil`).

## Установка и упаковка

```bash
./scripts/package.sh                     # dist/org.mops1k.win11battery-<версия>.plasmoid
kpackagetool6 --type Plasma/Applet --install dist/*.plasmoid
./scripts/install-local.sh [--no-restart]
./scripts/switch-battery.sh [--revert] [--no-restart]   # правка appletsrc при остановленном plasmashell
./scripts/uninstall-local.sh [--restore]
```

## Правила проекта

- Язык общения, комментариев в документации и сообщений задач — русский;
  сообщения коммитов — английский.
- Коммиты и push — только по прямой просьбе пользователя.
- Правка `~/.config/plasma-org.kde.plasma.desktop-appletsrc` — только с
  бэкапом и при остановленном plasmashell (скрипты делают это сами).
- Перед правкой существующего файла — прочитать его.
- SPDX-заголовки скопированных файлов powerdevil не удалять и не менять;
  скопированный QML — LGPL-2.0-or-later, наш код — GPL-3.0-or-later.
- Новая настройка попадает сразу в `contents/config/main.xml` и на страницу
  `contents/ui/config/ConfigAppearance.qml` (свойство `cfg_<entry>`).
- Обновляя QML из новой версии powerdevil, переносить правки в
  `CompactRepresentation.qml` заново (это единственный изменённый файл).

## Структура

- `metadata.json` — id, лицензия, `X-Plasma-NotificationAreaCategory: Hardware`,
  `X-Plasma-Provides: org.kde.plasma.powermanagement`.
- `contents/ui/BatteryIcon.qml` — своя рисованная иконка батареи (контур,
  носик, заливка по проценту, число внутри, молния).
- `contents/ui/CompactRepresentation.qml` — системное компактное
  представление с нашей иконкой; контракт `MouseArea` (свойства и
  `required property`) должен сохраняться — от него зависят `main.qml` и меню.
- `contents/ui/main.qml`, `PopupDialog.qml`, `BatteryItem.qml`,
  `PowerProfileItem.qml`, `InhibitionItem.qml`, `InhibitionHint.qml` —
  копия powerdevil 6.7.5 без изменений.
- `contents/config/main.xml`, `contents/ui/config/ConfigAppearance.qml` —
  настройки.
- `scripts/` — `package.sh` (архив), `install-local.sh`, `uninstall-local.sh`,
  `switch-battery.sh`, `appletsrc-tool.py`.
