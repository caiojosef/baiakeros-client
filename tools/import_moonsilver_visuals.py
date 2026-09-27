"""Import the 15.30 Moonsilver equipment graphics from Tibia's asset manifest.

The official package used here is 15.33.6ef2e8. Only the equipment, sigil,
two homing missiles, their sprite sheets and proficiency trees are merged.
"""

from __future__ import annotations

import hashlib
import json
import lzma
import struct
import sys
from pathlib import Path
from urllib.request import Request, urlopen


OFFICIAL = Path(r"D:\otserv\Update 15.30\Echo Raid\official-assets")
CLIENT = Path(__file__).resolve().parents[1] / "data" / "things" / "1525"
SERVER_APPEARANCES = Path(r"\\wsl.localhost\Ubuntu-24.04\home\baiakeros\baiakeros\data\items\appearances.dat")
BASE_URL = "https://static.tibia.com/launcher/assets-current/"
ITEM_IDS = set(range(53197, 53234)) | set(range(54510, 54515)) | {54480}
MISSILE_IDS = {75, 76}

sys.path[:0] = [str(OFFICIAL / "pydeps"), str(OFFICIAL)]
import appearances_pb2 as appearances  # noqa: E402


def read_appearances(path: Path) -> appearances.Appearances:
    value = appearances.Appearances()
    value.ParseFromString(path.read_bytes())
    return value


def sprite_ids(item: object) -> set[int]:
    return {
        sprite_id
        for frame in item.frame_group
        for sprite_id in frame.sprite_info.sprite_id
    }


