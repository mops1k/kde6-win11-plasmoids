# Attribution / Происхождение кода

`win11tasks` — самостоятельный плазмоид KDE Plasma 6 (id апплета
`org.mops1k.win11tasks`), таскбар в стиле Windows 11: только иконки,
подсветка запущенных приложений, всплывающие подсказки с превью окон и
кнопкой закрытия.

## Источники

1. **KDE-Windows-Modern** — https://github.com/Jeysef/KDE-Windows-Modern
   Copyright (C) Jeysef, лицензия GPL-3.0.
   Взято: каталог `plasma/applets/org.kde.windowsmodern.icontasks`
   (C++ backend + QML UI), то есть непосредственно основа этого проекта.
   Исходные SPDX-заголовки файлов сохранены без изменений: часть файлов
   `GPL-2.0-or-later`, часть `LGPL-2.0-or-later`.

2. **plasma-desktop** (upstream, KDE) — https://invent.kde.org/plasma/plasma-desktop
   Раздел `applets/taskmanager` — первоисточник C++ backend (`backend.cpp`,
   `smartlauncher*`, `floatingtooltip*`) и большей части QML. Автор —
   Eike Hein <hein@kde.org> и другие участники KDE. Лицензия
   GPL-2.0-or-later / LGPL-2.0-or-later.

## Лицензия проекта

Производная работа распространяется под **GPL-3.0** (см. `LICENSE`), как и
проект-источник KDE-Windows-Modern. Файлы сохраняют собственные
SPDX-идентификаторы; для файлов с `GPL-2.0-or-later` переход на GPL-3.0
разрешён условием «or later».

## Что изменено относительно источника

- id апплета: `org.kde.plasma.icontasks` → `org.mops1k.win11tasks`
  (у авторов набор подменял системный плагин тем же id; здесь id свой);
- `metadata.json`: имя `Win11 Tasks`, версия `0.1.0`, лицензия
  `GPL-3.0-or-later`, убраны ссылки на чужой репозиторий;
- домен перевода и категория логирования: `plasma_applet_org.mops1k.win11tasks`,
  `org.mops1k.win11tasks`;
- QML-импорт C++-модуля апплета:
  `plasma.applet.org.kde.plasma.icontasks` → `plasma.applet.org.mops1k.win11tasks`;
- проверки `Plasmoid.pluginName === "org.kde.plasma.icontasks"` (icons-only
  ветки, отступы, бейджи) переведены на новый id;
- добавлены собственные скрипты сборки/установки в `~/.local` и документация.
