# AGENTS.md — монорепозиторий plasmoids

Корень: `/home/deck/vibecoding/plasmoids`. Пять плазмоидов Win11 для KDE
Plasma 6: `win11tray`, `win11tasks` (C++/CMake) и `win11battery`,
`win11clock`, `win11keyboardlayout` (QML/KPackage). Состав и команды — в
`README.md`.

## Правила монорепо

- Язык общения, документации и комментариев — русский; сообщения коммитов —
  английский, краткая императивная строка.
- Коммиты и push — только по прямой просьбе пользователя. Remote:
  `origin` = `git@github.com:mops1k/kde6-win11-plasmoids.git`, рабочая ветка
  `main`. Из песочницы DSH (workspace-write) git к GitHub работает только с
  `GIT_SSH_COMMAND='ssh -F /dev/null -o BatchMode=yes'`.
- В коммит не попадают: референс-скриншоты (`Screenshot*.png`), `build/`,
  `build-*/`, `dist/`, `*.plasmoid`, `.dsh/` (планы и состояние сессий DSH).
- Идентичность репозитория задана локально: `mops1k`
  <mops1k@users.noreply.github.com>.
- Установка всех плазмоидов — `./scripts/install.sh` (zenity-чекбоксы,
  fallback whiptail → текстовое меню; `--all`, `--only`, `--list`,
  `--no-switch`, `--no-restart`); после установки отмеченные плазмоиды
  автоматически переключаются на свои в панели (один цикл stop/start
  `plasmashell`, правку appletsrc делают `win11*/scripts/switch-*.sh
  --no-restart`); реальная установка меняет `~/.local`.
- Режим «плавающей» панели — `./scripts/panel-floating.sh`
  (`status`/`off`/`on`/`toggle`, `--panel <id|all>`, `--no-persist`):
  в Plasma 6 панель сама открепляется на рабочем столе, и поповеры панельных
  апплетов заезжают на апплет. Состояние хранится в
  `[PlasmaViews][Panel <id>] floating=0/1` файла
  `~/.config/plasma-org.kde.plasma.desktop-appletsrc` (`PanelView::setFloating`
  в `shell/panelview.cpp`); без `--no-persist` скрипт пишет ключ при
  остановленном `plasmashell`, с бэкапом конфига.
- Проектные правила и детали сборки держать в `AGENTS.md` соответствующего
  каталога, а не здесь.
- Перед правкой файла — прочитать его; деструктивные операции (удаление,
  перезапись, `git reset --hard`, force-push) — только с подтверждением.
- Правка `~/.config/plasma-org.kde.plasma.desktop-appletsrc` — только с
  бэкапом и при остановленном `plasmashell` (скрипты проектов делают это сами).

## Релизы и установка без сборки

- Готовый релиз собирает `./scripts/package-release.sh` (`--tag`, `--out-dir`):
  архив `dist/win11-plasmoids-<тег>-<arch>-<distro>.tar.gz` с деревом репозитория
  и каталогом `prebuilt/` (собранные `.so`, QML-модуль уведомлений, `.plasmoid`,
  `.mo`, `manifest.json` с версиями Qt/Plasma и sha256), плюс `.sha256` и
  отдельные `.plasmoid`. Артефакты в git не попадают — это только ассеты релиза.
- CI: `.github/workflows/release.yml` на тег `v*` (и вручную) собирает архив в
  контейнере `archlinux:base-devel`, проверяет установку в подставной `HOME` и
  публикует GitHub Release. Процесс выпуска — `docs/RELEASE.md`.
- Установка без сборки: `scripts/online-install.sh` (`--tag`, `--from`,
  `--list`) скачивает релиз, проверяет sha256 и вызывает
  `scripts/install.sh --prebuilt-dir <архив>/prebuilt`; у `install.sh` также
  есть `--release [тег]` и `--no-fallback`.
- Общие функции для `prebuilt/` — `scripts/prebuilt-lib.sh`; каждый
  `win11*/scripts/install-local.sh` обязан принимать `--prebuilt-dir` и при
  нём не вызывать cmake/msgfmt.
- Релиз проверяется установкой в подставной `HOME`
  (`XDG_DATA_HOME`/`XDG_CONFIG_HOME` + `--no-restart --no-switch`), а не в
  живой `~/.local`.

## Проверка изменений

- C++: `cmake -S <проект> -B <проект>/build -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_INSTALL_PREFIX=$HOME/.local && cmake --build <проект>/build`.
- QML: `kpackagetool6 --type Plasma/Applet --install|--upgrade <проект>`.
- Журнал после установки: `journalctl --user -u plasma-plasmashell -b --since "-40s"`
  — искать `error when loading`, `TypeError`, `ReferenceError`.
- Визуальную проверку в панели делает пользователь; агент снимает скриншот
  только по прямой просьбе.