def unpack_sprite_sheet(payload: bytes) -> bytes:
    """Decode CIP's 32-byte wrapper exactly as SpriteAppearances does."""
    properties = payload[32]
    dictionary = struct.unpack_from("<I", payload, 33)[0]
    filters = [{
        "id": lzma.FILTER_LZMA1,
        "dict_size": dictionary,
        "lc": properties % 9,
        "lp": (properties // 9) % 5,
        "pb": (properties // 9) // 5,
    }]
    return lzma.decompress(payload[45:], format=lzma.FORMAT_RAW, filters=filters)


def main() -> None:
    official_path = next(OFFICIAL.glob("appearances-e8*.dat"))
    official = read_appearances(official_path)
    selected = {item.id: item for item in official.object if item.id in ITEM_IDS}
    if set(selected) != ITEM_IDS:
        raise ValueError(f"Missing official appearances: {sorted(ITEM_IDS - set(selected))}")
    missiles = {item.id: item for item in official.missile if item.id in MISSILE_IDS}
    if set(missiles) != MISSILE_IDS:
        raise ValueError("Missing official homing missile appearances")

    wanted_sprites = set().union(*(sprite_ids(item) for item in selected.values()))
    official_catalog = json.loads((OFFICIAL / "catalog-content.json").read_text(encoding="utf-8-sig"))
    sheets = [
        entry for entry in official_catalog
        if entry.get("type") == "sprite"
        and any(entry["firstspriteid"] <= sprite <= entry["lastspriteid"] for sprite in wanted_sprites)
    ]
    covered = {
        sprite for sprite in wanted_sprites
        if any(entry["firstspriteid"] <= sprite <= entry["lastspriteid"] for entry in sheets)
    }
    if covered != wanted_sprites or len(sheets) != 5:
        raise ValueError("The five official sprite sheets do not cover every equipment sprite")

    catalog_path = CLIENT / "catalog-content.json"
    catalog = json.loads(catalog_path.read_text(encoding="utf-8-sig"))
    # Missile sheets share numeric ranges with older client graphics. Allocate
    # new ranges instead of replacing sheets used by the existing game assets.
    missile_sprites = set().union(*(sprite_ids(item) for item in missiles.values()))
    missile_sheets = [entry for entry in official_catalog if entry.get("type") == "sprite"
                      and any(entry["firstspriteid"] <= s <= entry["lastspriteid"] for s in missile_sprites)]
    next_sprite = max(entry["lastspriteid"] for entry in [*catalog, *sheets] if entry.get("type") == "sprite") + 1
    remap = {}
    for original in missile_sheets:
        existing = next((entry for entry in catalog if entry.get("file") == original["file"]), None)
        sheet = dict(original)
        sheet["firstspriteid"] = existing["firstspriteid"] if existing else next_sprite
        sheet["lastspriteid"] = sheet["firstspriteid"] + original["lastspriteid"] - original["firstspriteid"]
        next_sprite = max(next_sprite, sheet["lastspriteid"] + 1)
        for sprite in missile_sprites:
            if original["firstspriteid"] <= sprite <= original["lastspriteid"]:
                remap[sprite] = sprite - original["firstspriteid"] + sheet["firstspriteid"]
        sheets.append(sheet)
    if set(remap) != missile_sprites:
        raise ValueError("Missing homing missile sprite ranges")
    remapped_missiles = {}
    for missile_id, original in missiles.items():
        item = appearances.Appearance()
        item.CopyFrom(original)
        for frame in item.frame_group:
            frame.sprite_info.sprite_id[:] = [remap[s] for s in frame.sprite_info.sprite_id]
        remapped_missiles[missile_id] = item

    manifest = json.loads((OFFICIAL / "assets-current.json").read_text(encoding="utf-8-sig"))
    manifest_files = {Path(entry["localfile"]).name: entry for entry in manifest["files"]}
    for sheet in sheets:
        name = sheet["file"]
        entry = manifest_files[name]
        target = CLIENT / name
        if not target.exists():
            request = Request(BASE_URL + entry["url"], headers={"User-Agent": "Mozilla/5.0"})
            with urlopen(request, timeout=30) as response:
                payload = response.read()
            if len(payload) != entry["packedsize"] or hashlib.sha256(payload).hexdigest() != entry["packedhash"]:
                raise ValueError(f"Official sprite checksum failed: {name}")
            target.write_bytes(payload)
        elif hashlib.sha256(target.read_bytes()).hexdigest() != entry["packedhash"]:
            raise ValueError(f"Existing sprite sheet has the wrong checksum: {name}")
        decoded = unpack_sprite_sheet(target.read_bytes())
        expected = name.removeprefix("sprites-").split(".bmp")[0]
        if hashlib.sha256(decoded).hexdigest() != expected or not decoded.startswith(b"BM"):
            raise ValueError(f"Unpacked sprite sheet checksum failed: {name}")

    appearance_path = next(CLIENT.glob("appearances-*.dat"))
    for path in (appearance_path, SERVER_APPEARANCES):
        data = read_appearances(path)
        remaining = [item for item in data.object if item.id not in ITEM_IDS]
        merged = sorted([*remaining, *selected.values()], key=lambda item: item.id)
        del data.object[:]
        for item in merged:
            data.object.add().CopyFrom(item)
        remaining_missiles = [item for item in data.missile if item.id not in MISSILE_IDS]
        del data.missile[:]
        for item in sorted([*remaining_missiles, *remapped_missiles.values()], key=lambda item: item.id):
            data.missile.add().CopyFrom(item)
        payload = data.SerializeToString()
        path.write_bytes(payload)
        if path == appearance_path:
            path.with_suffix(".dat.lzma").write_bytes(lzma.compress(payload, format=lzma.FORMAT_ALONE))

    for sheet in sheets:
        start, stop = sheet["firstspriteid"], sheet["lastspriteid"]
        for old in catalog:
            if old.get("type") == "sprite" and not (old["lastspriteid"] < start or old["firstspriteid"] > stop) and old["file"] != sheet["file"]:
                raise ValueError(f"Sprite range conflict: {sheet['file']} and {old['file']}")
    existing_files = {entry.get("file") for entry in catalog}
    catalog.extend(sheet for sheet in sheets if sheet["file"] not in existing_files)
    # Keep the local proficiency trees and their compressed sidecars in sync.
    proficiency_name = next(entry["file"] for entry in catalog if entry.get("type") == "proficiencies")
    proficiency_path = CLIENT / proficiency_name
    server_profiles = json.loads((SERVER_APPEARANCES.parent / "proficiencies.json").read_text(encoding="utf-8"))
    selected_profiles = {p["ProficiencyId"]: p for p in server_profiles if 475 <= p["ProficiencyId"] <= 496}
    if set(selected_profiles) != set(range(475, 497)):
        raise ValueError("Missing Moonsilver proficiency trees on the server")
    profiles = {p["ProficiencyId"]: p for p in json.loads(proficiency_path.read_text(encoding="utf-8"))}
    profiles.update(selected_profiles)
    payload = (json.dumps([profiles[k] for k in sorted(profiles)], indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    proficiency_path.write_bytes(payload)
    proficiency_path.with_suffix(".json.lzma").write_bytes(lzma.compress(payload, format=lzma.FORMAT_ALONE))
    payload = (json.dumps(catalog, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    catalog_path.write_bytes(payload)
    catalog_path.with_suffix(".json.lzma").write_bytes(lzma.compress(payload, format=lzma.FORMAT_ALONE))

    check = read_appearances(appearance_path)
    imported = {item.id: sprite_ids(item) for item in check.object if item.id in ITEM_IDS}
    if imported != {item_id: sprite_ids(item) for item_id, item in selected.items()}:
        raise ValueError("Merged appearances failed verification")
    print(f"Imported {len(imported)} item appearances, {len(remapped_missiles)} homing missiles, {len(sheets)} sheets and 22 profiles")


if __name__ == "__main__":
    main()
