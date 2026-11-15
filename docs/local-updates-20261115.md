# Cyclopedia custom pages, Bosses panel and NPC trade layout

The branch extends the latest `dudantas/client-1525-updates-20261110` snapshot with the tested local interface changes. It is paired with the identically named branch in the server repository. No executable or personal profile is distributed.

- Codex and Tasks appear within Cyclopedia, using the existing content/actions and custom book/scroll icons. Original pages keep their dimensions. Active tabs use a fixed 200-pixel caption area, inactive tabs remain compact, hidden pages do not reserve an empty cell and unused trailing header space is retained.
- The old combined shortcut becomes Bosses; existing Codex/Tasks shortcuts select their Cyclopedia pages. Boss cards show portraits, cooldowns and waiting players, preserve search/scroll state and request travel through server opcode 225. PZ, character limits, VIP, cooldown and quest access are server-authoritative. The panel does not operate a lever or enter a fight arena.
- Generic item cooldown no longer paints runes as potion cooldown. Action bar/hotkeys pass item identity to the helper so manual runes reserve the combat lane and manual potions reserve the potion lane independently. Existing spell priority remains.
- The modern NPC trade window reserves **670 x 440 pixels**. Buy/Sell/Blacklist, search, quantity, price, gold, preview, progress, Sell All and Cancel have separate visible/clickable areas. Negative button heights and overlapping absolute-positioned elements are removed; standard client button graphics are retained. The NPC name comes from the shop packet. Trade prices, sale queue, blacklist data and server item eligibility are unchanged.

Lua/interface/image changes do not require recompiling the client. Close and reopen the client to load them. The matching server's C++ cooldown changes require a server rebuild.

Validation used the actual client executable with disposable isolated profiles and simulated server payloads, without game login or real sales: 18 Cyclopedia cases, 14 Bosses cases, seven cooldown/helper cases and eight NPC trade cases. NPC trade checks were repeated on a fresh launch after installing the final files: complete captions, containment, no overlaps, active progress/cancellation and independent click handlers; logs contained no errors.

Assets still load from the standard **data/things/1525/** and **data/sounds/1525/** paths. Updater hash/security defaults and asset installation were not modified. No runtime startup observer, account settings, login endpoint, private keys, binaries or diagnostics are included.
