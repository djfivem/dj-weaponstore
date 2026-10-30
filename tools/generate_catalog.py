#!/usr/bin/env python3
"""Build shared/data catalog Lua from an ox_inventory weapons file.

The upload is the source of truth. Every weapon key is emitted. Duplicate
component item keys keep the later scalar fields (Lua overwrite) and the
union of component hashes so none are dropped.
"""
from __future__ import annotations

import argparse
import re
from collections import Counter


class ParseError(Exception):
    pass


class Parser:
    def __init__(self, s: str):
        self.s = s
        self.n = len(s)
        self.i = 0

    def peek(self) -> str:
        return self.s[self.i] if self.i < self.n else ""

    def skip(self) -> None:
        s, n = self.s, self.n
        i = self.i
        while i < n:
            c = s[i]
            if c in " \t\r\n":
                i += 1
                continue
            if c == "-" and i + 1 < n and s[i + 1] == "-":
                i += 2
                if i + 1 < n and s[i] == "[" and s[i + 1] == "[":
                    end = s.find("]]", i + 2)
                    i = n if end < 0 else end + 2
                    continue
                while i < n and s[i] != "\n":
                    i += 1
                continue
            break
        self.i = i

    def parse(self):
        self.skip()
        if self.s.startswith("return", self.i):
            self.i += 6
        return self.value()

    def value(self):
        self.skip()
        c = self.peek()
        if c == "{":
            return self.table()
        if c in "'\"":
            return self.string()
        if c == "-" or c.isdigit():
            return self.number()
        m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", self.s[self.i :])
        if not m:
            raise ParseError(f"bad token at {self.i}: {self.s[self.i:self.i+40]!r}")
        word = m.group(0)
        self.i += len(word)
        self.skip()
        if self.peek() == "(":
            return self.call(word)
        if word == "true":
            return True
        if word == "false":
            return False
        if word == "nil":
            return None
        return {"ident": word}

    def call(self, name: str):
        assert self.peek() == "("
        self.i += 1
        args = []
        while True:
            self.skip()
            if self.peek() == ")":
                self.i += 1
                break
            args.append(self.value())
            self.skip()
            if self.peek() == ",":
                self.i += 1
                continue
            if self.peek() == ")":
                self.i += 1
                break
            raise ParseError(f"bad call at {self.i}")
        if name == "GetHashKey" and args and isinstance(args[0], str):
            return args[0]
        return {"call": name, "args": args}

    def string(self) -> str:
        q = self.s[self.i]
        self.i += 1
        out = []
        while self.i < self.n:
            c = self.s[self.i]
            if c == "\\":
                self.i += 1
                esc = self.s[self.i]
                out.append({"n": "\n", "t": "\t", "r": "\r", "\\": "\\", "'": "'", '"': '"'}.get(esc, esc))
                self.i += 1
                continue
            if c == q:
                self.i += 1
                return "".join(out)
            out.append(c)
            self.i += 1
        raise ParseError("unterminated string")

    def number(self):
        m = re.match(r"-?\d+(\.\d+)?([eE][+-]?\d+)?", self.s[self.i :])
        if not m:
            raise ParseError("bad number")
        token = m.group(0)
        self.i += len(token)
        if "." in token or "e" in token.lower():
            return float(token)
        return int(token)

    def table(self):
        assert self.peek() == "{"
        self.i += 1
        data = {}
        numeric = []
        named = False
        idx = 1
        while True:
            self.skip()
            if self.peek() == "}":
                self.i += 1
                break
            if self.peek() in ",;":
                self.i += 1
                continue
            if self.peek() == "[":
                named = True
                self.i += 1
                key = self.value()
                self.skip()
                if self.peek() != "]":
                    raise ParseError("expected ]")
                self.i += 1
                self.skip()
                if self.peek() != "=":
                    raise ParseError("expected =")
                self.i += 1
                val = self.value()
                data[key] = merge(data[key], val) if key in data else val
            else:
                m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", self.s[self.i :])
                if m:
                    word = m.group(0)
                    j = self.i + len(word)
                    k = j
                    while k < self.n and self.s[k] in " \t\r\n":
                        k += 1
                    if k < self.n and self.s[k] == "=":
                        named = True
                        self.i = k + 1
                        val = self.value()
                        data[word] = merge(data[word], val) if word in data else val
                    else:
                        val = self.value()
                        numeric.append(val)
                        data[idx] = val
                        idx += 1
                else:
                    val = self.value()
                    numeric.append(val)
                    data[idx] = val
                    idx += 1
            self.skip()
            if self.peek() in ",;":
                self.i += 1
        if not named:
            return numeric
        return data


