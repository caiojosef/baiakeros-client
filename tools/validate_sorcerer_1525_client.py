#!/usr/bin/env python3
"""Static client-side checks for the Sorcerer/MS 15.25 update."""

from __future__ import annotations

import hashlib
import json
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []


def png_size(relative: str) -> tuple[int, int] | None:
    path = ROOT / relative
    try:
        data = path.read_bytes()
        if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
            raise ValueError("invalid PNG header")
        return struct.unpack(">II", data[16:24])
    except (OSError, ValueError, struct.error) as exc:
        failures.append(f"{relative}: {exc}")
        return None


def sha256(relative: str) -> str:
    return hashlib.sha256((ROOT / relative).read_bytes()).hexdigest()


def check_stance_catalog() -> None:
    content = (ROOT / "modules/gamelib/spells.lua").read_text(encoding="utf-8")
    expected = {
        "Master of Flames": (304, "uteta flam", 193),
        "Master of Thunder": (305, "uteta vis", 194),
        "Master of Decay": (306, "uteta mort", 195),
    }
    rows: list[str] = []
    for name, (spell_id, words, client_id) in expected.items():
        row = next((line for line in content.splitlines() if f"['{name}'] = {{" in line), "")
        rows.append(row)
        for needle in (
            f"id = {spell_id}", f"words = '{words}'", "level = 20", "mana = 400",
            f"clientId = {client_id}", "group = {[3] = 2000, [12] = 30000}",
            "exhaustion = 30000", "premium = true", "vocations = {5}",
        ):
            if needle not in row:
                failures.append(f"{name}: missing or incorrect {needle}")
    ids = [int(m.group(1)) for row in rows if (m := re.search(r"clientId = (\d+)", row))]
    if ids != [193, 194, 195] or len(set(ids)) != 3:
        failures.append("stance client IDs must be unique and ordered as 193, 194, 195")

    death_echo = next((line for line in content.splitlines() if "['Death Echo'] = {" in line), "")
    for needle in (
        "id = 307", "words = 'exevo mort ora'", "level = 120", "mana = 150",
        "clientId = 196", "group = {[1] = 2000}", "needTarget = true", "positionTarget = true",
        "range = 7", "exhaustion = 6000", "premium = true", "vocations = {1, 5}",
    ):
        if needle not in death_echo:
            failures.append(f"Death Echo: missing or incorrect {needle}")


    curse_stances = {
        "Aura of Exposed Weakness": (243, "exori moe tempo", 109),
        "Aura of Sapped Strength": (244, "exori kor tempo", 110),
    }
    for name, (spell_id, words, client_id) in curse_stances.items():
        row = next((line for line in content.splitlines() if f"['{name}'] = {{" in line), "")
        for needle in (
            f"id = {spell_id}", f"words = '{words}'", "level = 175", "mana = 1500",
            f"clientId = {client_id}", "group = {[3] = 2000, [6] = 30000}",
            "exhaustion = 30000", "premium = true", "vocations = {5}",
        ):
            if needle not in row:
                failures.append(f"{name}: missing or incorrect {needle}")
    for obsolete in ("['Expose Weakness']", "['Sap Strength']"):
        if obsolete in content:
            failures.append(f"legacy separate spell remains in catalog: {obsolete}")

    actionbar = (ROOT / "modules/game_actionbar/game_actionbar.lua").read_text(encoding="utf-8")
    action_logic = (ROOT / "modules/game_actionbar/logics/ActionButtonLogic.lua").read_text(encoding="utf-8")
    stance_opcode = (ROOT / "modules/game_ek_1525/game_ek_1525.lua").read_text(encoding="utf-8")
    for spell_id in (243, 244, 304, 305, 306):
        if f"[{spell_id}] = true" not in actionbar:
            failures.append(f"active stance set missing spell ID {spell_id}")
    for needle in ("setActiveStanceSpellIds", "isActiveStanceSpellId"):
        if needle not in actionbar:
            failures.append(f"multi-stance Action Bar missing {needle}")
    if "isActiveStanceSpellId(button.cache.spellData.id)" not in action_logic:
        failures.append("Action Button does not render multiple simultaneous stances")
    if "type(data.spellIds) == 'table'" not in stance_opcode:
        failures.append("stance opcode does not accept elemental + curse state")


