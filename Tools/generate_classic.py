"""
Generates DungeonQuestTracker/Data/Classic.lua from QuestieDB's Forever data.

Usage:
    pip install lupa
    git clone --depth 1 https://github.com/Questie/QuestieDB.git
    python generate_classic.py <path-to-QuestieDB> <path-to-DungeonQuestTracker>

QuestieDB is GPLv3. The generated file is derived data - keep the addon GPLv3
if you ever publish it.
"""
import sys
from pathlib import Path

from lupa import LuaRuntime

# key, display name, min level, max level, zoneOrSort area IDs (main first)
DUNGEONS = [
    ("RFC",  "Ragefire Chasm",       13, 18, [2437]),
    ("DM",   "The Deadmines",        17, 20, [1581, 10029]),
    ("WC",   "Wailing Caverns",      18, 24, [718]),
    ("SFK",  "Shadowfang Keep",      21, 26, [209, 10014, 10015, 10016, 10017, 10018, 10019, 236]),
    ("BFD",  "Blackfathom Deeps",    23, 28, [719, 10020, 10021, 2797]),
    ("STOCKS", "The Stockade",       25, 29, [717]),
    ("GNOMER", "Gnomeregan",         29, 34, [721, 133, 10030, 10031, 10032]),
    ("RFK",  "Razorfen Kraul",       30, 38, [491, 1717]),
    ("SM",   "Scarlet Monastery",    30, 46, [796, 6109, 6386, 10008, 10009, 10010]),
    ("ULDA", "Uldaman",              37, 45, [1337, 1517, 10033]),
    ("RFD",  "Razorfen Downs",       37, 45, [722, 1316]),
    ("ZF",   "Zul'Farrak",           40, 47, [1176, 978]),
    ("MARA", "Maraudon",             45, 51, [2100, 10000]),
    ("ST",   "Sunken Temple",        50, 55, [1477, 1417]),
    ("BRD",  "Blackrock Depths",     52, 60, [1584, 1585]),
    ("BRS",  "Blackrock Spire",      57, 60, [1583, 10003, 10004, 10005, 10006, 10007]),
    ("DIRE", "Dire Maul",            58, 60, [2557, 10022, 10023, 10024, 10025, 10026, 10027, 2577]),
    ("STRAT", "Stratholme",          58, 60, [2017, 10001, 2279]),
    ("SCHOLO", "Scholomance",        58, 60, [2057, 10011, 10012, 10013]),
]

QUEST_FLAG_SHARABLE = 8
SPECIAL_FLAG_REPEATABLE = 1

# questKeys (QuestieDB)
K_NAME, K_STARTED, K_REQLVL, K_QLVL, K_RACES, K_CLASSES = 1, 2, 4, 5, 6, 7
K_PREGROUP, K_PRESINGLE, K_EXCLUSIVE, K_ZONE = 12, 13, 16, 17
K_NEXT, K_QFLAGS, K_SFLAGS, K_PARENT = 22, 23, 24, 25
K_BREADCRUMB_FOR, K_AVAIL_STARTING = 27, 34

LUA_PRELUDE = """
QuestieDB = {}
ZoneDB = { private = {} }
Expansions = { Current = 1, Era = 1, Tbc = 2, Wotlk = 3, Cata = 4, MoP = 5 }
QuestieLoader = { ImportModule = function(_, name)
    if name == "QuestieDB" then return QuestieDB end
    if name == "ZoneDB" then return ZoneDB end
    if name == "Expansions" then return Expansions end
    return {}
end }
function UnitFactionGroup() return "Alliance" end
"""


def lua_list(t):
    if t is None:
        return []
    return [t[i] for i in range(1, len(t) + 1) if t[i] is not None]


