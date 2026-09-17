#!/usr/bin/env python3
"""Static client-side checks for the Knight/EK 15.25 update."""

from __future__ import annotations

import json
import struct
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []


def require(relative: str, *needles: str) -> None:
    path = ROOT / relative
    if not path.is_file():
        failures.append(f"{relative}: file is missing")
        return
    content = path.read_text(encoding="utf-8")
    for needle in needles:
        if needle not in content:
            failures.append(f"{relative}: missing {needle!r}")


def require_asset(relative: str) -> None:
    path = ROOT / relative
    if not path.is_file() or path.stat().st_size == 0:
        failures.append(f"{relative}: asset is missing or empty")


def check_wheel_spell_pairings() -> None:
    icons_path = ROOT / "modules/game_wheel/classes/icons.lua"
    wheelclass_path = ROOT / "modules/game_wheel/classes/wheelclass.lua"
    bonus_path = ROOT / "modules/game_wheel/classes/bonus.lua"
    try:
        icons = icons_path.read_text(encoding="utf-8")
        wheelclass = wheelclass_path.read_text(encoding="utf-8")
        bonus = bonus_path.read_text(encoding="utf-8")
    except OSError as exc:
        failures.append(f"wheel pairing files could not be read ({exc})")
        return

    def vocation_block(start: str, end: str) -> str:
        begin = icons.find(start)
        finish = icons.find(end, begin + 1)
        if begin < 0 or finish < 0:
            failures.append(f"icons.lua: missing vocation block {start}")
            return ""
        return icons[begin:finish]

    def slot_body(block: str, slot: int) -> str:
        match = re.search(rf"\n\t\t\[{slot}\] = \{{\n(.*?)\n\t\t\}},", block, re.S)
        if not match:
            failures.append(f"icons.lua: missing slot {slot}")
            return ""
        return match.group(1)

    knight = vocation_block("\t[KNIGHT] = {", "\t[PALADIN] = {")
    druid = vocation_block("\t[DRUID] = {", "\t[MONK] = {")
    expected = [
        ("EK Front Sweep", knight, (6, 21), 'iconRect = "360 0 30 30"'),
        ("EK Shield Slam", knight, (8, 24), 'iconSource = "/images/game/wheel/shield-slam-wheel"'),
        ("EK Groundshaker", knight, (11, 26), 'iconRect = "390 0 30 30"'),
        ("EK Intense Wound Cleansing", knight, (13, 29), 'iconRect = "330 0 30 30"'),
        ("EK Fierce Berserk", knight, (16, 31), 'iconRect = "300 0 30 30"'),
        ("ED Forked Spells", druid, (6, 21), 'iconSource = "/images/game/wheel/augmented-forked-spells"'),
        ("ED Mass Healing", druid, (8, 24), 'iconRect = "960 0 30 30"'),
        ("ED Heal Friend", druid, (11, 26), 'iconRect = "990 0 30 30"'),
        ("ED Terra Wave", druid, (13, 29), 'iconRect = "900 0 30 30"'),
        ("ED Strong Ice Wave", druid, (16, 31), 'iconRect = "870 0 30 30"'),
    ]
    for name, block, slots, needle in expected:
        for slot in slots:
            if needle not in slot_body(block, slot):
                failures.append(f"{name}: slot {slot} is not paired with its correct icon")

    groundshaker_contract = (
        '["spell_3"] = {11, 26}',
        '[10] = {maxPoints = 100, domain = 2, dedication = "mana", conviction = "spell_3"}',
        '[25] = {maxPoints = 100, domain = 3, dedication = "mitigation", conviction = "spell_3"}',
        r'return "Aug. Groundshaker\nI: -2s Cooldown\nII: +12.5% Base Damage"',
    )
    for needle in groundshaker_contract:
        if needle not in bonus:
            failures.append(f"Groundshaker positions/attributes are not paired correctly: missing {needle}")

    conviction_marker = wheelclass.find("  --- Convictions")
    summary_start = wheelclass.rfind("  local f_table = {", 0, conviction_marker)
    summary_end = wheelclass.find("  }", summary_start)
    summary = wheelclass[summary_start:summary_end + 3] if summary_start >= 0 and summary_end >= 0 else ""
    for index, key in enumerate(("spell_1", "spell_2", "spell_3", "spell_4", "spell_5"), start=8):
        if f'[{index}] = "{key}"' not in summary:
            failures.append(f"wheelclass.lua: conviction summary must map index {index} to {key}")


