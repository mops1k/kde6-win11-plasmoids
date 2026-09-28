# AGENTS.md — проект win11tasks

Плазмоид-таскбар (icons-only) для KDE Plasma 6 в стиле Windows 11.
Корень проекта: `/home/deck/vibecoding/plasmoids/win11tasks`.

## Что это

C++-апплет Plasma (`org.mops1k.win11tasks`) на базе таскбара
`org.kde.plasma.taskmanager` из plasma-desktop, взятый из набора
`Jeysef/KDE-Windows-Modern` (GPL-3.0). QML-исходники регистрируются в qrc
через `ecm_target_qml_sources`, поэтому `.so` самодостаточен: отдельный
KPackage в `~/.local/share/plasma/plasmoids/` ставить НЕЛЬЗЯ.

## Сборка и установка

```bash
./scripts/install-local.sh          # сборка + установка в ~/.local + рестарт plasmashell
./scripts/install-local.sh --no-build
./scripts/uninstall-local.sh [--restore]
./scripts/switch-tasks.sh [--revert]   # замена системного icontasks в панели
```

Префикс установки — `$HOME/.local`; плагин попадает в
`~/.local/lib/qt6/plugins/plasma/applets/`. Plasma видит его только при
`QT_PLUGIN_PATH=$HOME/.local/lib/qt6/plugins` (drop-in plasmashell; общий с
проектом `win11tray`).

## Правила проекта

- Язык общения, комментариев в документации и сообщений задач — русский;
  сообщения коммитов — английский.
- Коммиты и push — только по прямой просьбе пользователя.
- Правка `~/.config/plasma-org.kde.plasma.desktop-appletsrc` — только с
  бэкапом (скрипты делают его сами).
- Перед правкой существующего файла — прочитать его.
- Секреты и локальные конфиги в репозиторий не попадают.
- Лицензия проекта — GPL-3.0; SPDX-заголовки файлов не удалять и не менять.

## Структура

- `CMakeLists.txt` — сборка апплета (`plasma_add_applet` + `ecm_target_qml_sources`
  + `kconfig_add_kcfg_files`).
- `metadata.json` — id, имя, лицензия апплета (`X-Plasma-Provides: multitasking`).
- `backend.cpp/.h` — модель задач (C++), `smartlauncher*` — смарт-лаунчер,
  `floatingtooltip*` — окно тултипа с превью.
- `contents/ui/` — QML: `main.qml`, `TaskList.qml`, `Task.qml`,
  `ToolTipDelegate.qml`, `ConfigAppearance.qml`, `ConfigBehavior.qml`,
  `code/LayoutMetrics.js`, `code/TaskTools.js`.
- `contents/config/main.xml` — настройки апплета (KConfigXT).
- `scripts/` — сборка, установка, откат, замена таскбара.

## Важное про id

QML импортирует C++-модуль апплета как
`plasma.applet.org.mops1k.win11tasks` — при смене id нужно править и импорт,
и сравнения `Plasmoid.pluginName === "org.mops1k.win11tasks"` (ветки
icons-only, отступы, бейджи).
