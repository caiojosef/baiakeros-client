# NPC identity and trade window alignment

Opening a shop without the optional NPC-chat-window packet previously left the
portrait on the multiple-NPC placeholder and the transcript heading on
`talking to Unknown`, even after the shop packet supplied the NPC name.

The shared dialog now resolves the named NPC from its chat creature ID or the
nearby NPC list and displays its real outfit. It never selects an arbitrary
nearby creature or player. NPC replies also establish identity before the window
opens. Closing the window clears its identity; ending the game disconnects the
talk listener. A different merchant starts a clean shop session. If the named
NPC is unavailable, a neutral placeholder replaces the previous portrait.

The header name stays within its banner, with a full-name tooltip for long
names. The portrait fits inside its frame. Trade buttons use the standard
readable font and centered captions; currency caption/value, amount/price/gold,
search controls, conversation shortcuts and chat controls have separate areas.
NPC identity comes from the game, with no per-NPC hardcoded outfit catalog.
Rashid blacklist, Sell All, cancellation and server-authoritative pricing remain
on their existing paths. No server, database or asset-installer change is needed.

## Validation

- `luajit tests/lua/npc_dialog_identity_spec.lua`: 31 checks of named NPC
  resolution, outfit changes, missing NPCs, private replies before the window,
  outgoing player messages and rejection of non-NPC creatures.
- `luajit tests/lua/rashid_sell_all_spec.lua`: existing queue regression passed,
  including partial/rejected/missing acknowledgements, cancellation, equipped
  items and modern/legacy behavior.
- `tests/native/npc_dialog.lua`: 17 native cases passed against both staged and
  installed files, without Lua errors. Cases cover geometry, readable captions,
  rendered item rows, real UICreature outfit assignment, repeated merchant
  switching, talk-only NPCs, long names and separate action callbacks.

To run the native test, create a fresh disposable profile directory, copy
`tests/native/npc_dialog.lua` into it as `baiakeros-globalrc.lua`, and run
`otclient.exe --user-dir=<absolute-disposable-profile-directory>` from the client
root. Do not use a personal profile. The test writes `result.json` and an
application-only preview in that disposable directory and exits automatically;
it does not log into the game or send trade requests.

Restart the client to load the Lua/HTML changes. Recompilation is unnecessary.
The existing `data/things/<version>/` and `data/sounds/<version>/` asset paths,
strict manifest hashing and raw-fallback security settings are unchanged.
Publication does not deploy to the production server.
