# AGENTS.md — проект win11tray

Плазмоид-замена системного трея KDE Plasma 6 в стиле Windows 11.
Корень проекта: `/home/deck/vibecoding/plasmoids/win11tray`.

## Что это

C++-апплет Plasma (`org.mops1k.win11tray`) на базе трея из
`Jeysef/KDE-Windows-Modern` (GPL-3.0). QML-исходники регистрируются в qrc
через `ecm_target_qml_sources`, поэтому `.so` самодостаточен: отдельный
KPackage в `~/.local/share/plasma/plasmoids/` ставить НЕЛЬЗЯ (даёт пустой
тёмный прямоугольник вместо поповера).

## Сборка и установка

```bash
./scripts/install-local.sh          # сборка + установка в ~/.local + рестарт plasmashell
./scripts/install-local.sh --no-build
./scripts/uninstall-local.sh [--restore]
./scripts/switch-tray.sh            # замена системного трея в панели (с бэкапом appletsrc)
```

Префикс установки — `$HOME/.local`; плагин попадает в
`~/.local/lib/qt6/plugins/plasma/applets/`. Локальная копия .so имеет
приоритет над системной — это и есть механизм подмены без root.

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

- `CMakeLists.txt` — сборка апплета (`plasma_add_applet` + `ecm_target_qml_sources`).
- `metadata.json` — id, имя, лицензия апплета.
- `*.cpp`, `*.h` — C++ backend (модель SNI, настройки, DBusMenu importer).
- `contents/ui/` — QML: `main.qml` (панель), `ExpandedRepresentation.qml`
  и `ActionPanel.qml` (поповер quick settings), `components/`, `lib/`.
- `contents/config/main.xml` — настройки апплета (KConfigXT).
- `scripts/` — сборка, установка, откат, замена трея.
- `docs/` — заметки по архитектуре (при необходимости).
