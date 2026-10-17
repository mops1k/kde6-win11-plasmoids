#!/usr/bin/env bash
# Установка плазмоидов Win11 из готового релиза GitHub — без сборки из
# исходников. Скачивает архив релиза, проверяет sha256, распаковывает в
# кэш и запускает установщик из самого архива (install.sh --prebuilt-dir).
#
# Однострочник (после публикации релиза):
#   curl -fsSL https://raw.githubusercontent.com/mops1k/kde6-win11-plasmoids/main/scripts/online-install.sh | bash
#
#   --tag <tag>          версия релиза (по умолчанию — последний)
#   --from <файл|url>    взять архив не с GitHub (локальный файл или прямая ссылка)
#   --repo <owner/name>  репозиторий GitHub (по умолчанию mops1k/kde6-win11-plasmoids)
#   --cache-dir <dir>    куда качать (по умолчанию ~/.cache/win11-plasmoids)
#   --clean              удалить кэш перед скачиванием
#   --no-verify          не проверять sha256
#   --list               показать релизы репозитория и выйти
#   -h, --help           эта справка
#
# Дальше идут аргументы установщика: --all, --only win11tray,win11clock,
# --no-switch, --no-restart, --no-fallback (без них — интерактивный выбор).
set -euo pipefail

REPO="${WIN11_REPO:-mops1k/kde6-win11-plasmoids}"
CACHE_DIR="${WIN11_CACHE_DIR:-$HOME/.cache/win11-plasmoids}"
TAG=""
FROM=""
CLEAN=0
VERIFY=1
SHOW_LIST=0
declare -a INSTALL_ARGS=()

usage() { awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; }

fail() { echo "Ошибка: $*" >&2; exit 2; }

while (($#)); do
    case "$1" in
        --tag) shift; (($#)) || fail "--tag требует значение"; TAG="$1" ;;
        --tag=*) TAG="${1#--tag=}" ;;
        --from) shift; (($#)) || fail "--from требует файл или ссылку"; FROM="$1" ;;
        --from=*) FROM="${1#--from=}" ;;
        --repo) shift; (($#)) || fail "--repo требует owner/name"; REPO="$1" ;;
        --repo=*) REPO="${1#--repo=}" ;;
        --cache-dir) shift; (($#)) || fail "--cache-dir требует каталог"; CACHE_DIR="$1" ;;
        --cache-dir=*) CACHE_DIR="${1#--cache-dir=}" ;;
        --clean) CLEAN=1 ;;
        --no-verify) VERIFY=0 ;;
        --list) SHOW_LIST=1 ;;
        --all) INSTALL_ARGS+=(--all) ;;
        --only) shift; (($#)) || fail "--only требует список"; INSTALL_ARGS+=(--only "$1") ;;
        --only=*) INSTALL_ARGS+=(--only "${1#--only=}") ;;
        --no-switch|--no-restart|--no-fallback) INSTALL_ARGS+=("$1") ;;
        --) shift
            INSTALL_ARGS+=("$@")
            break
            ;;
        -h|--help) usage; exit 0 ;;
        *) fail "неизвестный аргумент: $1 (см. --help)" ;;
    esac
    shift
done

for tool in tar python3; do
    command -v "$tool" >/dev/null 2>&1 || fail "не найдено: $tool"
done
[ -n "$FROM" ] || command -v curl >/dev/null 2>&1 || fail "не найдено: curl"

# --clean пересоздаёт кэш; защита от случайного --cache-dir на корень или $HOME.
if [ "$CLEAN" = 1 ]; then
    case "$CACHE_DIR" in
        ""|"/"|"$HOME"|"$HOME/") fail "--clean отказано: подозрительный --cache-dir '$CACHE_DIR'" ;;
    esac
    rm -rf "$CACHE_DIR"
fi
mkdir -p "$CACHE_DIR"

sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"
    fi
}

api_curl() {
    local url="$1"
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        curl -fsSL -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer $GITHUB_TOKEN" "$url"
    else
        curl -fsSL -H "Accept: application/vnd.github+json" "$url"
    fi
}

# Разбор JSON релиза: печатает "<тег> <url архива> <url sha256 или -> <имя файла>".
parse_release() {
    python3 - <<'PY'
import json
import sys

data = json.load(sys.stdin)
assets = data.get("assets") or []
tarball = next((a for a in assets if a["name"].endswith(".tar.gz")), None)
if tarball is None:
    sys.exit("в релизе нет архива *.tar.gz")
checksum = next((a for a in assets if a["name"] == tarball["name"] + ".sha256"), None)
print(data.get("tag_name") or "unknown",
      tarball["browser_download_url"],
      checksum["browser_download_url"] if checksum else "-",
      tarball["name"])
PY
}

if [ "$SHOW_LIST" = 1 ]; then
    api_curl "https://api.github.com/repos/$REPO/releases?per_page=20" | python3 -c '
