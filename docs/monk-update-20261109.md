# Monk client update — 2026-11-09

This branch builds on `dudantas/local-fixes-20261107`. Use it with `dudantas/monk-update-20261109` in `caiojosef/baiakeros`. Publishing this branch does not deploy production changes.

## Changes

- Spell catalog and Wheel text match the server's Monk changes, including cooldowns, Mass Spirit Mend mana, Thousand Fist Blows augments and retirement of Mentor Other.
- The original helper recognizes `exori mas amp pug` as a target-centered area: cast range 7, radius 2 and Manhattan limit 3, matching the server's 21 tiles. This allows its actual area to count nearby monsters instead of treating it as single-target.
- Action bar adds **Selected Target Only** aim mode. It does not fall back to self-cast when no target exists. Existing target/self, cursor and crosshair modes are preserved; saved aim mode 4 is accepted.
- Quivers can be assigned as equipment despite being containers in the right-hand slot. Other containers remain excluded.
- Thousand Fist Blows uses its original CipSoft icon across both helpers, action bar, multi-action, spell picker and cooldown display. Presentation ID 186 resolves to the standalone PNG with inner crop `3 3 32 32`; it no longer assumes that atlas index 186 contains the right artwork. The other 200 icon indices retain their existing textures and crop calculations.

## Icon attribution

`data/images/game/spells/thousand-fist-blows-official.png` is the unmodified 38x38 image published by CipSoft at [the official image URL](https://static.tibia.com/images/library/thousandfistblow.png), referenced by [the official spell entry](https://www.tibia.com/library/?subtopic=spells&spell=thousandfistblow). Artwork belongs to CipSoft. [Tibia Monk](https://www.tibiamonk.com/en/abilities) was also used to compare the spell icon visually. No generated or approximate replacement image is included.

## Validation and use

- Syntax and icon-source/crop checks passed for all changed Lua files; all other 200 icon indices were preserved.
- Native client rendering confirmed the official image in the actual helper V2 slot. The server effect 326 was previewed against loaded assets and displays the sequence of fists.
- Helper Shooter regression covered the real spell catalog entry, 49 offsets / 21 included tiles and casting guards.
- Existing equipment/action-bar and quick-loot behavior is retained. Quiver assignment is covered separately in the icon/UI regression test.

Run from the repository root:

```sh
luajit tests/lua/monk_spell_icons_spec.lua
luajit tests/lua/helper_shooter_priority_spec.lua
```

These changes are Lua and an image resource; this client patch does not require another C++ rebuild. Fully close and reopen the client to reload modules and textures.

Asset installation paths remain `data/things/<version>/` and `data/sounds/<version>/`. Existing runtime loading, strict manifest hashes, archive extraction and Android dependencies are untouched. The new icon loads from the existing `data/images/game/spells/` resource hierarchy.
