# Empty equipment slot indicators

The ten inventory slots retain their existing silhouette images and positions:
head, neck, backpack, armor, right hand/quiver, left hand/weapon, legs, feet,
ring and ammunition/tools.

When a price frame was cleared, the shared item-decoration code could restore the
opaque `/images/ui/item` background on the equipment item's widget. That widget is
drawn over the separate silhouette. Equipment updates now clear the item image
when empty, after clearing the tier/rarity state, so the existing silhouette remains
visible. The change is local to equipment widgets; container backgrounds stay intact.

Monk mirror updates use the same cleanup when the left-hand weapon is removed and
retain tier/rarity decoration while the mirrored weapon is displayed.

Native verification in an isolated offline profile passed 103 checks across all ten
slots, four instance rarities, market-frame cleanup and the monk mirror. The preview
used the actual `MainInventoryItem` style and real inventory callback. The existing
rarity drag/drop regression also passed. No character or normal client profile was
modified during these checks.

Run the native scenario by copying `tests/native/inventory_slots.lua` to the
`baiakeros-globalrc.lua` file of a disposable `--user-dir` profile. It writes a result
JSON and screenshot to that profile and exits. Do not use a normal player profile.

This is a Lua change; reopen the client to load it. A C++ rebuild is unnecessary.
