# Shared NPC window polish

Small creature previews previously filled only part of their widgets, leaving
NPC portraits hard to identify. The shared dialog now scales the visible outfit
inside a clipped 88 x 88 viewport and a 96 x 100 frame, adapting to larger NPCs.
Names retain their full tooltip and fit the banner by measured glyph width.

Trade windows are 720 x 480; conversation-only windows are 395 x 480. The item
list, Buy/Sell/Blacklist tabs, search, quantity, price, balance, Sell All and
cancellation controls have separate aligned regions. Item names and price/weight
details are fitted without wrapping and remain complete in their tooltips.
Displayed balances/prices use digit grouping; numeric transaction values are
unchanged. The balance caption also supports item currencies such as Boss Token.

Conversation shortcuts use 24-pixel buttons in a native grid. Up to three rows
resize the transcript area; longer option lists scroll, including the last
option, without covering chat input. Native grid scrolling avoids the HTML flex
layout's failure to apply its virtual scroll offset.

Validation on the installed local client: 20 native dialog/trade scenarios,
8 settled visual variants with 587 geometry/text/scroll checks, 31 identity
checks and the existing Rashid sell-all regression passed, without Lua errors.
Variants include human addons, a gnome, a large demon, gold/token shops, long
names and 28/42/43 conversation options. No real account was logged into by QA.

Run `luajit tests/lua/npc_dialog_identity_spec.lua` and
`luajit tests/lua/rashid_sell_all_spec.lua` from the client root. For either native
test, copy its Lua file to `baiakeros-globalrc.lua` in a fresh disposable profile,
then run `otclient.exe --user-dir=<absolute-disposable-profile-directory>` from
the client root. The profile receives JSON results and application-only renders.
Never use a personal profile for these simulated tests.

Restart the client to load the Lua/HTML changes; no compilation is needed.
The existing `data/things/<version>/` and `data/sounds/<version>/` runtime paths,
strict manifest verification and raw-fallback security defaults are unchanged.
This publication does not deploy or restart any game server.