def merge(old, new):
    if isinstance(old, dict) and isinstance(new, dict):
        out = dict(old)
        for key, val in new.items():
            if key in out:
                out[key] = merge(out[key], val)
            else:
                out[key] = val
        return out
    if isinstance(old, list) and isinstance(new, list):
        seen = set()
        out = []
        for item in old + new:
            marker = item if isinstance(item, (str, int, float)) else repr(item)
            if marker in seen:
                continue
            seen.add(marker)
            out.append(item)
        return out
    return new


def as_list(value):
    if isinstance(value, list):
        return value
    if isinstance(value, dict):
        nums = sorted(k for k in value if isinstance(k, int))
        if nums:
            return [value[k] for k in nums]
    return []


def lua_str(value: str) -> str:
    return "'" + str(value).replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n").replace("\r", "") + "'"


def lua_num(value) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        if value.is_integer():
            return str(int(value))
        text = f"{value:.6f}".rstrip("0").rstrip(".")
        return text
    raise TypeError(value)


def coerce_num(value):
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, (int, float)):
        return value
    if isinstance(value, str) and re.fullmatch(r"-?\d+(\.\d+)?", value):
        return float(value) if "." in value else int(value)
    return None


MELEE_TOKENS = [
    "KNIFE", "DAGGER", "SWITCHBLADE", "MACHETTE", "MACHETE", "KATANA", "SWORD", "SYTHE", "SCYTHE",
    "KARAMBIT", "KUNAI", "KNUCKLE", "BATTLEAXE", "HATCHET", "PICKAXE", "ICEAXE", "CHAINSAW", "CROWBAR",
    "HAMMER", "NIGHTSTICK", "BATON", "WRENCH", "POOLCUE", "GOLFCLUB", "BOTTLE", "CANDYCANE", "FLASHLIGHT",
    "UNARMED", "CLEAVER", "CLEAT", "HOCKEY", "PENCIL", "SABER", "WAND", "BREAD", "UNICORN", "PALMTREE",
    "RAINBOWSMASH", "FORTNITE", "DILDO", "SEXT", "PSKELE", "SLURP", "KAALF", "AXE", "BAT",
    "STICK", "ICEBREAKER", "ICEICLE", "ICICLE",
]
# BAT is intentionally last-ish and checked with boundaries below.

MELEE_EXACT_SUFFIX = ("BAT", "AXE")

SMG_TOKENS = [
    "SMG", "MICROSMG", "MINISMG", "ASSAULTSMG", "MACHINEPISTOL", "COMBATPDW", "PDW", "MP5", "MP7",
    "MP9", "MPX", "MAC10", "MAC11", "UZI", "VECTOR", "UMP", "PPSH", "SCORP", "TEC9", "TECPISTOL",
    "THOMPSON", "TOMMY", "GUSENBERG", "P90",
]

HEAVY_TOKENS = [
    "DEAGLE", "DESERTEAGLE", "DESERT_EAGLE", "REVOLVER", "PISTOL50", "HEAVYPISTOL", "FN57", "FNX",
    "MARKSMANPISTOL", "NAVYREVOLVER", "DOUBLEACTION", "GADGETPISTOL", "50AE",
]

SHOTGUN_TOKENS = ["SHOTGUN", "BOOMSTICK", "BEANBAG"]

RIFLE_TOKENS = ["MARKSMANRIFLE", "MUSKET", "PRECISIONRIFLE", "HUNTINGRIFLE", "BOLTACTION"]

SNIPER_TOKENS = ["SNIPER", "AWP", "BARRETT", "HEAVYSNIPER"]

