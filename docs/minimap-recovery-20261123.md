# Minimap recovery — 2026-11-23

Branch: `dudantas/warzone-updates-20261123`, based on `dudantas/boss-cooldowns-20261118` (`6e24a4a`). Matching server branch: `dudantas/warzone-updates-20261123` in `caiojosef/baiakeros`.

An interrupted client session left `/baiakeros-player-minimap.otmm` unreadable. The login path ignored a failed personal-map load, leaving the minimap empty and subsequently saving only newly explored areas.

The client now checks the personal load result, preserves the failed file once as `/baiakeros-player-minimap.recovery-backup.otmm`, discards partially loaded blocks and falls back to `/data/minimap.otmm`. It does not save an empty map when both sources fail. A healthy personal map continues loading normally.

The affected local profile was separately restored by merging its surviving known tiles into the valid bundled map. Both the old profile file and the source were backed up locally. That personal recovery is not committed: existing valid but incomplete profiles on other PCs need a separate backup/recovery; this change automatically handles failed reads, not historical exploration already lost before the fix.

Validation: **9 isolated Lua regression cases** in `tests/lua/minimap_load_spec.lua` cover healthy profiles, failed reads, backup preservation/failure, missing sources, failed fallback and first-time bundle installation. `git diff --check` passes. Run from the client root:

```sh
luajit tests/lua/minimap_load_spec.lua
```

Close and reopen the client to load the Lua change; no recompilation is needed. The bundled minimap, executables, updater settings and personal configuration are unchanged by this commit. Standard `data/things/1525/` and `data/sounds/1525/` asset paths remain in use.
