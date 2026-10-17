# Выпуск релиза

Релиз — архив с готовыми артефактами, который ставится без сборки из
исходников: `dist/win11-plasmoids-<тег>-<arch>-<distro>.tar.gz`, рядом
`.sha256`, плюс отдельные `.plasmoid` — всё это ассеты GitHub Release.

## Что внутри архива

- дерево репозитория на момент тега (`scripts/`, `win11*/`, `README.md`);
- `prebuilt/manifest.json` — тег, коммит, хост сборки, требуемые версии
  Qt/Plasma, sha256 каждого готового файла;
- `prebuilt/qt6-plugins/plasma/applets/*.so` — `win11tray`, `win11tasks`;
- `prebuilt/qt6-qml/org/mops1k/win11clock/notifications/` — C++ QML-модуль
  всплывающих уведомлений;
- `prebuilt/plasmoids/*.plasmoid` — `win11battery`, `win11clock`,
  `win11keyboardlayout`;
- `prebuilt/locale/<язык>/LC_MESSAGES/*.mo` — переводы всех пяти плазмоидов.

## Обычный выпуск (CI)

1. При необходимости поднять `KPlugin.Version` в `*/metadata.json` (имя архива
   берётся из тега, версия внутри KPackage — из `metadata.json`).
2. Убедиться, что `main` собирается.
3. Поставить тег и запушить его:

   ```bash
   git tag -a v0.1.0 -m "v0.1.0"
   git push origin main --tags
   ```

4. Workflow `release` (`.github/workflows/release.yml`) в контейнере
   `archlinux:base-devel` соберёт архив, установит его в подставной `HOME`
   как проверку и приложит `*.tar.gz`, `*.sha256` и `*.plasmoid` к GitHub
   Release. Ручной запуск: Actions → release → Run workflow (тег + нужно ли
   публиковать релиз; без публикации удобно проверять сборку).

## Локальный выпуск (без CI)

```bash
./scripts/package-release.sh --tag v0.1.0          # в dist/
./scripts/package-release.sh --tag v0.1.0 --out-dir /tmp/rel --keep-stage
```

Проверка перед публикацией — установка в подставной `HOME`, живой `~/.local`
не затрагивается:

```bash
tmp="$(mktemp -d)"
tar -xzf dist/win11-plasmoids-v0.1.0-x86_64-arch.tar.gz -C "$tmp"
HOME="$tmp/home" XDG_DATA_HOME="$tmp/home/.local/share" \
  HOME="$tmp/home" ./scripts/install.sh \
    --prebuilt-dir "$tmp"/win11-plasmoids-v0.1.0/prebuilt --all --no-restart --no-switch
```

Публикация вручную:

```bash
gh release create v0.1.0 dist/*.tar.gz dist/*.sha256 dist/*.plasmoid \
  --title v0.1.0 --notes "Готовые артефакты: установка без сборки из исходников."
```

## Совместимость готовых бинарников

`prebuilt/*.so` слинкованы с Qt6/KF6/Plasma той системы, где шла сборка (в CI —
текущий образ `archlinux`), поэтому релиз адресован Arch-семейству x86_64.
При установке `scripts/install.sh` сверяет `requires.plasma_major_minor` и
`requires.qt_major_minor` из манифеста с системой и проверяет `ldd` каждого
`.so`; при несовпадении `win11tray`, `win11tasks` и QML-плагин `win11clock`
собираются из исходников (`.plasmoid` QML-плазмоидов остаются из релиза).
Планку версий в манифесте править вручную не нужно — она берётся со
сборочного хоста. `--no-fallback` запрещает откат и останавливает установку.

## Проверка после установки

```bash
journalctl --user -u plasma-plasmashell -b --since "-40s" \
    | grep -iE "error when loading|TypeError|ReferenceError"
```

Визуальную проверку в панели делает пользователь.