VARIANT_TOKENS = [
    "MK2", "HALLOWEEN", "WIREFRAME", "CHRISTMAS", "CAMO", "HELLOKITTY", "KITTY", "CHUCKY", "FREDDY",
    "GHOSTFACE", "LEATHERFACE", "PENNYWISE", "MIKEMYERS", "TIFFANY", "VALENTINE", "KAWAI", "VORTEX",
    "GRAVEYARD", "RETROPIXEL", "STARKILLER", "DARKMATTER", "PIMHALLOWEEN", "JASON",
]

WORLD = {
    "WEAPON_ANIMAL", "WEAPON_ANIMAL_RETRIEVER", "WEAPON_BARBED_WIRE", "WEAPON_BIRD_CRAP", "WEAPON_BLEEDING",
    "WEAPON_BOAR", "WEAPON_CAT", "WEAPON_COUGAR", "WEAPON_COW", "WEAPON_COYOTE", "WEAPON_DEER",
    "WEAPON_DROWNING", "WEAPON_DROWNING_IN_VEHICLE", "WEAPON_ELECTRIC_FENCE", "WEAPON_EXHAUSTION",
    "WEAPON_EXPLOSION", "WEAPON_FALL", "WEAPON_FIRE", "WEAPON_HAMMERHEAD_SHARK", "WEAPON_HELI_CRASH",
    "WEAPON_HEN", "WEAPON_HIT_BY_WATER_CANNON", "WEAPON_KILLER_WHALE", "WEAPON_PASSENGER_ROCKET",
    "WEAPON_PIG", "WEAPON_RABBIT", "WEAPON_RAMMED_BY_CAR", "WEAPON_RUN_OVER_BY_CAR", "WEAPON_SMALL_DOG",
    "WEAPON_STINGER", "WEAPON_TIGER_SHARK", "WEAPON_VEHICLE_ROCKET", "WEAPON_AIRSTRIKE_ROCKET",
    "WEAPON_GRENADELAUNCHER_SMOKE", "WEAPON_REMOTESNIPER", "WEAPON_UNHOLSTER_UNARMED", "WEAPON_BRIEFCASE",
    "WEAPON_BRIEFCASE_02",
}

BENCH = {
    "pistols": "pistol",
    "heavy_pistols": "pistol",
    "smgs": "rifle",
    "shotguns": "rifle",
    "rifles": "rifle",
    "assault_rifles": "rifle",
    "snipers": "rifle",
    "melee": "melee",
    "custom": "assembly",
    "variants": "general",
    "attachments": "assembly",
    "ammunition": "assembly",
}


def contains_token(name: str, token: str) -> bool:
    if token == "BAT":
        return bool(re.search(r"(^|_)BAT($|_)", name)) or name.endswith("BAT")
    if token == "AK":
        return bool(re.search(r"(^|_)AK($|_)", name)) or name.endswith("AK") or "AK47" in name
    if token == "AXE":
        return "AXE" in name
    return token in name


def family_of(item: str, fields: dict) -> tuple[str, bool, bool]:
    """Return family, craftable, purchasable."""
    name = item.upper()
    ammo = fields.get("ammo") or ""
    if item in WORLD or name in WORLD:
        return "custom", False, False
    melee = False
    for token in MELEE_TOKENS:
        if contains_token(name, token):
            melee = True
            break
    if fields.get("throwable") and not ammo:
        if melee:
            return "melee", True, True
        return "custom", True, True
    if not ammo and (melee or fields.get("anim")):
        return "melee", True, True
    if not ammo and melee:
        return "melee", True, True
    if any(contains_token(name, token) or token in name for token in SNIPER_TOKENS) or ammo in ("ammo-sniper", "ammo-heavysniper", "pd-sniper"):
        if "MARKSMANRIFLE" in name:
            return "rifles", True, True
        return "snipers", True, True
    if any(token in name for token in SHOTGUN_TOKENS) or name.endswith("SG") or ammo in ("ammo-shotgun", "pd-shotgun", "pd-beanbag"):
        return "shotguns", True, True
    if any(token in name for token in SMG_TOKENS):
        if "REVOLVER" in name:
            return "heavy_pistols", True, True
        return "smgs", True, True
    if any(token in name for token in HEAVY_TOKENS):
        return "heavy_pistols", True, True
    if any(token in name for token in RIFLE_TOKENS):
        return "rifles", True, True
    if ammo in ("ammo-rifle", "ammo-rifle2", "pd-rifle") or "RIFLE" in name or contains_token(name, "AK") or "ARP" in name or "CARBINE" in name or "MG" == name.split("_")[-1] or name.endswith("MG"):
        if "MARKSMAN" in name or "MUSKET" in name or "PRECISION" in name or "HUNTING" in name:
            return "rifles", True, True
        return "assault_rifles", True, True
    if ammo in ("ammo-44", "ammo-45", "ammo-9", "ammo-22", "ammo-38", "ammo-50", "pd-pistol") or "PISTOL" in name or "GLOCK" in name or "SWITCH" in name:
        return "pistols", True, True
    if melee:
        return "melee", True, True
    if not ammo:
        return "melee" if fields.get("anim") else "custom", True, True
    return "custom", True, True


