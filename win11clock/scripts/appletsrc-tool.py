#!/usr/bin/env python3
# Правка ~/.config/plasma-org.kde.plasma.desktop-appletsrc: замена системных
# часов (org.kde.plasma.digitalclock) на org.mops1k.win11clock.
#
# Часы стоят в контейнере панели напрямую, поэтому достаточно сменить plugin
# у группы апплета: id группы сохраняется, значит позиция в панели не
# меняется, а настройки системных часов просто перестают читаться.
#
# Запускать только при остановленном plasmashell.
import re
import sys

SYS_APP = "org.kde.plasma.digitalclock"
OUR_APP = "org.mops1k.win11clock"

BLOCK_RE = re.compile(r"^\[(.+)\]\s*$")


def read_blocks(path):
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().splitlines()
    blocks = []
    current = None
    for line in lines:
        m = BLOCK_RE.match(line)
        if m:
            current = [m.group(1), []]
            blocks.append(current)
        elif current is None:
            blocks.append([None, [line]])
        else:
            current[1].append(line)
    return blocks


def get_value(block, key):
    prefix = key + "="
    for line in block[1]:
        if line.startswith(prefix):
            return line[len(prefix):]
    return None


def set_value(block, key, value):
    prefix = key + "="
    for i, line in enumerate(block[1]):
        if line.startswith(prefix):
            block[1][i] = prefix + value
            return
    block[1].append(prefix + value)


def write_blocks(path, blocks):
    out = []
    for header, lines in blocks:
        if header is not None:
            out.append("[" + header + "]")
        out.extend(lines)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(out) + "\n")


def del_value(block, key):
    prefix = key + "="
    block[1] = [line for line in block[1] if not line.startswith(prefix)]


def drop_inherited_popup_size(blocks):
    """Убирает popupWidth/popupHeight, оставшиеся от системных часов.

    Plasma берёт эти ключи из [Configuration] апплета и они перебивают
    Layout.preferredWidth/Height нашего поповера.
    """
    for block in blocks:
        if get_value(block, "plugin") != OUR_APP:
            continue
        conf = next((b for b in blocks if b[0] == block[0] + "][Configuration"), None)
        if conf is None:
            continue
        if get_value(conf, "popupWidth") is not None or get_value(conf, "popupHeight") is not None:
            del_value(conf, "popupWidth")
            del_value(conf, "popupHeight")
            print(f"==> Убраны унаследованные popupWidth/popupHeight у [{conf[0]}]")


def move_to_panel_end(blocks):
    """Ставит часы последними в панели — как в Windows 11, у правого края."""
    ours = next((b for b in blocks if get_value(b, "plugin") == OUR_APP), None)
    if ours is None:
        return
    our_id = ours[0].split("][")[-1].rstrip("]")
    parent = "][".join(ours[0].split("][")[:-1])
    general = next((b for b in blocks if b[0] == parent + "][General"), None)
    if general is None:
        return
    order = [x for x in (get_value(general, "AppletOrder") or "").split(";") if x]
    if not order:
        return
    if order[-1] == our_id:
        print("==> Часы уже последние в панели")
        return
    order = [x for x in order if x != our_id] + [our_id]
    set_value(general, "AppletOrder", ";".join(order))
    print(f"==> Часы перемещены в конец панели (AppletOrder: {get_value(general, 'AppletOrder')})")


def main():
    if len(sys.argv) != 3 or sys.argv[1] != "--apply":
        print("usage: appletsrc-tool.py --apply <appletsrc>", file=sys.stderr)
        return 2
    path = sys.argv[2]
    blocks = read_blocks(path)

    system = [b for b in blocks if get_value(b, "plugin") == SYS_APP]
    ours = [b for b in blocks if get_value(b, "plugin") == OUR_APP]

    if not system and ours:
        print("==> Системные часы уже заменены, правлю размеры поповера и порядок")
        drop_inherited_popup_size(blocks)
        move_to_panel_end(blocks)
        write_blocks(path, blocks)
        return 0
    if not system:
        print("Не найден апплет часов в appletsrc", file=sys.stderr)
        return 1

    keep = system[0]
    set_value(keep, "plugin", OUR_APP)
    print(f"==> Апплет [{keep[0]}] переведён на {OUR_APP}")

    # Если наш апплет уже был где-то ещё, убираем дубликат вместе с его
    # вложенными группами.
    for extra in system[1:]:
        drop = [b for b in blocks if b is extra or (b[0] and b[0].startswith(extra[0] + "["))]
        for b in drop:
            blocks.remove(b)
        print(f"==> Удалён дубликат часов [{extra[0]}]")

    drop_inherited_popup_size(blocks)
    move_to_panel_end(blocks)

    write_blocks(path, blocks)
    return 0


if __name__ == "__main__":
    sys.exit(main())