def main(qdb_root: Path, addon_root: Path):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(LUA_PRELUDE)

    def run(path):
        lua.execute(path.read_text(encoding="utf-8"))

    data = qdb_root / "data" / "Forever"
    zones = qdb_root / "support" / "Forever" / "Zones"
    run(data / "foreverQuestDB.lua")
    run(data / "foreverNpcDB.lua")
    run(data / "foreverObjectDB.lua")
    run(data / "foreverItemDB.lua")
    run(zones / "dungeons.lua")
    run(zones / "areaIdToUiMapId.lua")

    g = lua.globals()
    load = g.load
    quests = load(g.QuestieDB.questData)()
    npcs = load(g.QuestieDB.npcData)()
    objects = load(g.QuestieDB.objectData)()
    items = load(g.QuestieDB.itemData)()
    area_to_map = load(g.ZoneDB.private.areaIdToUiMapId)()
    dungeon_entrances = g.ZoneDB.private.dungeons

    area_to_key = {}
    for key, _, _, _, areas in DUNGEONS:
        for a in areas:
            area_to_key[a] = key

    def ui_map(area_id):
        m = area_to_map[area_id]
        return int(m) if m else None

    def entrance(key):
        main_area = next(d[4][0] for d in DUNGEONS if d[0] == key)
        entry = dungeon_entrances[main_area]
        if entry is None:
            return None
        loc = entry[4][1]
        m = ui_map(loc[1])
        return {"map": m, "x": float(loc[2]), "y": float(loc[3])} if m else None

    def first_spawn(spawns):
        if spawns is None:
            return None
        for area_id in sorted(spawns.keys()):
            coords = spawns[area_id]
            if coords is None or coords[1] is None:
                continue
            m = ui_map(area_id)
            if m and m != 0:
                return {"map": m, "x": float(coords[1][1]), "y": float(coords[1][2])}
        return None

    def start_info(q):
        started = q[K_STARTED]
        if started is None:
            return None
        for npc_id in lua_list(started[1]):
            npc = npcs[npc_id]
            if npc is None:
                continue
            loc = first_spawn(npc[7])
            info = {"npc": npc[1]}
            if loc:
                info.update(loc)
            return info
        for obj_id in lua_list(started[2]):
            obj = objects[obj_id]
            if obj is None:
                continue
            loc = first_spawn(obj[4])
            info = {"object": obj[1]}
            if loc:
                info.update(loc)
            return info
        for item_id in lua_list(started[3]):
            item = items[item_id]
            return {"item": item[1] if item else "Item %d" % item_id}
        return None

    def build_entry(qid, dungeon_key):
        q = quests[qid]
        flags = q[K_QFLAGS] or 0
        entry = {
            "name": q[K_NAME],
            "d": dungeon_key,
            "lvl": q[K_QLVL],
            "min": q[K_REQLVL],
            "races": q[K_RACES],
            "classes": q[K_CLASSES],
            "pre": lua_list(q[K_PREGROUP]),
            "preAny": lua_list(q[K_PRESINGLE]),
            "excl": lua_list(q[K_EXCLUSIVE]),
            "next": q[K_NEXT],
            "parent": q[K_PARENT],
            "crumbFor": q[K_BREADCRUMB_FOR],
            "startWith": q[K_AVAIL_STARTING],
            "share": bool(int(flags) & QUEST_FLAG_SHARABLE),
            "start": start_info(q),
        }
        return entry

    selected = {}
    for qid in quests.keys():
        q = quests[qid]
        zone = q[K_ZONE]
        if zone is None or zone not in area_to_key:
            continue
        if (q[K_SFLAGS] or 0) & SPECIAL_FLAG_REPEATABLE:
            continue
        selected[int(qid)] = build_entry(qid, area_to_key[zone])

    # Pull in every prerequisite chain (non-dungeon helper quests) so the map can locate them.
    queue = list(selected.keys())
    while queue:
        qid = queue.pop()
        e = selected[qid]
        refs = e["pre"] + e["preAny"] + ([e["parent"]] if e["parent"] else []) + ([e["startWith"]] if e["startWith"] else [])
        for ref in refs:
            ref = int(ref)
            if ref in selected or quests[ref] is None:
                continue
            selected[ref] = build_entry(ref, None)
            queue.append(ref)

    # Entrance as fallback location for item-started / in-instance quests.
    entrances = {d[0]: entrance(d[0]) for d in DUNGEONS}

    out = []
    out.append("-- AUTO-GENERATED by Tools/generate_classic.py from QuestieDB (GPLv3) Forever data. DO NOT EDIT.")
    out.append("-- Re-run the generator instead. Hand-maintained data lives in Forever.lua.")
    out.append("local _, ns = ...")
    out.append("local D, Q = ns.Data.Dungeons, ns.Data.Quests")
    out.append("")
    for order, (key, name, lo, hi, _) in enumerate(DUNGEONS, start=1):
        ent = entrances[key]
        ent_s = "{ map = %d, x = %.2f, y = %.2f }" % (ent["map"], ent["x"], ent["y"]) if ent else "nil"
        out.append('D.%s = { name = %s, min = %d, max = %d, entrance = %s, isNew = false }'
                   % (key, lua_str(name), lo, hi, ent_s))
    out.append("")

    dungeon_count = {}
    for qid in sorted(selected):
        e = selected[qid]
        if e["d"]:
            dungeon_count[e["d"]] = dungeon_count.get(e["d"], 0) + 1
        out.append("Q[%d] = %s" % (qid, lua_entry(e)))

    target = addon_root / "Data" / "Classic.lua"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("\n".join(out) + "\n", encoding="utf-8")

    total = sum(dungeon_count.values())
    print("Wrote %s: %d dungeon quests, %d helper (prereq) quests" % (target, total, len(selected) - total))
    for key, *_ in DUNGEONS:
        print("  %-7s %d" % (key, dungeon_count.get(key, 0)))


def lua_str(s):
    return '"%s"' % str(s).replace("\\", "\\\\").replace('"', '\\"')


def lua_entry(e):
    parts = ["name = %s" % lua_str(e["name"])]
    if e["d"]:
        parts.append('d = "%s"' % e["d"])
    parts.append("lvl = %d" % (e["lvl"] or 0))
    parts.append("min = %d" % (e["min"] or 1))
    if e["races"]:
        parts.append("races = %d" % e["races"])
    if e["classes"]:
        parts.append("classes = %d" % e["classes"])
    for k in ("pre", "preAny", "excl"):
        if e[k]:
            parts.append("%s = { %s }" % (k, ", ".join(str(int(x)) for x in e[k])))
    for k in ("next", "parent", "crumbFor", "startWith"):
        if e[k]:
            parts.append("%s = %d" % (k, e[k]))
    if e["share"]:
        parts.append("share = true")
    s = e["start"]
    if s:
        sp = []
        for k in ("npc", "object", "item"):
            if k in s:
                sp.append("%s = %s" % (k, lua_str(s[k])))
        if "map" in s:
            sp.append("map = %d, x = %.2f, y = %.2f" % (s["map"], s["x"], s["y"]))
        parts.append("start = { %s }" % ", ".join(sp))
    return "{ " + ", ".join(parts) + " }"


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    main(Path(sys.argv[1]), Path(sys.argv[2]))
