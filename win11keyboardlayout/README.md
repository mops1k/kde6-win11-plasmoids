# win11keyboardlayout

Индикатор раскладки клавиатуры в стиле Windows 11 для KDE Plasma 6:
в трее панели отображается только текст — прописной трёхбуквенный код
раскладки (`РУС`, `ENG`, `УКР`, `DEU`, …), а внешний вид шрифта
настраивается.

Апплет: `org.mops1k.win11keyboardlayout`. Чистый QML (без C++ и сборки),
использует системный QML-модуль `org.kde.plasma.workspace.keyboardlayout`.
Заменяет системный апплет `org.kde.plasma.keyboardlayout` внутри контейнера
трея (win11tray).

## Установка

```bash
./scripts/install-local.sh              # kpackagetool6 --install/--upgrade + рестарт plasmashell
./scripts/install-local.sh --no-restart
./scripts/switch-widget.sh              # замена системного апплета раскладки в панели
./scripts/switch-widget.sh --revert     # вернуть системный апплет
./scripts/uninstall-local.sh [--restore]
```

Плазмоид ставится в `~/.local/share/plasma/plasmoids/org.mops1k.win11keyboardlayout`
(через `kpackagetool6 --type Plasma/Applet`).

## Настройки (страница «Внешний вид»)

- **Семейство шрифта** — пусто = шрифт темы Plasma.
- **Размер шрифта** — в пунктах, `0` = размер темы. Ячейка апплета в трее
  квадратная, поэтому размер работает как максимум: если текст не влезает,
  он ужимается (`Text.Fit`), а не исчезает.
- **Жирный**, **Курсив**.
- **Прописные буквы** (`РУС`/`ENG` против `рус`/`eng`).
- **Свой цвет текста** + выбор цвета (по умолчанию цвет темы Plasma).

Клик по виджету переключает на следующую раскладку, колесо мыши — вперёд/назад.
В полном виде (поповер) — список раскладок.

## Грабли (проверено на Plasma 6.7.5)

1. **`X-Plasma-NotificationAreaCategory` обязателен** в `metadata.json`.
   Без него трей не считает плазмоид элементом трея, не регистрирует его и
   возвращает системный апплет раскладки.
2. Системный `org.kde.plasma.keyboardlayout` объявлен `EnabledByDefault`,
   поэтому `PlasmoidRegistry` трея при каждой загрузке сам добавляет его в
   `knownItems`/`extraItems`, если его там нет, и создаёт апплет заново.
   Поэтому `scripts/appletsrc-tool.py` оставляет системный id **в
   `knownItems`**, но убирает его из `extraItems`.
3. Правку `~/.config/plasma-org.kde.plasma.desktop-appletsrc` нужно делать
   **при остановленном plasmashell**: иначе он при выходе перезаписывает
   файл своим состоянием из памяти (возвращает `extraItems` и создаёт
   дубликат апплета).
4. Переустановка плазмоида (`kpackagetool6 --upgrade`) порождает сигнал
   `packageUpdated`, трей пересоздаёт апплет с **новым id**, и настройки,
   записанные вручную в группу старого id, теряются. Настраивать нужно через
   диалог настроек виджета.
5. `KeyboardLayout.initialize()` из QML недоступен (не функция), но и не
   нужен: `layoutsList` заполняется сам.

## Проверка

```bash
QML_IMPORT_PATH=/usr/lib/qt6/qml qmllint contents/ui/main.qml
plasmawindowed org.mops1k.win11keyboardlayout      # окно виджета
```

Вид в панели проверяется так: снять панель при двух раскладках
(`busctl --user call org.kde.keyboard /Layouts org.kde.KeyboardLayouts setLayout u 0|1`),
найти изменившуюся область (`PIL`/`numpy`) и распознать её `tesseract`.

## Лицензия

GPL-3.0-or-later.