def is_variant(item: str, lowered_groups: dict) -> bool:
    name = item.upper()
    if any(token in name for token in VARIANT_TOKENS):
        return True
    group = lowered_groups.get(item.lower(), [])
    if len(group) > 1 and item != group[0]:
        return True
    return False


def internal_id(item: str, kind: str, used: dict) -> str:
    base = "ws_" + re.sub(r"[^a-z0-9]+", "_", item.lower()).strip("_")
    if kind == "ammo":
        base = "ws_ammo_" + re.sub(r"[^a-z0-9]+", "_", item.lower()).strip("_")
    elif kind == "attachment":
        base = "ws_att_" + re.sub(r"[^a-z0-9]+", "_", item.lower()).strip("_")
    candidate = base
    n = 2
    while candidate in used:
        candidate = f"{base}_{n}"
        n += 1
    used[candidate] = item
    return candidate


def description(label: str, category: str, ammo: str | None) -> str:
    pretty = category.replace("_", " ")
    if ammo:
        return f"{label}. {pretty.capitalize()} manufactured by DJ Weapon Store. Chambered for {ammo}."
    return f"{label}. {pretty.capitalize()} manufactured by DJ Weapon Store."


def entry_line(fields: list[str]) -> str:
    return "{" + ",".join(fields) + "}"


def weapon_entries(weapons: dict) -> list[dict]:
    groups = {}
    for key in weapons:
        groups.setdefault(key.lower(), []).append(key)
    for key in groups:
        groups[key].sort()
    used = {}
    rows = []
    for item, raw in weapons.items():
        if not isinstance(raw, dict):
            continue
        ammo = raw.get("ammoname") if isinstance(raw.get("ammoname"), str) else None
        weight = coerce_num(raw.get("weight"))
        degrade = coerce_num(raw.get("durability"))
        label = raw.get("label") if isinstance(raw.get("label"), str) else item
        model = raw.get("model") if isinstance(raw.get("model"), str) else None
        throwable = bool(raw.get("throwable"))
        anim = as_list(raw.get("anim")) if raw.get("anim") is not None else []
        fam, craftable, purchasable = family_of(item, {"ammo": ammo, "throwable": throwable, "anim": anim})
        variant = is_variant(item, groups)
        category = "variants" if variant and craftable else fam
        required = None
        if (ammo and str(ammo).startswith("pd-")) or (item.startswith("WEAPON_PD") and not item.startswith("WEAPON_PINK")):
            required = "police"
        rows.append({
            "id": internal_id(item, "weapon", used),
            "item": item,
            "label": label,
            "category": category,
            "family": fam,
            "kind": "weapon",
            "ammo": ammo,
            "weight": weight if weight is not None else 0,
            "degrade": degrade,
            "model": model,
            "throwable": throwable,
            "anim": [a for a in anim if isinstance(a, (str, int, float))],
            "bench": BENCH[category if category != "variants" else fam],
            "craftable": craftable,
            "purchasable": purchasable,
            "requiredJob": required,
            "description": description(label, category, ammo),
        })
    return rows