def check_wheel_contract() -> None:
    icons = (ROOT / "modules/game_wheel/classes/icons.lua").read_text(encoding="utf-8")
    start = icons.index("\t[SORCERER] = {")
    end = icons.index("\n\t[DRUID] = {", start)
    block = icons[start:end]
    expected_x = [
        1050,150,1110,1020,1140,810,1110,780,180,1140,1080,150,
        750,1020,1110,720,180,1140,1170,150,810,1200,1020,780,
        180,1080,1170,150,750,1200,720,1170,1020,1200,180,690,
    ]
    actual: list[int] = []
    for slot in range(1, 37):
        match = re.search(
            rf"\[{slot}\] = \{{\s*iconRect = \"(\d+) 0 30 30\"",
            block,
        )
        if not match:
            failures.append(f"missing Sorcerer Wheel icon slot {slot}")
            return
        actual.append(int(match.group(1)))
    if actual != expected_x:
        failures.append(f"Sorcerer Wheel icon positions differ from official contract: {actual}")

    bonus = (ROOT / "modules/game_wheel/classes/bonus.lua").read_text(encoding="utf-8")
    required = (
        "Augmented Special Spells", "Aug. Special Spells",
        "Augmented Death Echo", "Aug. Death Echo",
        "+5% Base Damage for Hell's", "+50% Base Damage",
        "-2s Cooldown", "+12% Base Damage",
        "Affected area enlarged", "+10% Base Damage",
        "+15% Critical Extra Damage", "Focus spells: -2s primary",
    )
    for needle in required:
        if needle not in bonus:
            failures.append(f"Wheel bonus text missing: {needle}")
    for obsolete in ("Augmented Magic Shield", "Aug. Magic Shield", "Augmented Sap Strength", "Aug. Sap Strength"):
        if obsolete in bonus:
            failures.append(f"obsolete Sorcerer Wheel text remains: {obsolete}")

    data = json.loads((ROOT / "data/json/SkillwheelStringsJsonLibrary.json").read_text(encoding="utf-8"))
    medium = data["MediumPerkInfos"]
    expected = {
        "23": ("Focus Mastery", "reduced by 2 seconds"),
        "24": ("Augmented Great Fire Wave|Aug. Great Fire Wave", "+15% Critical Extra Damage", "+5% Base Damage"),
        "25": ("Augmented Energy Wave|Aug. Energy Wave", "Affected area enlarged", "+10% Base Damage"),
        "26": ("Augmented Special Spells|Aug. Special Spells", "-4s Cooldown", "+50% Base Damage"),
        "27": ("Augmented Focus Spells|Aug. Focus Spells", "+5% Base Damage", "-4s Cooldown"),
        "36": ("Augmented Death Echo|Aug. Death Echo", "-2s Cooldown", "+12% Base Damage"),
    }
    for perk_id, needles in expected.items():
        serialized = json.dumps(medium[perk_id], ensure_ascii=False)
        for needle in needles:
            if needle not in serialized:
                failures.append(f"MediumPerkInfos[{perk_id}] missing {needle}")




    large = data["LargePerkInfos"]
    lord = json.dumps(large["8"], ensure_ascii=False)
    for needle in ("Lord of Destruction", "+2%/+3%/+4% Base Power", "+2%/+3%/+4% critical hit chance", "+15%/+22.5%/+30% critical extra damage"):
        if needle not in lord:
            failures.append(f"LargePerkInfos[8] missing {needle}")
    serialized_strings = json.dumps(data, ensure_ascii=False)
    for obsolete in ("Drain Body", "Expose Weakness grants", "Sap Strength grants"):
        if obsolete in serialized_strings:
            failures.append(f"obsolete Sorcerer revelation text remains: {obsolete}")

def check_position_targeting() -> None:
    protocol = (ROOT / "src/client/protocolgamesend.cpp").read_text(encoding="utf-8")
    game = (ROOT / "src/client/game.cpp").read_text(encoding="utf-8")
    bindings = (ROOT / "src/client/luafunctions.cpp").read_text(encoding="utf-8")
    interface = (ROOT / "modules/game_interface/gameinterface.lua").read_text(encoding="utf-8")
    actionbar = (ROOT / "modules/game_actionbar/logics/ActionButtonLogic.lua").read_text(encoding="utf-8")
    api_json = (ROOT / "modules/game_actionbar/logics/ApiJson.lua").read_text(encoding="utf-8")
    expected = {
        "protocol": (protocol, ("sendTalkPosition", "POSITION_SPELL_MARKER = 0xA5", "addPosition(msg, position)")),
        "game": (game, ("Game::talkPosition", "sendTalkPosition(message, position, aimMode)")),
        "bindings": (bindings, ('"talkPosition"',)),
        "interface": (interface, ("castPositionSpell", "startPositionSpell", "g_game.talkPosition", "positionSpell")),
        "actionbar": (actionbar, ("Aim: Target or Self", "Aim: Cursor Position", "Aim: Crosshair", "positionSpellAimMode")),
        "persistence": (api_json, ("setPositionSpellAimMode", '["positionSpellAimMode"]')),
    }
    for area, (content, needles) in expected.items():
        for needle in needles:
            if needle not in content:
                failures.append(f"Death Echo targeting {area} missing {needle}")

def main() -> int:
    check_stance_catalog()
    check_wheel_contract()
    check_position_targeting()
    expected_images = {
        "data/images/game/spells/spell-icons-32x32.png": ((6304, 32), "a773ffe08b04414b3cc3c5ddd7f2ad366e848bce44b56a1ae2f5dfd560c6df28"),
        "data/images/game/spells/spell-icons-20x20.png": ((3940, 20), "19c0071bc75e1695d2ae6deb9fc1aab5cb7a84c20bb9c10778297eb75e6983ef"),
        "data/images/game/wheel/icons-skillwheel-mediumperks.png": ((1470, 30), "64a798e63ec8ee3fe2d23d46ebe57d9bb55eb441afd506e03801f810e925af5b"),
        "data/images/game/wheel/icons-skillwheel-largeperks.png": ((544, 34), "5a36d866b59837fcee9395b88043f83c7fd0b4b8352cb27547aab8d2d1740872"),
    }
    for path, (size, digest) in expected_images.items():
        if png_size(path) != size:
            failures.append(f"{path}: expected dimensions {size}")
        if digest and sha256(path) != digest:
            failures.append(f"{path}: does not match the official 15.25 atlas")

    if failures:
        print("Sorcerer 15.25 client validation FAILED:")
        for failure in failures:
            print(f" - {failure}")
        return 1
    print("Sorcerer 15.25 client validation passed (catalog, targeting modes, atlases and 36-node Wheel contract).")
    return 0


if __name__ == "__main__":
    sys.exit(main())

