# plasmoids — монорепозиторий плазмоидов Win11 для KDE Plasma 6

Пять апплетов в стиле Windows 11 для панели KDE Plasma 6 (Qt 6 / KF6).
Единый репозиторий нужен, чтобы изменения можно было откатывать через git.
Репозиторий: <https://github.com/mops1k/kde6-win11-plasmoids> (ветка `main`).

## Состав

| Каталог | id апплета | Тип | Что это |
| --- | --- | --- | --- |
| `win11tray/` | `org.mops1k.win11tray` | C++ / CMake | замена системного трея, сводный поповер быстрых настроек |
| `win11tasks/` | `org.mops1k.win11tasks` | C++ / CMake | таскбар icons-only с Win11-тултипами и превью |
| `win11battery/` | `org.mops1k.win11battery` | QML (KPackage) | батарея с процентом внутри, системное меню питания |
| `win11clock/` | `org.mops1k.win11clock` | QML (KPackage) | часы над датой, уведомления, календарь, «Не беспокоить» |
| `win11keyboardlayout/` | `org.mops1k.win11keyboardlayout` | QML (KPackage) | индикатор раскладки (РУС/ENG) с настройками шрифта |

Проектные детали (сборка, зависимости, грабли) — в `AGENTS.md` каждого каталога.

## Предпросмотр

Панель целиком (таскбар, трей, часы, индикатор раскладки, батарея):

![Панель](docs/screenshots/panel.png)

Поповер часов — календарь, история уведомлений и переключатель «Не беспокоить»:

![Поповер часов](docs/screenshots/popup-clock.png)

Поповер трея — сводные быстрые настройки (сеть, Bluetooth, ночной свет,
электропитание, «Не беспокоить», микрофон, точка доступа, яркость, громкость):

![Поповер трея](docs/screenshots/popup-tray.png)

Всплывающее уведомление (toast) от плазмоида часов:

![Всплывающее уведомление](docs/screenshots/toast.png)

## Установка

### 1. Требования

KDE Plasma 6 на Wayland (KWin). Проверено на Plasma 6.7.5, Qt 6.11.2, KF6 6.30
(CachyOS/Arch). Пакеты для сборки:

```bash
sudo pacman -S --needed base-devel cmake extra-cmake-modules kpackage gettext \
    qt6-wayland wayland plasma-workspace plasma-wayland-protocols \
    plasma-activities plasma-activities-stats libksysguard
```

Остальные Qt6/KF6-модули приходят зависимостями `plasma-workspace`.
`powerdevil` нужен для win11battery (системное меню «Питание и батарея»),
`python3` и `git` — для скриптов правки `appletsrc` и клонирования.

### 2. Клонирование

```bash
git clone https://github.com/mops1k/kde6-win11-plasmoids.git
cd kde6-win11-plasmoids
```

### 3. Установка плазмоидов

```bash
./scripts/install.sh              # интерактивный выбор (zenity-чекбоксы)
./scripts/install.sh --all        # установить все
./scripts/install.sh --only win11tray,win11clock
./scripts/install.sh --list       # только показать список
./scripts/install.sh --no-switch  # установить, но не трогать панель
```

Выбор плазмоидов — диалог `zenity --list --checklist`; если zenity или
графическая сессия недоступны, используется whiptail, затем текстовое
нумерованное меню.

Что делает установщик (всё в `~/.local`, root не нужен):

- C++-плазмоиды `win11tray` и `win11tasks` собираются CMake в `build/`,
  плагины ставятся в `~/.local/lib/qt6/plugins/plasma/applets`;
- QML-плазмоиды `win11battery`, `win11clock`, `win11keyboardlayout` ставятся
  `kpackagetool6` в `~/.local/share/plasma/plasmoids`;
- C++ QML-плагин уведомлений `win11clock/notifications` собирается в
  `~/.local/lib/qt6/qml/org/mops1k/win11clock/notifications`;