def component_rows(components: dict, used: dict) -> list[dict]:
    rows = []
    for item, raw in components.items():
        if not isinstance(raw, dict):
            continue
        client = raw.get("client") if isinstance(raw.get("client"), dict) else {}
        hashes = []
        for value in as_list(client.get("component")):
            if isinstance(value, str):
                hashes.append(value)
        weight = coerce_num(raw.get("weight"))
        usetime = coerce_num(client.get("usetime"))
        rows.append({
            "id": internal_id(item, "attachment", used),
            "item": item,
            "label": raw.get("label") if isinstance(raw.get("label"), str) else item,
            "category": "attachments",
            "family": "attachments",
            "kind": "attachment",
            "weight": weight if weight is not None else 0,
            "attachType": raw.get("type") if isinstance(raw.get("type"), str) else None,
            "components": hashes,
            "usetime": usetime,
            "image": client.get("image") if isinstance(client.get("image"), str) else None,
            "bench": "assembly",
            "craftable": True,
            "purchasable": True,
            "description": f"{raw.get('label', item)}. Weapon attachment stocked by DJ Weapon Store.",
        })
    return rows


def ammo_rows(ammo: dict, used: dict) -> list[dict]:
    rows = []
    for item, raw in ammo.items():
        if not isinstance(raw, dict):
            continue
        weight = coerce_num(raw.get("weight"))
        locked = bool(raw.get("locked"))
        rows.append({
            "id": internal_id(item, "ammo", used),
            "item": item,
            "label": raw.get("label") if isinstance(raw.get("label"), str) else item,
            "category": "ammunition",
            "family": "ammunition",
            "kind": "ammo",
            "weight": weight if weight is not None else 0,
            "locked": locked,
            "bench": "assembly",
            "craftable": not locked,
            "purchasable": not locked,
            "requiredJob": "police" if locked or str(item).startswith("pd-") else None,
            "description": f"{raw.get('label', item)}. Ammunition stocked by DJ Weapon Store.",
        })
    return rows


def emit_weapon_lua(rows: list[dict]) -> str:
    lines = [
        "-- Generated from the ox_inventory weapon source. Do not rename item fields.",
        "-- Internal id is `id`. Inventory adapters map that id to `item` (ox name) unless overridden.",
        "DJWS = DJWS or {}",
        "DJWS.WeaponEntries = {",
    ]
    for row in rows:
        parts = [
            f"id={lua_str(row['id'])}",
            f"item={lua_str(row['item'])}",
            f"label={lua_str(row['label'])}",
            f"category={lua_str(row['category'])}",
            f"family={lua_str(row['family'])}",
            "kind='weapon'",
            f"weight={lua_num(row['weight'])}",
            f"bench={lua_str(row['bench'])}",
            f"craftable={'true' if row['craftable'] else 'false'}",
            f"purchasable={'true' if row['purchasable'] else 'false'}",
            f"description={lua_str(row['description'])}",
        ]
        if row["ammo"]:
            parts.append(f"ammo={lua_str(row['ammo'])}")
        if row["degrade"] is not None:
            parts.append(f"degrade={lua_num(row['degrade'])}")
        if row["model"]:
            parts.append(f"model={lua_str(row['model'])}")
        if row["throwable"]:
            parts.append("throwable=true")
        if row["requiredJob"]:
            parts.append(f"requiredJob={lua_str(row['requiredJob'])}")
        if row["anim"]:
            anim = ",".join(lua_str(v) if isinstance(v, str) else lua_num(v) for v in row["anim"])
            parts.append(f"anim={{{anim}}}")
        lines.append("{" + ",".join(parts) + "},")
    lines.append("}")
    lines.append(f"DJWS.WeaponSourceCount = {len(rows)}")
    return "\n".join(lines) + "\n"


