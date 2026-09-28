# Attribution / Происхождение кода

`win11tray` — самостоятельный плазмоид KDE Plasma 6 (id апплета
`org.mops1k.win11tray`), заменяющий системный трей и повторяющий вид
системного трея Windows 11.

## Источники

1. **KDE-Windows-Modern** — https://github.com/Jeysef/KDE-Windows-Modern
   Copyright (C) Jeysef, лицензия GPL-3.0.
   Взято: каталог `plasma/applets/org.kde.windowsmodern.systemtray`
   (C++ backend + QML UI + вендоренный `libdbusmenuqt`), то есть
   непосредственно основа этого проекта. Исходные SPDX-заголовки файлов
   сохранены без изменений: часть файлов `GPL-2.0-or-later`, часть
   `LGPL-2.0-or-later`.

2. **plasma-workspace** (upstream, KDE) — https://invent.kde.org/plasma/plasma-workspace
   Раздел `applets/systemtray` и `libdbusmenuqt` — первоисточник C++ кода,
   от которого происходит пункт 1. Лицензия LGPL-2.0-or-later.

3. **libdbusmenu-qt / libdbusmenuqt** — реализация спецификации
   `com.canonical.dbusmenu` (LGPL-2.0-or-later), вендорена в исходниках
   пункта 1.

## Лицензия проекта

Производная работа распространяется под **GPL-3.0** (см. `LICENSE`), как и
проект-источник KDE-Windows-Modern. Файлы сохраняют собственные
SPDX-идентификаторы; для файлов с `GPL-2.0-or-later` переход на GPL-3.0
разрешён условием «or later».

## Что изменено относительно источника

- id апплета: `org.kde.windowsmodern.systemtray` → `org.mops1k.win11tray`;
- имя в `metadata.json`: `Win11 Tray`, версия `0.1.0`, лицензия
  `GPL-3.0-or-later`, убраны ссылки на чужой репозиторий;
- домен перевода: `plasma_applet_org.mops1k.win11tray`;
- темы по умолчанию в `contents/config/main.xml` переведены с тем
  `org.kde.windowsmodern.*` на системные `org.kde.breezedark.desktop`
  и `org.kde.breeze.desktop`;
- добавлены собственные скрипты сборки/установки в `~/.local` и документация.
