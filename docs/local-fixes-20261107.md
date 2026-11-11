# Client fixes, 7 November 2026

Window layouts, text bounds and scrolling are corrected across Store, Prey, analyzers, inventory-side panels and related dialogs. The Hireling Apprentice offer opens a dedicated name/gender/preview dialog, confirms the purchase, prevents duplicate sends, and recovers after server rejection.

Quick Loot dispatch applies to corpses; ordinary quest chests are opened normally in the supported mouse-control modes. Quick Loot configuration preserves the correct loot/obtain columns and cancellation state. Cyclopedia item search combines literal text and source filters and keeps counts grouped by source, item and tier.

Action-bar equip/unequip recognizes temporary equipment transformation families and quivers without recreating consumed items or replenishing durations.

The branch keeps the upstream per-instance rarity frames and NPC sale interfaces; these concerns remain separate. Client assets continue loading from the standard data/things/<version>/ and data/sounds/<version>/ paths. No asset-installation settings are changed.

Validation: Release x64 client build; native four-color, clone, drag/drop and empty-slot checks; 47 native flow regressions covering Store, Hireling, Prey, Options, Exiva and quest-chest interaction; previous UI layout sweep and action-bar transformation checks. No executable, user profile, credentials or temporary test configuration is included.