def check_audit_regressions() -> None:
    require("modules/game_ek_1525/game_ek_1525.lua",
            "g_ui.importStyle('shield_effect')",
            "g_ui.createWidget('EKShieldEffect', mapPanel)")
    require("modules/game_ek_1525/shield_effect.otui", "image-individual-animation: true")
    content = (ROOT / "modules/gamelib/spells.lua").read_text()
    expected = {
        "Shield Bash": (315, 18, 30, 4000, "4, 8"),
        "Shield Slam": (316, 30, 110, 6000, "4, 8"),
        "Blood Rage": (133, 20, 20, 2000, "8"),
        "Protector": (132, 20, 20, 2000, "8"),
        "Bruise Bane": (170, 1, 10, 2000, "4, 8"),
        "Wound Cleansing": (123, 8, 60, 2000, "4, 8"),
        "Fair Wound Cleansing": (239, 300, 135, 2000, "4, 8"),
        "Intense Wound Cleansing": (158, 80, 300, 120000, "4, 8"),
    }
    for name, (spell_id, level, mana, cooldown, vocations) in expected.items():
        row = next((line for line in content.splitlines() if "['" + name + "'] = {" in line), "")
        for key, value in (("id", spell_id), ("level", level), ("mana", mana), ("exhaustion", cooldown)):
            if not re.search(r"\b" + key + r" = " + str(value) + r"[,}]", row):
                failures.append(f"{name}: incorrect {key}")
        if "vocations = {" + vocations + "}" not in row:
            failures.append(f"{name}: incorrect vocation list")
    try:
        data = (ROOT / "data/images/game/effects/shield-bash.png").read_bytes()
        assert data[:8] == bytes.fromhex("89504e470d0a1a0a")
        offset, duration, frames = 8, 0.0, 0
        animation = None
        while offset < len(data):
            size = struct.unpack(">I", data[offset:offset + 4])[0]
            tag = data[offset + 4:offset + 8]
            value = data[offset + 8:offset + 8 + size]
            if tag == b"IHDR":
                assert struct.unpack(">II", value[:8]) == (64, 64)
            elif tag == b"acTL":
                animation = struct.unpack(">II", value)
            elif tag == b"fcTL":
                frame = struct.unpack(">IIIIIHHBB", value)
                duration += frame[5] / (frame[6] or 100)
                frames += 1
            offset += size + 12
        assert animation == (11, 1) and frames == 11 and abs(duration - 1.12) < 0.001
    except (OSError, AssertionError, struct.error):
        failures.append("shield effect must be a 64x64, 11-frame, 1120ms, single-play APNG")


def main() -> int:
    check_audit_regressions()
    check_wheel_spell_pairings()
    require(
        "modules/gamelib/spells.lua",
        "['Shield Bash'] = {id = 315",
        "words = 'exori ico scu'",
        "clientId = 187",
        "['Shield Slam'] = {id = 316",
        "words = 'exori scu'",
        "mana = 110",
        "clientId = 188",
        "['Groundshaker'] = {id = 106",
        "mana = 200",
        "['Intense Wound Cleansing'] = {id = 158",
        "mana = 300",
        "exhaustion = 120000",
    )
    require(
        "modules/game_wheel/classes/bonus.lua",
        'return "Aug. Front Sweep\\nI: +40% Base Damage\\nII: Enlarges the area to 5 SQMs"',
        'return "Aug. Shield Slam\\nI: +15% Life Leech\\nII: Next hostile autoattack damage reduction increased to 75%"',
        'return "Aug. Groundshaker\\nI: -2s Cooldown\\nII: +12.5% Base Damage"',
        'return "Aug. Intense Wound Cleansing\\nI: +125% Base Healing\\nII: -300s Cooldown"',
        'convictions[t] = {perk = "Aug. Shield Slam"',
    )
    require(
        "modules/game_wheel/classes/icons.lua",
        "-- Shield Slam uses a round medallion made for the Wheel.",
        'iconSource = "/images/game/wheel/shield-slam-wheel"',
        "-- Groundshaker uses the brown medallion shown by the official Wheel.",
    )
    require(
        "modules/game_ek_1525/game_ek_1525.lua",
        "local OPCODE = 218",
        "local EFFECT_DURATION = 1120",
        "local EFFECT_NATIVE_SIZE = 64",
        "local SQUARE_3X3_OFFSETS",
        "if data.area == 'square3x3' then",
        "ProtocolGame.registerExtendedOpcode(OPCODE, onExtendedOpcode)",
    )
    require(
        "modules/game_ek_1525/game_ek_1525.otmod",
        "scripts: [ game_ek_1525 ]",
        "autoload: true",
    )
    require_asset("data/images/game/wheel/shield-slam-wheel.png")
    require_asset("data/images/game/effects/shield-bash.png")

    strings_path = ROOT / "data/json/SkillwheelStringsJsonLibrary.json"
    try:
        strings = json.loads(strings_path.read_text(encoding="utf-8"))
        serialized = json.dumps(strings, ensure_ascii=False)
        for name in ("Augmented Front Sweep", "Augmented Shield Slam", "Augmented Groundshaker", "Augmented Intense Wound Cleansing"):
            if name not in serialized:
                failures.append(f"data/json/SkillwheelStringsJsonLibrary.json: missing {name}")
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        failures.append(f"data/json/SkillwheelStringsJsonLibrary.json: invalid JSON ({exc})")

    if failures:
        print("EK 15.25 client validation FAILED:")
        for failure in failures:
            print(f" - {failure}")
        return 1
    print("EK 15.25 client validation passed (client was not built or started).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
