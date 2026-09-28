#!/usr/bin/env python3
# Правка ~/.config/plasma-org.kde.plasma.desktop-appletsrc: замена системного
# апплета раскладки (org.kde.plasma.keyboardlayout) на
# org.mops1k.win11keyboardlayout внутри контейнера трея.
#
# Почему не sed: системный апплет батареи объявлен EnabledByDefault, поэтому
# трей при каждой загрузке сам возвращает его в knownItems/extraItems и
# создаёт апплет заново. Чтобы системный не возвращался, его id должен
# остаться в knownItems, но отсутствовать в extraItems; апплет-дубликат
# удаляется, а единственный апплет-раскладка получает наш plugin id.
#
# Запускать только при остановленном plasmashell.
import re
import sys

SYS_APP = "org.kde.plasma.battery"
OUR_APP = "org.mops1k.win11battery"
TRAY_PLUGINS = ("org.mops1k.win11tray", "org.kde.plasma.systemtray")

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


def is_child_of(header, parent):
    return header.startswith(parent + "][Applets][") and header.count("[Applets]") == parent.count("[Applets]") + 1


def write_blocks(path, blocks):
    out = []
    for header, lines in blocks:
        if header is not None:
            out.append("[" + header + "]")
        out.extend(lines)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(out) + "\n")


def main():
    if len(sys.argv) != 3 or sys.argv[1] != "--apply":
        print("usage: appletsrc-tool.py --apply <appletsrc>", file=sys.stderr)
        return 2
    path = sys.argv[2]
    blocks = read_blocks(path)

    tray = next((b for b in blocks if b[0] and get_value(b, "plugin") in TRAY_PLUGINS), None)
    if tray is None:
        print("Не найден контейнер трея в appletsrc", file=sys.stderr)
        return 1
    tray_path = tray[0]

    children = [b for b in blocks if b[0] and is_child_of(b[0], tray_path)]
    sys_child = next((b for b in children if get_value(b, "plugin") == SYS_APP), None)
    our_child = next((b for b in children if get_value(b, "plugin") == OUR_APP), None)

    if our_child is None and sys_child is None:
        used = [int(b[0].split("][")[-1].rstrip("]")) for b in children]
        new_id = (max(used) + 1) if used else 1
        new_header = f"{tray_path}][Applets][{new_id}"
        our_child = [new_header, ["immutability=1", f"plugin={OUR_APP}"]]
        insert_at = blocks.index(tray) + 1
        blocks.insert(insert_at, our_child)
        print(f"==> Создан апплет батареи [{new_header}]")
    elif our_child is None:
        set_value(sys_child, "plugin", OUR_APP)
        our_child = sys_child
        print(f"==> Апплет [{sys_child[0]}] переведён на {OUR_APP}")
    elif sys_child is not None:
        drop = [b for b in blocks if b is sys_child or (b[0] and b[0].startswith(sys_child[0] + "["))]
        for b in drop:
            blocks.remove(b)
        print(f"==> Удалён дубликат системного апплета батареи [{sys_child[0]}]")

    general = next((b for b in blocks if b[0] == f"{tray_path}][General"), None)
    if general is None:
        general = [f"{tray_path}][General", []]
        blocks.insert(blocks.index(tray) + 1, general)

    extra = [x for x in (get_value(general, "extraItems") or "").split(",") if x]
    extra = [x for x in extra if x != SYS_APP]
    if OUR_APP not in extra:
        extra.append(OUR_APP)
    set_value(general, "extraItems", ",".join(extra))

    known = [x for x in (get_value(general, "knownItems") or "").split(",") if x]
    if SYS_APP not in known:
        known.append(SYS_APP)
    if OUR_APP not in known:
        known.append(OUR_APP)
    set_value(general, "knownItems", ",".join(known))

    write_blocks(path, blocks)
    print(f"==> extraItems: {SYS_APP} -> {OUR_APP}; {SYS_APP} оставлен в knownItems (трей не вернёт его в трей)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