import json, sys
for rel in json.load(sys.stdin):
    assets = ", ".join(a["name"] for a in rel.get("assets", []))
    print("%-14s %s  %s" % (rel.get("tag_name", "?"), (rel.get("published_at") or "")[:10], assets))'
    exit 0
fi

ARCHIVE=""
LOCAL_ARCHIVE=0
DOWNLOAD_URL=""
CHECKSUM_URL=""

if [ -n "$FROM" ]; then
    if [ -f "$FROM" ]; then
        ARCHIVE="$(cd "$(dirname "$FROM")" && pwd)/$(basename "$FROM")"
        LOCAL_ARCHIVE=1
        TAG="${TAG:-local}"
        if [ -f "$ARCHIVE.sha256" ]; then
            CHECKSUM_URL="file:$ARCHIVE.sha256"
        fi
    else
        asset_name="$(basename "${FROM%%\?*}")"
        TAG="${TAG:-${asset_name%.tar.gz}}"
        ARCHIVE="$CACHE_DIR/$TAG/$asset_name"
        DOWNLOAD_URL="$FROM"
        CHECKSUM_URL="$FROM.sha256"
    fi
else
    if [ -n "$TAG" ]; then
        api="https://api.github.com/repos/$REPO/releases/tags/$TAG"
    else
        api="https://api.github.com/repos/$REPO/releases/latest"
    fi
    echo "==> Поиск релиза: $REPO${TAG:+ (тег $TAG)}"
    release_info="$(api_curl "$api")" ||
        fail "не удалось получить релиз (нет релиза у $REPO или исчерпан лимит GitHub API)"
    read -r found_tag asset_url checksum_url asset_name <<<"$(printf '%s' "$release_info" | parse_release)" ||
        fail "в релизе $REPO нет архива плазмоидов (*.tar.gz)"
    TAG="$found_tag"
    ARCHIVE="$CACHE_DIR/$TAG/$asset_name"
    DOWNLOAD_URL="$asset_url"
    [ "$checksum_url" = "-" ] || CHECKSUM_URL="$checksum_url"
fi

if [ "$LOCAL_ARCHIVE" = 1 ]; then
    echo "==> Локальный архив: $ARCHIVE"
elif [ -f "$ARCHIVE" ] && [ "$CLEAN" = 0 ]; then
    echo "==> Архив уже в кэше: $ARCHIVE"
else
    echo "==> Скачивание: $DOWNLOAD_URL"
    mkdir -p "$(dirname "$ARCHIVE")"
    curl -fL --progress-bar -o "$ARCHIVE.part" "$DOWNLOAD_URL" || fail "не удалось скачать $DOWNLOAD_URL"
    mv "$ARCHIVE.part" "$ARCHIVE"
fi

if [ "$VERIFY" = 1 ]; then
    expected=""
    checksum_file=""
    case "$CHECKSUM_URL" in
        ""|"-") : ;;
        file:*) checksum_file="${CHECKSUM_URL#file:}" ;;
        *)
            checksum_file="$ARCHIVE.sha256"
            if ! curl -fsSL -o "$checksum_file" "$CHECKSUM_URL"; then
                checksum_file=""
                echo "==> ВНИМАНИЕ: не удалось скачать .sha256" >&2
            fi
            ;;
    esac
    if [ -n "$checksum_file" ] && [ -f "$checksum_file" ]; then
        expected="$(awk '{print $1}' "$checksum_file" | head -1)"
    fi
    if [ -z "$expected" ]; then
        echo "==> ВНИМАНИЕ: контрольная сумма не найдена — проверка sha256 пропущена" >&2
    else
        actual="$(sha256_of "$ARCHIVE")"
        if [ "$expected" != "$actual" ]; then
            fail "sha256 не совпал:
      ожидалось $expected
      получено  $actual
      удалите $ARCHIVE и повторите"
        fi
        echo "==> sha256 совпал: $actual"
    fi
fi

STAGE="$CACHE_DIR/$TAG/unpacked"
rm -rf "$STAGE"
mkdir -p "$STAGE"
echo "==> Распаковка: $ARCHIVE"
tar -xzf "$ARCHIVE" -C "$STAGE"

RELEASE_DIR=""
for candidate in "$STAGE"/*; do
    [ -f "$candidate/scripts/install.sh" ] || continue
    RELEASE_DIR="$candidate"
    break
done
[ -n "$RELEASE_DIR" ] || fail "в архиве нет scripts/install.sh — это не релиз плазмоидов"
[ -d "$RELEASE_DIR/prebuilt" ] || fail "в архиве нет каталога prebuilt — релиз собран без готовых артефактов"

echo "==> Релиз распакован: $RELEASE_DIR"
echo "==> Установка без сборки (готовые артефакты в prebuilt/)"
exec bash "$RELEASE_DIR/scripts/install.sh" --prebuilt-dir "$RELEASE_DIR/prebuilt" "${INSTALL_ARGS[@]}"
