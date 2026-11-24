# Client UI updates — 2026-11-24

Branch: `dudantas/warzone-updates-20261123`. These commits follow the minimap recovery update and do not change the server or database.

## Helper hotkey notifications

- Healing, Target, Spell Shooter and the combined Target + Spell Shooter hotkey now display `<name> Enable` / `<name> Disable`.
- Names remain white; only Enable is green (`#79ef8b`) or Disable red (`#ff7777`). The centered notice has no background, border or padding and uses the normal rounded game-message font.
- Toggle messages omit helper/attack preset metadata. Preset changes and other informational notices remain plain white.
- Existing activation behavior, combined-toggle semantics, offline guards and dismissal timing are preserved.

## Miniwindow titles

Fourteen miniwindow title widgets using the smaller `cipsoftFont` now match the Loot Pouch title: `verdana-11px-monochrome`, height 13, with the existing header anchors and margins. This covers Analytics Selector, all nine analyser windows including Boss Cooldowns, Battle List, Skills, VIP and Unjustified Points. Their content fonts are unchanged.

## Level-300 chest label

The exact text `300+` now participates in the existing native location-label renderer, using the quest label's gold/orange palette. It shares the other temple labels' pulse timing, color changes and rendering treatment. The server already sends AID 60012 as a location label, so no server/map changes were required. Ordinary player speech containing `300+` is still treated as normal speech.

## Validation and application

- `luajit tests/lua/helper_notifications_spec.lua`: **41 checks** of the actual hotkey callbacks, exact captions, status-only color, combined behavior, offline handling and fade cancellation.
- Existing `helper_shooter_priority_spec.lua` passed.
- The native client rendered **8** enable/disable samples and checked **15** real window headers (14 normalized titles plus the container reference). A separate disposable profile was used; no game login or real account changes.
- Native location-label checks passed for all seven captions in both monster-say/bark-low modes (**14 cases**), repeated pulses and normal-chat behavior.
- Existing Windows release preset successfully rebuilt `otclient` after the C++ change. Changed Lua files pass syntax validation and `git diff --check` passes.
- The separate legacy `helper_manual_priority_spec.lua` fails on a missing `Item` test stub in both the unchanged baseline and the updated source; this predates these visual changes.

Rebuild the native client for `src/client/statictext.cpp`, then close/reopen OTC to load both the binary and Lua/style updates. No compilation is needed for just the Helper/title changes. No executables, maps, personal profiles, screenshots, credentials or backups are included in these commits. Asset installation paths and security defaults are unchanged. Production (Quente) was not deployed by this publication.
