# Loot Pouch refreshes

The server transfers loot immediately. `lootPouchClientUpdateDelay` groups visual
updates of an open pouch; it does not change the drop chance or item ownership.
The deployed server executable must support this option for it to take effect.

For the supplied production configuration (160 ms), an initial diagnostic trial is:

```lua
lootPouchClientUpdateDelay = 300
```

This reduces the maximum frequency of complete pouch snapshots while items still
arrive immediately on the server. It does not throttle loot statistics, death
events or item collection itself. Do not increase `quickLootMaxCorpses` to fix a
death-related freeze: that setting controls manual multi-corpse collection.

The client now reuses the existing item grid when an identical pouch receives a
new snapshot. It updates stack counts, empty slots, rarity/tier visuals, pagination
and drag/drop positions. The window's height, lock and placement remain intact.
Opening a different container or changing its capacity/state still rebuilds it.
Close, parent navigation and saved window state resolve the latest snapshot;
refreshes no longer nest drag handlers. The Helper also persists pouch discovery
once instead of repeatedly scanning bags and saving the same setting.

Validation uses `tests/lua/helper_loot_refresh_spec.lua` and the isolated native
client test `tests/native/loot_pouch_refresh.lua`. The native test sends 50 mock
snapshots through the actual container UI: the previous code created 1,600 item
widgets and set up the window 50 times; the optimized path does neither.
This measures unnecessary UI work, not production FPS or server latency.

To run native validation, create a separate `--user-dir` profile containing a
`baiakeros-globalrc.lua` with:

```lua
dofile('/tests/native/loot_pouch_refresh.lua')
```

Run the development client from the repository root with that isolated profile.
The test creates local container snapshots, does not log in, writes a
`[LootRefreshQA] PASS` or `FAIL` to its diagnostic log and exits automatically.

Confirm in a real hunt after distributing the updated client. Compare the same
hunt with the pouch open and closed. If freezes persist with the pouch closed,
investigate server death/autoloot processing and analyser packets as separate
causes. The production machine was not accessed or modified during this analysis.