- переводы (`.mo`) ставятся в `~/.local/share/locale`;
- создаются systemd drop-in'ы `~/.config/systemd/user/plasma-plasmashell.service.d/`
  с `QT_PLUGIN_PATH` и `QML_IMPORT_PATH` — без них plasmashell не увидит
  C++-плагины;
- `plasmashell` перезапускается один раз в конце (`--no-restart` отключает).

После установки отмеченные плазмоиды автоматически переключаются на свои в
панели: `plasmashell` останавливается один раз, для каждого плазмоида
вызывается его `win11*/scripts/switch-*.sh --no-restart` (правка appletsrc с
бэкапом), затем панель запускается снова. Если в панели нет системного
апплета (например, `digitalclock`), установщик предупреждает и продолжает.
`--no-switch` отключает переключение, `--no-restart` пропускает и перезапуск,
и переключение.

### 4. Сборка панели как на скриншоте

Системные апплеты заменяются на свои уже при установке (`./scripts/install.sh`).
Отдельные скрипты нужны для ручной замены или отката: каждый делает бэкап
`~/.config/plasma-org.kde.plasma.desktop-appletsrc` и правит его при
остановленном `plasmashell`; `--revert` возвращает системный апплет,
`--no-restart` оставляет перезапуск панели вызывающему скрипту:

```bash
win11tasks/scripts/switch-tasks.sh            # таскбар вместо системного icontasks
win11tray/scripts/switch-tray.sh              # трей вместо системного
win11clock/scripts/switch-clock.sh            # часы вместо digitalclock
win11battery/scripts/switch-battery.sh        # батарея внутрь трея
win11keyboardlayout/scripts/switch-widget.sh  # индикатор раскладки внутрь трея
```

Затем панель (правый клик по панели → «Настроить панель…»):

- положение — снизу, высота — 48 px;
- снять «Плавающая», иначе в Plasma 6 панель сама открепляется на рабочем
  столе и поповеры заезжают на апплет (то же самое делает
  `./scripts/panel-floating.sh off`, см. ниже);
- порядок апплетов: таскбар | разделитель | трей (внутри него — батарея,
  индикатор раскладки и системные значки) | часы; часы — последними справа.

Тема оформления на скриншотах — Orchis-dark
(`com.github.vinceliuice.Orchis-dark`), но она не обязательна: плазмоиды
рисуются в текущей теме Plasma.

### 5. Режим «плавающей» панели

```bash
./scripts/panel-floating.sh status   # показать режим панелей
./scripts/panel-floating.sh off      # прикрепить к краям экрана
./scripts/panel-floating.sh on       # вернуть авто-открепление
./scripts/panel-floating.sh toggle   # переключить
```

Без `--no-persist` настройка сохраняется в `plasma-org.kde.plasma.desktop-appletsrc`
(`[PlasmaViews][Panel <id>] floating=0/1`) при остановленном `plasmashell`,
с бэкапом конфига.

### 6. Проверка

```bash
journalctl --user -u plasma-plasmashell -b --since "-40s" \
    | grep -iE "error when loading|TypeError|ReferenceError"
```

Вывод должен быть пустым. Если апплет не появился — проверить, что
`plasmashell` действительно перезапустился (drop-in'ы подхватываются только
при старте) и что в журнале нет ошибок загрузки QML.

## Откат

```bash
git log --oneline                 # история изменений
git diff <коммит> -- win11tray    # что изменилось в плазмоиде
git restore --source=<коммит> -- win11tray   # вернуть файлы из коммита
```

Откат установленного плазмоида — `scripts/uninstall-local.sh` в каталоге
проекта (`--restore` возвращает системный апплет в панель).

## Что не в репозитории

`.gitignore` исключает референс-скриншоты Win11 (`Screenshot*.png`),
`build/` и `build-*/`, `dist/` и `*.plasmoid`, а также `.dsh/` — планы и
рабочее состояние сессий DSH.