def emit_component_lua(rows: list[dict]) -> str:
    lines = [
        "-- Attachment items and the component hashes they install.",
        "-- Duplicate ox keys were merged: scalar fields follow the later definition, hashes are a union.",
        "DJWS = DJWS or {}",
        "DJWS.ComponentEntries = {",
    ]
    for row in rows:
        hashes = ",".join(lua_str(h) for h in row["components"])
        parts = [
            f"id={lua_str(row['id'])}",
            f"item={lua_str(row['item'])}",
            f"label={lua_str(row['label'])}",
            "category='attachments'",
            "family='attachments'",
            "kind='attachment'",
            f"weight={lua_num(row['weight'])}",
            "bench='assembly'",
            "craftable=true",
            "purchasable=true",
            f"description={lua_str(row['description'])}",
            f"components={{{hashes}}}",
        ]
        if row["attachType"]:
            parts.append(f"attachType={lua_str(row['attachType'])}")
        if row["usetime"] is not None:
            parts.append(f"usetime={lua_num(row['usetime'])}")
        if row["image"]:
            parts.append(f"image={lua_str(row['image'])}")
        lines.append("{" + ",".join(parts) + "},")
    lines.append("}")
    lines.append(f"DJWS.ComponentSourceCount = {len(rows)}")
    return "\n".join(lines) + "\n"


def emit_ammo_lua(rows: list[dict]) -> str:
    lines = [
        "-- Ammo items preserved from the ox_inventory source.",
        "DJWS = DJWS or {}",
        "DJWS.AmmoEntries = {",
    ]
    for row in rows:
        parts = [
            f"id={lua_str(row['id'])}",
            f"item={lua_str(row['item'])}",
            f"label={lua_str(row['label'])}",
            "category='ammunition'",
            "family='ammunition'",
            "kind='ammo'",
            f"weight={lua_num(row['weight'])}",
            "bench='assembly'",
            f"craftable={'true' if row['craftable'] else 'false'}",
            f"purchasable={'true' if row['purchasable'] else 'false'}",
            f"locked={'true' if row['locked'] else 'false'}",
            f"description={lua_str(row['description'])}",
        ]
        if row["requiredJob"]:
            parts.append(f"requiredJob={lua_str(row['requiredJob'])}")
        lines.append("{" + ",".join(parts) + "},")
    lines.append("}")
    lines.append(f"DJWS.AmmoSourceCount = {len(rows)}")
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    text = open(args.source, encoding="utf-8").read().replace("`", "'")
    data = Parser(text).parse()
    weapons = data["Weapons"]
    components = data["Components"]
    ammo = data["Ammo"]
    if not isinstance(weapons, dict) or not isinstance(components, dict) or not isinstance(ammo, dict):
        raise SystemExit("unexpected top-level shape")
    used = {}
    wrows = weapon_entries(weapons)
    # weapon_entries fills its own used map; rebuild ids in one shared map for cross-kind safety
    used = {}
    # recompute ids in a shared set by calling internal on copies
    wrows = weapon_entries(weapons)
    crows = component_rows(components, {})
    arows = ammo_rows(ammo, {})
    # detect id collisions across files
    ids = [r["id"] for r in wrows + crows + arows]
    dupes = [i for i, c in Counter(ids).items() if c > 1]
    if dupes:
        raise SystemExit(f"catalog id collision: {dupes[:10]}")
    if len(wrows) != len(weapons):
        raise SystemExit(f"weapon count mismatch {len(wrows)} != {len(weapons)}")
    out = args.out.rstrip("/")
    open(f"{out}/weapons.lua", "w", encoding="utf-8").write(emit_weapon_lua(wrows))
    open(f"{out}/components.lua", "w", encoding="utf-8").write(emit_component_lua(crows))
    open(f"{out}/ammo.lua", "w", encoding="utf-8").write(emit_ammo_lua(arows))
    cats = Counter(r["category"] for r in wrows)
    fams = Counter(r["family"] for r in wrows)
    print("weapons", len(wrows), "components", len(crows), "ammo", len(arows))
    print("categories", dict(cats))
    print("families", dict(fams))
    print("craftable", sum(1 for r in wrows if r["craftable"]), "hidden", sum(1 for r in wrows if not r["craftable"]))
    print("variants", cats.get("variants", 0))
    print("case ids", [r["id"] for r in wrows if r["item"].lower() != r["item"] and any(x["item"] == r["item"].lower() for x in wrows)][:12])


if __name__ == "__main__":
    main()
