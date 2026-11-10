# Local migration to protocol 15.25

Validated on 2026-11-10 against the Baiakeros WSL server. This is a local migration;
the production server and public downloads have not been deployed.

## Runtime

- Protocol and client version: **1525**. The previous network version was 1511.
- Appearance/sound catalog remains **1525**, including the existing adapted content.
- `environment.development.lua` keeps localhost; `environment.production.lua` keeps
  the public endpoints. The ignored local `environment.lua` uses the development endpoints.
- Asset paths remain `data/things/1525/` and `data/sounds/1525/`. Manifest verification
  stays strict; no raw hash-mismatch fallback was enabled.
- The desktop local-client shortcut continues to use the existing Windows Release executable.

## Compatibility changes

- Send the 15.25 chase/secure/PvP fight-mode layout. Preserve the existing client
  rule that forces offensive mode; this migration does not add combat stances.
- Keep the level percentage exposed to Lua consistent with `getLevelPercent()`:
  raw 15.20+ basis points remain internal, while Lua receives a value from 0 to 100.
- Respect the server's disabled `GameTaskboard` feature. The current Task Hunt,
  Prey and Wheel layouts remain in use rather than enabling an incomplete replacement.
- Expose the existing negotiated `GameItemRarity = 136` capability to Lua. The
  `bkrarity1` handshake and rarity attributes remain unchanged.
- Translate modern Client Events into the existing automatic-screenshot settings.
  Simple events and structured achievement/level/skill/bestiary events keep their
  correct categories. Legacy protocol behavior and saved option IDs remain intact.

## Validation

Both cached Release builds passed (Linux server and Windows OTC). Native client
sessions passed with RP, sorcerer, druid, knight and monk. Tested:

- level and XP percentage (37%), HP/MP updates, chase/safety and offensive mode;
- effects/projectiles and structured level/skill/bestiary/achievement events;
- all four rarities, bow/quiver equipment and rarity retention when moving items;
- Cyclopedia General, Combat, Offence, Defence, Misc and Store Summary;
- Wheel, Store balance (normal versus transferable coins) and modern NPC trade;
- selling an Ultra item to Rashid;
- local HTTP login and maintenance denial for a normal account.

The screenshot-controller regression test exercises the real Lua controller:

```sh
luajit tests/lua/client_event_screenshots_test.lua
```

No database schema change or reset is required. Disposable test accounts are removed
after validation. This migration does not promise every official 15.25 content feature:
it establishes compatible networking with the current Baiakeros content and adaptations.

## Reference and rollback

Wire layouts were checked against OpenTibiaBR Canary commit
`666a60f6fef803b043cbaf1c7b5fab219da9bfa9` and mehah OTC commit
`a1f6fe2980c5cab46b7b868fd9a06f1ed638eee0`. Whole upstream repositories were not merged.

Local pre-migration sources and executables are backed up under
`G:\otserv\BACKUPS\protocol-1525-20261110`. Revert server and client together;
changing only the version number does not restore the old packet layouts.
