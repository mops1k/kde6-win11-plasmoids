# AGENTS.md — проект win11keyboardlayout

Индикатор раскладки клавиатуры в стиле Windows 11 для панели KDE Plasma 6.
Корень проекта: `/home/deck/vibecoding/plasmoids/win11keyboardlayout`.

## Что это

QML-плазмоид `org.mops1k.win11keyboardlayout` (KPackageStructure
`Plasma/Applet`), показывающий в трее текстовый код раскладки (`РУС`, `ENG`)
с настройками шрифта. C++ нет, сборки нет: используется системный QML-модуль
`org.kde.plasma.workspace.keyboardlayout` и KConfigXT
(`contents/config/main.xml`).

## Установка

```bash
./scripts/install-local.sh [--no-restart]
./scripts/switch-widget.sh [--revert]     # правка appletsrc при остановленном plasmashell
./scripts/uninstall-local.sh [--restore]
```

Плазмоид ставится в `~/.local/share/plasma/plasmoids/` через `kpackagetool6`.

## Правила проекта

- Язык общения, комментариев в документации и сообщений задач — русский;
  сообщения коммитов — английский.
- Коммиты и push — только по прямой просьбе пользователя.
- Правка `~/.config/plasma-org.kde.plasma.desktop-appletsrc` — только с
  бэкапом и при остановленном plasmashell (скрипты делают это сами).
- Перед правкой существующего файла — прочитать его.
- Лицензия — GPL-3.0-or-later; SPDX-заголовки не удалять.
- Настройка должна сразу попадать в `contents/config/main.xml` и на страницу
  `contents/ui/config/ConfigAppearance.qml` (свойство `cfg_<entry>`).

## Структура

- `metadata.json` — id, имя, лицензия; обязателен
  `X-Plasma-NotificationAreaCategory` (иначе трей не видит плазмоид).
- `contents/ui/main.qml` — `PlasmoidItem`, compact = текст кода, full = список
  раскладок; клик переключает раскладку.
- `contents/ui/LayoutCodes.js` — маппинг кода раскладки X11 в трёхбуквенный
  код Windows (ru→РУС, us→ENG, …) с резервом `uppercase(shortName)`.
- `contents/config/main.xml` — настройки (KConfigXT).
- `contents/ui/config/ConfigAppearance.qml` — страница «Внешний вид».
- `scripts/appletsrc-tool.py` — замена системного апплета раскладки в
  appletsrc (см. README, грабли 2–3).
