# AGENTS.md — монорепозиторий plasmoids

Корень: `/home/deck/vibecoding/plasmoids`. Пять плазмоидов Win11 для KDE
Plasma 6: `win11tray`, `win11tasks` (C++/CMake) и `win11battery`,
`win11clock`, `win11keyboardlayout` (QML/KPackage). Состав и команды — в
`README.md`.

## Правила монорепо

- Язык общения, документации и комментариев — русский; сообщения коммитов —
  английский, краткая императивная строка.
- Коммиты и push — только по прямой просьбе пользователя. Remote не настроен.
- В коммит не попадают: референс-скриншоты (`Screenshot*.png`), `build/`,
  `build-*/`, `dist/`, `*.plasmoid`, `.dsh/` (планы и состояние сессий DSH).
- Идентичность репозитория задана локально: `mops1k`
  <mops1k@users.noreply.github.com>.
- Установка всех плазмоидов — `./scripts/install.sh` (whiptail-выбор,
  `--all`, `--only`, `--list`, `--no-restart`); реальная установка меняет
  `~/.local` и перезапускает `plasmashell`.
- Проектные правила и детали сборки держать в `AGENTS.md` соответствующего
  каталога, а не здесь.
- Перед правкой файла — прочитать его; деструктивные операции (удаление,
  перезапись, `git reset --hard`, force-push) — только с подтверждением.
- Правка `~/.config/plasma-org.kde.plasma.desktop-appletsrc` — только с
  бэкапом и при остановленном `plasmashell` (скрипты проектов делают это сами).

## Проверка изменений

- C++: `cmake -S <проект> -B <проект>/build -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_INSTALL_PREFIX=$HOME/.local && cmake --build <проект>/build`.
- QML: `kpackagetool6 --type Plasma/Applet --install|--upgrade <проект>`.
- Журнал после установки: `journalctl --user -u plasma-plasmashell -b --since "-40s"`
  — искать `error when loading`, `TypeError`, `ReferenceError`.
- Визуальную проверку в панели делает пользователь; агент снимает скриншот
  только по прямой просьбе.
