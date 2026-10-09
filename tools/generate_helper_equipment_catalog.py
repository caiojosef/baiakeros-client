"""Generate the Helper's selectable equipment from this server's item definitions."""
import argparse
import json
from pathlib import Path
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser()
parser.add_argument('--server-root', type=Path, required=True)
parser.add_argument('--output', type=Path, default=Path('modules/game_baiakeros_helper_v2/equipment_catalog.lua'))
args = parser.parse_args()
items = {}
for node in ET.parse(args.server_root / 'data/items/items.xml').getroot():
    first = int(node.get('id', node.get('fromid', '0')))
    last = int(node.get('toid', first))
    attrs = {a.get('key').lower(): a.get('value') for a in node.iter('attribute')}
    for item_id in range(first, last + 1):
        items[item_id] = (node.get('name', ''), attrs)
vocations = {'none': 0, 'sorcerer': 3, 'master sorcerer': 13, 'druid': 4, 'elder druid': 14,
             'paladin': 2, 'royal paladin': 12, 'knight': 1, 'elite knight': 11,
             'monk': 5, 'exalted monk': 15}
entries = []
for item_id, (name, attrs) in items.items():
    slot = attrs.get('slot', attrs.get('slottype'))
    if slot not in ('ring', 'necklace') or not name:
        continue
    if int(attrs.get('transformdeequipto', '0')) in items:
        continue  # Select the backpack version, recognize its equipped variant.
    variants = [item_id]
    active_id = int(attrs.get('transformequipto', '0'))
    if active_id in items:
        variants.append(active_id)
    allowed = set()
    level = 0
    for variant in variants:
        data = items[variant][1]
        level = max(level, int(data.get('level', '0')))
        for vocation in data.get('vocation', '').split(','):
            vocation = vocation.split(';')[0].strip().lower()
            if vocation:
                if vocation not in vocations:
                    raise ValueError(f'Unknown vocation {vocation!r} on {item_id}')
                allowed.add(vocations[vocation])
    entries.append((name.lower(), item_id, slot, level, sorted(allowed), variants))
lines = ['-- Generated from server data/items/items.xml by tools/generate_helper_equipment_catalog.py.',
         '-- IDs are protocol item IDs; active variants prevent accidental unequipping.',
         'BaiakHelperEquipmentCatalog = {']
for name, item_id, slot, level, allowed, variants in sorted(entries):
    values = lambda numbers: '{' + ','.join(map(str, numbers)) + '}'
    lines.append(f'    {{id={item_id}, name={json.dumps(name)}, slot="{slot}", level={level}, vocations={values(allowed)}, variants={values(variants)}}},')
lines.append('}\n')
args.output.write_text('\n'.join(lines), encoding='utf-8')
print(f'Generated {len(entries)} equipment entries: {args.output}')
