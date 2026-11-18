# Boss cooldown counters and travel notices

The Bosses panel refreshes when the normal Bosstiary cooldown event arrives and after a refused travel request. A coalesced retry after 2.1 seconds covers the server's sync throttle and is cancelled when the panel closes. A travel result containing the selected boss ID and its remaining encounter cooldown immediately updates the corresponding card, independently of the other boss counters. Blocked quest/access entries show `Indisponivel` instead of claiming availability.

The matching server branch enforces a **30-second travel interval per character**, including VIP, across all destinations. The panel shows `Proximo teleporte: HH:MM:SS`, disables travel buttons and displays `Aguarde Ns` for otherwise ready bosses. The normal encounter cooldown of each boss remains separately visible. Repeated clicks blocked by the local interval do not send teleport or extra refresh requests. Closing and reopening the panel reads the remaining server interval.

The player also receives normal in-game messages:

- After successful travel: `Teleporte realizado. Aguarde 30 segundos para usar novamente.`
- When attempting travel before expiry: `Aguarde 17 segundos para usar outro teleporte de boss.`, using the actual remaining seconds and singular wording when one second remains.

Messages use the client's existing text-message module. The server remains authoritative if a custom client bypasses the interface. Pair this with `dudantas/boss-cooldowns-20261118` in the server repository. Close and reopen the client to load the Lua change; no recompilation is needed.

Validation: Lua syntax checked; **31 regression cases in the real client executable** passed in a disposable isolated profile without login, mouse control or desktop capture, including all cards, counters, VIP, throttled refresh, duplicate clicks, exact expiry, independent fight cooldowns, early server replies before window creation, reopen behavior and caption containment. The same suite was repeated after the on-screen message change with no client errors.

Existing assets continue using `data/things/1525/` and `data/sounds/1525/`. Asset installation, updater settings, binaries and personal profiles are not part of this change.
